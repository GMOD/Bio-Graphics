package Bio::Graphics::Glyph::pinsertion;
# package to use for drawing P insertion as a triangle
# p insertion is a point (one base). right now width of box stays 
# 6 pixels

use strict;
use GD;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::generic';

sub calculate_left {
  my $self = shift;
  my $val = $self->SUPER::calculate_left(@_);
  $val -= 3;
}

sub calculate_right {
  my $self = shift;
  my $val = $self->SUPER::calculate_right(@_);
  $val += 3;
}

# override draw method
sub draw {
  my $self = shift;

  my $gd = shift;
  my ($left,$top) = @_;
  my ($x1,$y1,$x2,$y2) = $self->calculate_boundaries(@_);

  my $height = $self->height;

  my $half = 3;

  my $fill = $self->fillcolor;

  my $poly = GD::Polygon->new;

  if ($self->feature->strand > 0) { #plus strand
      $poly->addPt($x1 - $half, $y1);
      $poly->addPt($x1 + ($half), $y1);
      $poly->addPt($x1, $y2); #pointer down
  } else {
      $poly->addPt($x1, $y1); #pointer up
      $poly->addPt($x1 - $half, $y2);
      $poly->addPt($x1 + ($half), $y2);
  }
  $gd->filledPolygon($poly, $fill);
  $gd->polygon($poly, $fill);

  # draw label
  if ($self->option('label')) {
      $self->draw_label($gd,@_);
  }
}



1;
