package Bio::Graphics::Glyph::transcript;
# $Id: transcript.pm,v 1.15 2002-04-23 17:46:53 sshu Exp $

use strict;
use Bio::Graphics::Glyph::segments;
use vars '@ISA';
@ISA = qw( Bio::Graphics::Glyph::segments);

sub pad_left  {
  my $self = shift;
  my $pad  = $self->SUPER::pad_left;
  return $pad if $self->{level} > 0;
  return $pad unless $self->feature->strand < 0;
  return $self->arrow_length > $pad ? $self->arrow_length : $pad;
}

sub pad_right {
  my $self = shift;
  my $pad  = $self->SUPER::pad_right;
  return $pad if $self->{level} > 0;
  return $pad unless $self->feature->strand > 0;
  return $self->arrow_length > $pad ? $self->arrow_length : $pad;
}

sub draw_component {
  my $self = shift;
  return unless $self->level > 0;
  $self->SUPER::draw_component(@_);
}

sub draw_connectors {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  $self->SUPER::draw_connectors($gd,$left,$top);
  my @parts = $self->parts;

  # H'mmm.  No parts.  Must be in an intron, so draw intron
  # spanning entire range
  if (!@parts) {
    my($x1,$y1,$x2,$y2) = $self->bounds(0,0);
    $self->_connector($gd,$left,$top,$x1,$y1,$x1,$y2,$x2,$y1,$x2,$y2);
    @parts = $self;
  }

  if ($self->feature->strand >= 0) {
    my($x1,$y1,$x2,$y2) = $parts[-1]->bounds(@_);
    my $center = ($y2+$y1)/2;
    $self->arrow($gd,$x2,$x2+$self->arrow_length,$center);
  } else {
    my($x1,$y1,$x2,$y2) = $parts[0]->bounds(@_);
    my $center = ($y2+$y1)/2;
    $self->arrow($gd,$x1,$x1 - $self->arrow_length,$center);
  }
}

sub arrow_length {
  my $self = shift;
  return $self->option('arrow_length') || 8;
}

# override option() for force the "hat" type of connector
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'hat';
}

# overwrite draw to mark start and stop codons
sub draw {
  my $self = shift;
  $self->SUPER::draw(@_);
  return unless ($self->option('mark_cds'));

  return unless($self->feature->can('start_codon') && $self->feature->can('stop_codon'));

  my $gd = shift;
  my ($left,$top,$partno,$total_parts) = @_;

  my $startc = $self->option('start_codon_color') || 'mediumseagreen';
  my $stopc = $self->option('stop_codon_color') || 'red';
  my ($startcolor, $stopcolor) = ($self->factory->translate_color($startc),
                                  $self->factory->translate_color($stopc));

  my($x1,$y1,$x2,$y2) = $self->bounds(@_);

  my ($start_codon, $stop_codon) = ($self->feature->start_codon, $self->feature->stop_codon);
  my ($start, $end);
  my ($min, $fudge, $width) = (1, 1.5, $self->panel->width);
  #start codon
  $start = $start_codon->start;
  $end = $start_codon->can('stop') ? $start_codon->stop : $start_codon->end;
  $end = $self->feature->strand < 0 ? $start + 3 : $start - 3 if ($start == $end); #?
  ($x1, $x2) = $self->map_pt($start, $end);
  ($x1, $x2) = ($x2, $x1) if ($x1 > $x2);
  ($x1, $x2) = ($left + $x1, $left + $x2);
  my $diff = ($x2-$x1) || 1;
  $min = $diff + (($fudge+$diff)/$width) * $width;
  $x2 = $x1 + $min if ($x2 - $x1 < $min); #exagerating
  if ($x1 >= $self->panel->left && $x1 <= $self->panel->right - $self->panel->pad_right) {
      $gd->filledRectangle($x1, $y1, $x2, $y2, $startcolor);
  }
  #stop codon
  $start = $stop_codon->stop;
  $end = $stop_codon->can('end') ? $stop_codon->end : $stop_codon->stop;
  $end = $self->feature->strand < 0 ? $start - 3 : $start + 3 if ($start == $end); #?
  ($x1, $x2) = $self->map_pt($start, $end);
  ($x1, $x2) = ($x2, $x1) if ($x1 > $x2);
  ($x1, $x2) = ($left + $x1, $left + $x2);
  my $diff = ($x2-$x1) || 1;
  $min = $diff + (($fudge+$diff)/$width) * $width;
  $x2 = $x1 + $min if ($x2 - $x1 < $min); #exagerating
  if ($x1 >= $self->panel->left && $x1 <= $self->panel->right - $self->panel->pad_right) {
      $gd->filledRectangle($x1, $y1, $x2, $y2, $stopcolor);
  }
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::transcript - The "transcript" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used for drawing transcripts.  It is essentially a
"segments" glyph in which the connecting segments are hats.  The
direction of the transcript is indicated by an arrow attached to the
end of the glyph.

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

  -connector    Connector type                 0 (false)

  -connector_color
                Connector color                black

  -label        Whether to draw a label	       0 (false)

  -description  Whether to draw a description  0 (false)

In addition, the alignment glyph recognizes the following
glyph-specific options:

  Option         Description                  Default
  ------         -----------                  -------

  -arrow_length  Length of the directional   8
                 arrow.

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Track>,
L<Bio::Graphics::Glyph::transcript2>,
L<Bio::Graphics::Glyph::anchored_arrow>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::box>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
