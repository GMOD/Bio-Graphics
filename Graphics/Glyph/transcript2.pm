package Bio::Graphics::Glyph::transcript2;

use strict;
use base 'Bio::Graphics::Glyph::generic';

sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  my @rect = $self->bounds(@_);

  if ($self->feature->strand < 0 && $self->{partno} == 0) { # first exon, minus strand transcript
    $self->filled_arrow($gd,-1,@rect);
  } elsif ($self->feature->strand >= 0 && $self->{partno} == $self->{total_parts}-1) { # last exon, plus strand
        $self->filled_arrow($gd,+1,@rect);
  } else {
    $self->SUPER::draw_component($gd,@_);
  }
}

sub filled_arrow {
  my $self = shift;
  my $gd  = shift;
  my $orientation = shift;

  my ($x1,$y1,$x2,$y2) = @_;
  my ($width) = $gd->getBounds;
  my $indent = ($y2-$y1);

  return $self->filled_box($gd,@_)
    if ($orientation == 0)
      or ($x1 < 0 && $orientation < 0)
        or ($x2 > $width && $orientation > 0)
          or ($x2 - $x1 < $indent);

  my $fg = $self->fgcolor;
  if ($orientation >= 0) {
    $gd->line($x1,$y1,$x2-$indent,$y1,$fg);
    $gd->line($x2-$indent,$y1,$x2,($y2+$y1)/2,$fg);
    $gd->line($x2,($y2+$y1)/2,$x2-$indent,$y2,$fg);
    $gd->line($x2-$indent,$y2,$x1,$y2,$fg);
    $gd->line($x1,$y2,$x1,$y1,$fg);
    $gd->fill($x1+1,($y1+$y2)/2,$self->bgcolor);
  } else {
    $gd->line($x1,($y2+$y1)/2,$x1+$indent,$y1,$fg);
    $gd->line($x1+$indent,$y1,$x2,$y1,$fg);
    $gd->line($x2,$y2,$x1+$indent,$y2,$fg);
    $gd->line($x1+$indent,$y2,$x1,($y1+$y2)/2,$fg);
    $gd->line($x2,$y1,$x2,$y2,$fg);
    $gd->fill($x2-1,($y1+$y2)/2,$self->bgcolor);
  }
}

# override option() for force the "hat" type of connector
sub connector {
  return 'hat';
}

1;
