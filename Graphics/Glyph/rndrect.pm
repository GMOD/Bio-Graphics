package Bio::Graphics::Glyph::rndrect;

use strict;
use base 'Bio::Graphics::Glyph::generic';

# override draw_component to draw an round edge rect rather than a rectangle
sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  my($x1,$y1,$x2,$y2) = $self->calculate_boundaries(@_);#$self->bounds(@_);
  require GD;
  my $poly = GD::Polygon->new;
  my $boxheight = $y2 - $y1;

  if (($x2-$x1) > 3) {
      $poly->addPt($x1+1, $y1+1);
      $poly->addPt($x1+2, $y1);
      $poly->addPt($x2-2, $y1);
      $poly->addPt($x2-1, $y1+1);
      $poly->addPt($x2, $y1 + $boxheight / 2)
        if (($y2 - $y1) > 6);

      $poly->addPt($x2-1, $y2-1);
      $poly->addPt($x2-2, $y2);
      $poly->addPt($x1+2, $y2);
      $poly->addPt($x1+1, $y2-1);
      $poly->addPt($x1, $y1 + $boxheight / 2)
        if (($y2 - $y1) > 6);
  } else {
      $poly->addPt($x1, $y1);
      $poly->addPt($x2, $y1);
      
      $poly->addPt($x2, $y2);
      $poly->addPt($x1, $y2);
  }

  $gd->filledPolygon($poly, $self->fillcolor);

  $gd->polygon($poly, $self->fgcolor);
}

# group sets connector to 'solid'
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'solid';
}

sub bump {
  my $self = shift;
  return $self->SUPER::bump(@_) if $self->all_callbacks;
  return 0;
}


1;
