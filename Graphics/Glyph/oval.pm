package Bio::Graphics::Glyph::oval;

use strict;
use base 'Bio::Graphics::Glyph';

# override draw_component to draw an oval rather than a rectangle (weird)
sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  my($x1,$y1,$x2,$y2) = $self->bounds(@_);
  $self->filled_oval($gd,
		     $x1, $y1,
		     $x2, $y2);
}


1;
