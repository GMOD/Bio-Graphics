package Bio::Graphics::Glyph::sequence;

use strict;
use Bio::Graphics::Glyph::generic;
use vars '@ISA';
@ISA = qw(Bio::Graphics::Glyph::generic);

# turn off description
sub description { 0 }

# turn off label
sub label { 0}

sub height {
  my $self = shift;
  my $font = $self->font;
  return $self->dna_fits ? 2*$font->height : $self->SUPER::height;
}

sub pixels_per_base {
  my $self = shift;

  my $width           = $self->width;
  my $length          = $self->feature->length;

  return $width/($self->feature->length-1);
}

sub dna_fits {
  my $self = shift;

  my $pixels_per_base = $self->pixels_per_base;
  my $font            = $self->font;
  my $font_width      = $font->width;
  return $pixels_per_base >= $font_width;
}

sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = $self->bounds(@_);

  my $sequence        = eval { $self->feature->dna };
  $sequence or return $self->SUPER::draw_component($gd,@_);

  if ($self->dna_fits) {
    $self->draw_dna($gd,$sequence,$x1,$y1,$x2,$y2);
  } else {
    $self->draw_gc_content($gd,$sequence,$x1,$y1,$x2,$y2);
  }
}

sub draw_dna {
  my $self = shift;
  my ($gd,$sequence,$x1,$y1,$x2,$y2) = @_;
  my $pixels_per_base = $self->pixels_per_base;

  my @bases = split '',$sequence;
  my $color = $self->fgcolor;
  my $font  = $self->font;
  my $lineheight = $font->height;
  my %complement = (g=>'c',a=>'t',t=>'a',c=>'g',
		    G=>'C',A=>'T',T=>'A',C=>'G');
  for (my $i=0;$i<@bases;$i++) {
    my $x = $x1 + $i * $pixels_per_base;
    $gd->char($font,$x,$y1,$bases[$i],$color);
    $gd->char($font,$x,$y1+$lineheight,$complement{$bases[$i]}||$bases[$i],$color);
  }

}

sub draw_gc_content {
  my $self     = shift;
  my $gd       = shift;
  my $sequence = shift;
  my ($x1,$y1,$x2,$y2) = @_;

  my $bin_size = length($sequence) / ($self->option('gc_bins') || 100);
  $bin_size = 100 if $bin_size < 100;

  my @bins;
  for (my $i = 0; $i < length($sequence) - $bin_size; $i+= $bin_size) {
    my $subseq  = substr($sequence,$i,$bin_size);
    my $gc      = $subseq =~ tr/gcGC/gcGC/;
    my $content = $gc/$bin_size;
    push @bins,$content;
  }
  my $bin_width  = ($x2-$x1)/@bins;
  my $bin_height = $y2-$y1;
  my $fgcolor    = $self->fgcolor;
  my $bgcolor    = $self->factory->translate_color($self->panel->gridcolor);

  $gd->line($x1,  $y1,        $x1,  $y2,        $fgcolor);
  $gd->line($x2,  $y1,        $x2,  $y2,        $fgcolor);
  $gd->line($x1,  $y1,        $x1+3,$y1,        $fgcolor);
  $gd->line($x1,  $y2,        $x1+3,$y2,        $fgcolor);
  $gd->line($x1,  ($y2+$y1)/2,$x1+3,($y2+$y1)/2,$fgcolor);
  $gd->line($x2-3,$y1,        $x2,  $y1,        $fgcolor);
  $gd->line($x2-3,$y2,        $x2,  $y2,        $fgcolor);
  $gd->line($x2-3,($y2+$y1)/2,$x2,  ($y2+$y1)/2,$fgcolor);
  $gd->line($x1+5,$y2,        $x2-5,$y2,        $bgcolor);
  $gd->line($x1+5,($y2+$y1)/2,$x2-5,($y2+$y1)/2,$bgcolor);
  $gd->line($x1+5,$y1,        $x2-5,$y1,        $bgcolor);
  $gd->string($self->font,$x1+5,$y1,'% gc',$fgcolor);

  for (my $i = 0; $i < @bins; $i++) {
    my $bin_start  = $x1+$i*$bin_width;
    my $bin_stop   = $bin_start + $bin_width;
    my $y          = $y2 - ($bin_height*$bins[$i]);
    $gd->line($bin_start,$y,$bin_stop,$y,$fgcolor);
    $gd->line($bin_stop,$y,$bin_stop,$y2 - ($bin_height*$bins[$i+1]),$fgcolor)
      if $i < @bins-1;
  }
}

1;
