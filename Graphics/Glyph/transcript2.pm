package Bio::Graphics::Glyph::transcript2;

# $Id: transcript2.pm,v 1.17 2002-04-13 00:46:01 lstein Exp $

use strict;
use Bio::Graphics::Glyph::transcript;
use vars '@ISA','$VERSION';
@ISA = 'Bio::Graphics::Glyph::transcript';
$VERSION = '1.2';

use constant MIN_WIDTH_FOR_ARROW => 8;

sub pad_left  {
  my $self = shift;
  my $pad = $self->Bio::Graphics::Glyph::generic::pad_left;
  return $pad unless $self->feature->strand < 0;
  my $first = ($self->parts)[0] || $self;
  my @rect  = $first->bounds();
  my $width = abs($rect[2] - $rect[0]);
  return $self->SUPER::pad_left if $width < MIN_WIDTH_FOR_ARROW;
  return $pad;
}

sub pad_right  {
  my $self = shift;
  my $pad = $self->Bio::Graphics::Glyph::generic::pad_right;
  return $pad if $self->{level} > 0;
  my $last = ($self->parts)[-1] || $self;
  my @rect  = $last->bounds();
  my $width = abs($rect[2] - $rect[0]);
  return $self->SUPER::pad_right if $width < MIN_WIDTH_FOR_ARROW;
  return $pad
}

sub draw_component {
  my $self = shift;
  return unless $self->level > 0;

  my $gd = shift;
  my ($left,$top) = @_;
  my @rect = $self->bounds(@_);

  my $width = abs($rect[2] - $rect[0]);
  my $filled = defined($self->{partno}) && $width >= MIN_WIDTH_FOR_ARROW;

  if ($filled) {
    my $f = $self->feature;

    if ($f->strand < 0
	&& 
	$self->{partno} == 0) { # first exon, minus strand transcript
      $self->filled_arrow($gd,-1,@rect);
    } elsif ($f->strand >= 0
	     &&
	     $self->{partno} == $self->{total_parts}-1) { # last exon, plus strand
      $self->filled_arrow($gd,+1,@rect);
    } else {
      $self->SUPER::draw_component($gd,@_);
    }
  }

  else {
    $self->SUPER::draw_component($gd,@_);
  }

}

# override option() for force the "hat" type of connector
sub connector {
  return 'hat';
}

sub draw_connectors {
  my $self = shift;
  my ($gd,$dx,$dy) = @_;

  my $part;
  if (my @parts  = $self->parts) {
    $part   = $self->feature->strand > 0 ? $parts[-1] : $parts[0];
  } else {
    # no parts -- so draw an intron spanning whole thing
    my($x1,$y1,$x2,$y2) = $self->bounds(0,0);
    $self->_connector($gd,$dx,$dy,$x1,$y1,$x1,$y2,$x2,$y1,$x2,$y2);
    $part = $self;
  }
  my @rect   = $part->bounds();
  my $width  = abs($rect[2] - $rect[0]);
  my $filled = $width >= MIN_WIDTH_FOR_ARROW;

  if ($filled) {
    $self->Bio::Graphics::Glyph::generic::draw_connectors(@_);
  } else {
    $self->SUPER::draw_connectors(@_);
  }
}

sub bump {
  my $self = shift;
  return $self->SUPER::bump(@_) if $self->all_callbacks;
  return 0;  # never allow our components to bump
}

1;


__END__

=head1 NAME

Bio::Graphics::Glyph::transcript2 - The "transcript2" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used for drawing transcripts.  It is like "transcript"
except that if there is sufficient room the terminal exon is shaped
like an arrow in order to indicate the direction of transcription.  If
there isn't enough room, a small arrow is drawn.

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

  -strand_arrow Whether to indicate            0 (false)
                 strandedness

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
