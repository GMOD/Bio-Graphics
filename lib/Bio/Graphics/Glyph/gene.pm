package Bio::Graphics::Glyph::gene;

use strict;
use base 'Bio::Graphics::Glyph::processed_transcript';

sub my_descripton {
    return <<END;
This glyph is used for drawing genes that may have
alternatively-spliced transcripts. The various isoforms are stacked on
top of each other and given a single label and description that apply
to the entire stack. Each individual transcript\'s name is optionally
printed to the left of the transcript glyph.

Transcripts (splice isoforms) are drawn using the processed_transcript
glyph.  CDS features are drawn in the background color, and the UTRs
are drawn in an alternate color selected by the utr_color option.  In
addition, you can make the UTRs thinner than the CDS by setting the
"thin_utr" option.

This glyph is designed to work properly with GFF3-style three-tier
genes, in which the top level feature has the Sequence Ontology type
of "gene", the second level feature(s) have the SO type "mRNA", and
the third level feature(s) have the SO type "CDS", "five_prime_utr"
and "three_prime_utr."  Subparts named "UTR" are also honored.  The
feature can contain other subparts as well (e.g. exon, intron,
translation), but they are currently ignored unless the option
sub_part is supplied.  If the sub_part option is used that feature 
type will be used and CDS and UTR features will be excluded.
This could be used for specifying that exons be used instead,
for example.

This glyph is a subclass of processed_transcript, and recognizes the
same options.
END
}

sub my_options {
    {
	label_transcripts => [
	    'boolean',
	    undef,
	    'If true, then the display_name of each transcript',
	    'will be drawn to the left of the transcript glyph.'],
	thin_utr => [
	    'boolean',
	    undef,
	    'If true, UTRs will be drawn at 2/3 of the height of CDS segments.'],
	utr_color => [
	    'color',
	    'grey',
	    'Color of UTR segments.'],
	decorate_introns => [
	    'boolean',
	    undef,
	    'Draw chevrons on the introns to indicate direction of transcription.'
	],
    }
}

sub extra_arrow_length {
  my $self = shift;
  return 0 if $self->feature->primary_tag =~ /exon|utr/i;
  return $self->SUPER::extra_arrow_length 
      unless $self->feature->primary_tag =~ /gene/;
  return 0 unless $self->{level} == 1;
  local $self->{level} = 0;  # fake out superclass
  return $self->SUPER::extra_arrow_length;
}

sub pad_left {
  my $self = shift;
  my $type = $self->feature->primary_tag;
  return 0 unless $type =~ /gene|rna|transcript/i;
  $self->SUPER::pad_left;
}

sub pad_right {
  my $self = shift;
  return 0 unless $self->{level} < 2; # don't invoke this expensive call on exons
  return $self->SUPER::pad_right;
}

sub pad_bottom {
  my $self = shift;
  return 0 unless $self->{level} < 2 || $self->is_utr; # don't invoke this expensive call on exons
  return $self->SUPER::pad_bottom;
}

sub pad_top {
  my $self = shift;
  return 0 unless $self->{level} < 2 || $self->is_utr; # don't invoke this expensive call on exons
  return $self->SUPER::pad_top;
}

sub bump {
  my $self = shift;
  my $bump;
  if ($self->{level} == 0
      && lc $self->feature->primary_tag eq 'gene'
      && eval {($self->subfeat($self->feature))[0]->type =~ /RNA|pseudogene/i}) {
      $bump = $self->option('bump');
  } else {
      $bump = $self->SUPER::bump;
  }
  return $bump;
}

sub label {
  my $self = shift;
  return unless $self->{level} < 2;
  if ($self->{feature}->primary_tag =~ /rna|transcript|pseudogene/i && $self->label_transcripts) {
      return $self->_label;
  } else {
    return $self->SUPER::label;
  }
}

sub label_position {
  my $self = shift;
  return 'top' if $self->{level} == 0;
  return 'left';
}

sub label_transcripts {
  my $self = shift;
  return $self->{label_transcripts} if exists $self->{label_transcripts};
  return $self->{label_transcripts} = $self->_label_transcripts;
}

sub _label_transcripts {
  my $self = shift;
  return $self->option('label_transcripts');
}

sub draw_connectors {
  my $self = shift;
  if ($self->feature->primary_tag eq 'gene') {
      my @parts = $self->parts;
      return if @parts && $parts[0]->feature->primary_tag =~ /rna|transcript|pseudogene/i;
  }
  $self->SUPER::draw_connectors(@_);
}

sub maxdepth {
  my $self = shift;
  my $md   = $self->Bio::Graphics::Glyph::maxdepth;
  return $md if defined $md;
  return 2;
}

sub fixup_glyph {
  my $self = shift;
  return unless $self->level == 1;
  $self->create_implied_utrs if $self->option('implied_utrs');
  $self->adjust_exons        if $self->option('implied_utrs') || $self->option('adjust_exons');
}

