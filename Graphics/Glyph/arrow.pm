package Bio::Graphics::Glyph::arrow;
# package to use for drawing an arrow

use strict;
use vars '@ISA';
use Bio::Graphics::Glyph::generic;
@ISA = 'Bio::Graphics::Glyph::generic';

sub pad_bottom {
  my $self = shift;
  my $val = $self->SUPER::pad_bottom(@_);
  $val += $self->font->height if $self->option('tick');
  $val;
}

# override draw method
sub draw {
  my $self = shift;
  my $parallel = $self->option('parallel');
  $parallel = 1 unless defined $parallel;
  $self->draw_parallel(@_) if $parallel;
  $self->draw_perpendicular(@_) unless $parallel;
}

sub draw_perpendicular {
  my $self = shift;
  my $gd = shift;
  my ($dx,$dy) = @_;
  my ($x1,$y1,$x2,$y2) = $self->bounds(@_);

  my $ne = $self->option('northeast');
  my $sw = $self->option('southwest');
  $ne = $sw = 1 unless defined($ne) || defined($sw);

  # draw a perpendicular arrow at position indicated by $x1
  my $fg = $self->set_pen;
  my $a2 = ($y2-$y1)/4;

  my @positions = $x1 == $x2 ? ($x1) : ($x1,$x2);
  for my $x (@positions) {
    if ($ne) {
      $gd->line($x,$y1,$x,$y2,$fg);
      $gd->line($x-$a2,$y1+$a2,$x,$y1,$fg);
      $gd->line($x+$a2,$y1+$a2,$x,$y1,$fg);
    }
    if ($sw) {
      $gd->line($x,$y1,$x,$y2,$fg);
      $gd->line($x-$a2,$y2-$a2,$x,$y2,$fg);
      $gd->line($x+$a2,$y2-$a2,$x,$y2,$fg);
    }
  }

  # add a label if requested
  $self->draw_label($gd,$dx,$dy) if $self->option('label');  # this draws the label aligned to the left
}

sub draw_parallel {
  my $self = shift;
  my $gd = shift;
  my ($dx,$dy) = @_;
  my ($x1,$y1,$x2,$y2) = $self->bounds(@_);

  my $fg = $self->set_pen;
  my $a2 = ($y2-$y1)/2;
  my $center = $y1+$a2;

  my $ne   = $self->option('northeast');
  my $sw   = $self->option('southwest');
  my $base = $self->option('base');

  unless (defined($ne) || defined($sw)) {
    # turn on both if neither specified
    $ne = 1 if $self->feature->strand > 0;
    $sw = 1 if $self->feature->strand < 0;
  }

  $gd->line($x1,$center,$x2,$center,$fg);
  if ($sw) {  # west arrow
    $self->arrowhead($gd,$x1,$center,$a2,-1);
    $gd->line($x2,$center-$a2,$x2,$center+$a2,$fg) if $base;
  }
  if ($ne) {  # east arrow
    $self->arrowhead($gd,$x2,$center,$a2,+1);
    $gd->line($x1,$center-$a2,$x1,$center+$a2,$fg) if $base;
  }

  # turn on ticks
  if ($self->option('tick')) {
    my $left = shift;

    my $scale = $self->scale;

    # figure out tick mark scale
    # we want no more than 1 tick mark every 30 pixels
    # and enough room for the labels
    my $font = $self->font;
    my $width = $font->width;
    my $font_color = $self->fontcolor;

    my $interval = 1;
    my $mindist =  30;
    my $widest = 5 + (length($self->end) * $width);
    $mindist = $widest if $widest > $mindist;

    while (1) {
      my $pixels = $interval * $scale;
      last if $pixels >= $mindist;
      $interval *= 10;
    }

    my $first_tick = $interval * int(0.5 + $self->start/$interval);
    my $pl = $self->panel->pad_left;

    for (my $i = $first_tick; $i < $self->end; $i += $interval) {
      my $tickpos = $left + $self->map_pt($i);
      $gd->line($tickpos,$center-$a2,$tickpos,$center+$a2,$fg)
	unless $tickpos <= $pl;
      my $middle = $tickpos - (length($i) * $width)/2;

      ## Does the user want to override the internal scale?
      my $label;
      if ($self->option('scale')) {
	my $arb_scale = $self->option('scale');
	$label = ($i / $arb_scale);
      } else {
	$label = $i;
      }

      $gd->string($font,$middle,$center+$a2-1,$label,$font_color)
	unless $middle <= $pl;
    }

    if ($self->option('tick') >= 2) {
      my $a4 = ($y2-$y1)/4;
      for (my $i = $self->start+$interval/10; $i < $self->end; $i += $interval/10) {
	my $tickpos = $dx + $self->map_pt($i);
	$gd->line($tickpos,$center-$a4,$tickpos,$center+$a4,$fg);
      }
    }
  }

  # add a label if requested
  $self->draw_label($gd,$dx,$dy)       if $self->option('label');
  $self->draw_description($gd,$dx,$dy) if $self->option('description');
}

1;

__END__

=head1 NAME

Ace::Graphics::Glyph::arrow - The "arrow" glyph

=head1 SYNOPSIS

  See L<Ace::Graphics::Panel> and L<Ace::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph draws arrows.  Depending on options, the arrows can be
labeled, be oriented vertically or horizontally, or can contain major
and minor ticks suitable for use as a scale.

=head2 OPTIONS

In addition to the common options, the following glyph-specific
options are recognized:

  Option      Description               Default
  ------      -----------               -------

  -tick       Whether to draw major         0
              and minor ticks.
	      0 = no ticks
	      1 = major ticks
	      2 = minor ticks

  -parallel   Whether to draw the arrow     true
	      parallel to the sequence
	      or perpendicular to it.

  -northeast  Force a north or east         true
	      arrowhead(depending 
	      on orientation)

  -southwest  Force a south or west         true
	      arrowhead(depending 
	      on orientation)

  -base       Draw a vertical base at the   false
              non-arrowhead side

  -scale      Reset the labels on the arrow false
              to reflect an externally 
              established scale.

Set -parallel to false to display a point-like feature such as a
polymorphism, or to indicate an important location.  If the feature
start == end, then the glyph will draw a single arrow at the
designated location:

       ^
       |

Otherwise, there will be two arrows at the start and end:

       ^              ^
       |              |

Scale: Pass in a externally established scale to reset the labels on the arrow.  This is particularly useful for manually constructed images where the founding parameters of the panel are not 1-based.  For example, a genetic map interval ranging from 0.1 - 0.3 can be constructed by first multiplying every value by 100. Passing

arrow(-scale=>100);

will draw tick marks labelled appropriately to your external scale.

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Ace::Sequence>, L<Ace::Sequence::Feature>, L<Ace::Graphics::Panel>,
L<Ace::Graphics::Track>, L<Ace::Graphics::Glyph::anchored_arrow>,
L<Ace::Graphics::Glyph::arrow>,
L<Ace::Graphics::Glyph::box>,
L<Ace::Graphics::Glyph::primers>,
L<Ace::Graphics::Glyph::segments>,
L<Ace::Graphics::Glyph::toomany>,
L<Ace::Graphics::Glyph::transcript>,

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
