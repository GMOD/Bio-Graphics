package Bio::Graphics::Glyph::transcript;

use strict;
use base 'Bio::Graphics::Glyph::generic';
use constant ARROW_SIZE => 4;

sub pad_left  { shift->feature->strand > 0 ? 0 : ARROW_SIZE  }
sub pad_right { shift->feature->strand < 0 ? 0 : ARROW_SIZE  }

sub draw_connectors {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  $self->SUPER::draw_connectors($gd,$left,$top);
  my($x1,$y1,$x2,$y2) = $self->bounds(@_);
  if ($self->feature->strand >= 0) {
    $self->draw_arrow($gd,$x2,$x2+ARROW_SIZE,$top+($y2-$y1)/2);
  } else {
    $self->draw_arrow($gd,$x1,$x1 - ARROW_SIZE,$top+($y2-$y1)/2);
  }
}

sub draw_arrow {
  my $self = shift;
  my ($gd,$start,$stop,$y) = @_;
  my $color = $self->connector_color(0);
  my $a2 = abs($stop-$start)/2;
  if ($start < $stop) {  #rightward arrow
    $gd->line($start,$y,$stop,$y,$color);
    $gd->line($stop,$y,$stop-$a2,$y-$a2,$color);
    $gd->line($stop,$y,$stop-$a2,$y+$a2,$color);
  } else {
    $gd->line($stop,$y,$start,$y,$color);
    $gd->line($stop,$y,$stop+$a2,$y-$a2,$color);
    $gd->line($stop,$y,$stop+$a2,$y+$a2,$color);
  }
}

# override option() for force the "hat" type of connector
sub connector {
  return 'hat';
}

1;