sub _subfeat {
  my $class   = shift;
  my $feature = shift;

  if ($feature->primary_tag =~ /^gene/i) {
    my @transcripts;
    for my $t (qw/mRNA tRNA snRNA snoRNA miRNA ncRNA pseudogene transcript/) {
      push @transcripts, $feature->get_SeqFeatures($t);
    }
    return @transcripts if @transcripts;
    my @features = $feature->get_SeqFeatures;  # no transcripts?! return whatever's there
    return @features if @features;

    # fall back to drawing a solid box if no subparts and level 0
    return ($feature) if $class->{level} == 0;
  }
  elsif ($feature->primary_tag =~ /^CDS/i) {
      my @parts = $feature->get_SeqFeatures();
      return ($feature) if $class->{level} == 0 and !@parts;
      return @parts;
  }

  my @subparts;
  if ($class->option('sub_part')) {
    @subparts = $feature->get_SeqFeatures($class->option('sub_part'));
  }
  elsif ($feature->primary_tag =~ /^mRNA/i) {
    if ($class->option('implied_utrs') || $class->option('adjust_exons')) {
      @subparts = $feature->get_SeqFeatures(qw(CDS exon five_prime_UTR three_prime_UTR UTR));
    } else {
      @subparts = $feature->get_SeqFeatures(qw(CDS five_prime_UTR three_prime_UTR UTR));
    }
  }
  else {
    @subparts = $feature->get_SeqFeatures('exon');
  }
 
  # The CDS and UTRs may be represented as a single feature with subparts or as several features
  # that have different IDs. We handle both cases transparently.
  my @result;
  foreach (@subparts) {
    if ($_->primary_tag =~ /CDS|UTR/i) {
      my @cds_seg = $_->get_SeqFeatures;
      if (@cds_seg > 0) { push @result,@cds_seg  } else { push @result,$_ }
    } else {
      push @result,$_;
    }
  }
  # fall back to drawing a solid box if no subparts and level 0
  return ($feature) if $class->{level} == 0 && !@result;

  return @result;
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::gene - A GFF3-compatible gene glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used for drawing genes that may have
alternatively-spliced transcripts. The various isoforms are stacked on
top of each other and given a single label and description that apply
to the entire stack. Each individual transcript's name is optionally
printed to the left of the transcript glyph.

Transcripts (splice isoforms) are drawn using the processed_transcript
glyph.  CDS features are drawn in the background color, and the UTRs
are drawn in an alternate color selected by the utr_color option.  In
addition, you can make the UTRs thinner than the CDS by setting the
"thin_utr" option.

This glyph is designed to work properly with GFF3-style three-tier
genes, in which the top level feature has the Sequence Ontology type
of "gene", the second level feature(s) have the SO type "mRNA", and
the third level feature(s) have the SO type "CDS", "five_prime_utr"
and "three_prime_utr."  Subparts named "UTR" are also honored.  The
feature can contain other subparts as well (e.g. exon, intron,
translation), but they are currently ignored unless the option
sub_part is supplied.  If the sub_part option is used that feature 
type will be used and CDS and UTR features will be excluded.
This could be used for specifying that exons be used instead,
for example.

This glyph is a subclass of processed_transcript, and recognizes the
same options.

=head2 OPTIONS

The following options are standard among all Glyphs.  See
L<Bio::Graphics::Glyph> for a full explanation.

  Option      Description                      Default
  ------      -----------                      -------

  -fgcolor      Foreground color	       black

  -outlinecolor	Synonym for -fgcolor

  -bgcolor      Background color               turquoise

  -fillcolor    Synonym for -bgcolor

  -linewidth    Line width                     1

  -height       Height of glyph		       10

  -font         Glyph font		       gdSmallFont

  -connector    Connector type                 undef (false)

  -connector_color
                Connector color                black

  -label        Whether to draw a label	       undef (false)

  -description  Whether to draw a description  undef (false)

  -strand_arrow Whether to indicate            undef (false)
                 strandedness

  -hilite       Highlight color                undef (no color)

In addition, the gene glyph recognizes the following glyph-specific
options:

  Option         Description                   Default
  ------         -----------                   -------

  -label_transcripts                           undef (false)
                 Flag. If true, then the
                 display name of each
                 transcript will be drawn
                 to the left of the transcript
                 glyph.

  -thin_utr      Flag.  If true, UTRs will      undef (false)
                 be drawn at 2/3 of the
                 height of CDS segments.

  -utr_color     Color of UTR segments.         Gray #D0D0D0

  -decorate_introns
                 Draw strand with little arrows undef (false)
                 on the intron.

=head1 BUGS

The SO terms are hard-coded. They should be more flexible and should
recognize ISA relationships.

=head1 SEE ALSO


L<Bio::Graphics::Panel>,
L<Bio::Graphics::Glyph>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::cds>,
L<Bio::Graphics::Glyph::crossbox>,
L<Bio::Graphics::Glyph::diamond>,
L<Bio::Graphics::Glyph::dna>,
L<Bio::Graphics::Glyph::dot>,
L<Bio::Graphics::Glyph::ellipse>,
L<Bio::Graphics::Glyph::extending_arrow>,
L<Bio::Graphics::Glyph::generic>,
L<Bio::Graphics::Glyph::graded_segments>,
L<Bio::Graphics::Glyph::heterogeneous_segments>,
L<Bio::Graphics::Glyph::line>,
L<Bio::Graphics::Glyph::pinsertion>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::rndrect>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::ruler_arrow>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,
L<Bio::Graphics::Glyph::transcript2>,
L<Bio::Graphics::Glyph::translation>,
L<Bio::Graphics::Glyph::triangle>,
L<Bio::DB::GFF>,
L<Bio::SeqI>,
L<Bio::SeqFeatureI>,
L<Bio::Das>,
L<GD>

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
