package Bio::Graphics::Glyph;
use GD;

use strict;
use Carp 'croak';
use constant BUMP_SPACING => 2; # vertical distance between bumped glyphs

# a bumpable graphical object that has bumpable graphical subparts

# args:  -feature => $feature_object (may contain subsequences)
#        -factory => $factory_object (called to create glyphs for subsequences)
# In this scheme, the factory decides based on stylesheet information what glyph to
# draw and what configurations options to us. This allows for heterogeneous tracks.
sub new {
  my $class = shift;
  my %arg = @_;

  my $feature = $arg{-feature} or die "No feature";
  my $factory = $arg{-factory} || $class->default_factory;

  my $self = bless {},$class;
  $self->{feature} = $feature;
  $self->{factory} = $factory;
  $self->{top} = 0;

  if (my @subfeatures = $self->subseq($feature)) {
    my @subglyphs = sort { $a->left  <=> $b->left }
      $factory->make_glyph(@subfeatures);  # dynamic glyph resolution

    $self->{left}    = $subglyphs[0]->{left};
    my $right        = (sort { $b<=>$a } map {$_->{left} + $_->{width} - 1} @subglyphs)[0];
    $self->{width}   = $right - $self->{left} + 1;
    $self->{parts}   = \@subglyphs;
  }

  else {
    my ($left,$right) = $factory->map_pt($feature->start,$feature->stop);
    ($left,$right) = ($right,$left) if $left > $right;  # paranoia
    $self->{left}    = $left;
    $self->{width}   = $right - $left + 1;
  }
  return $self;
}

sub parts      {
  my $self = shift;
  return unless $self->{parts};
  return wantarray ? @{$self->{parts}} : $self->{parts};
}

sub feature { shift->{feature} }
sub factory { shift->{factory} }
sub panel   { shift->factory->panel }
sub scale   { shift->factory->scale }
sub start   { shift->{feature}->start}
sub stop    { shift->{feature}->stop}
sub end     { shift->{feature}->stop}
sub map_pt  { shift->{factory}->map_pt(@_) }

sub top {
  my $self = shift;
  my $g = $self->{top};
  $self->{top} = shift if @_;
  $g;
}
sub left {
  my $self = shift;
  $self->{left} - $self->pad_left;
}
sub right {
  my $self = shift;
  $self->left + $self->layout_width - 1;
}
sub bottom {
  my $self = shift;
  $self->top + $self->layout_height - 1;
}
sub height {
  my $self = shift;
  return $self->{height} if exists $self->{height};
  my $baseheight = $self->option('height');  # what the factory says
  return $self->{height} = $baseheight;
}
sub width {
  my $self = shift;
  my $g = $self->{width};
  $self->{width} = shift if @_;
  $g;
}
sub layout_height {
  my $self = shift;
  return $self->layout;
}
sub layout_width {
  my $self = shift;
  $self->{layout_width} ||= $self->width + $self->pad_left + $self->pad_right;
  return $self->{layout_width};
}

# returns the rectangle that surrounds the physical part of the
# glyph, excluding labels and other "extra" stuff
sub bounds {
  my $self = shift;
  my ($dx,$dy) = @_;
  $dx += 0; $dy += 0;
  ($dx + $self->{left},
   $dy + $self->top    + $self->pad_top,
   $dx + $self->{left} + $self->{width} -1,
   $dy + $self->bottom - $self->pad_bottom);
}
sub box {
  my $self = shift;
  ($self->left,$self->top,$self->right,$self->bottom);
}

# return boxes surrounding each part
sub boxes {
  my $self = shift;
  my ($left,$top) = @_;
  $top  += 0; $left += 0;
  my @result;

  $self->layout;
  for my $part ($self->parts) {
    if ($part->feature->type eq 'group') {
      push @result,$part->boxes($left+$self->left,$top+$self->top);
    } else {
      my ($x1,$y1,$x2,$y2) = $part->box;
      push @result,[$part->feature,$left+$x1,$top+$self->top+$y1,$left+$x2,$top+$self->top+$y2];
    }
  }
  return wantarray ? @result : \@result;
}

# this should be overridden for labels, etc.
# allows glyph to make itself thicker or thinner depending on
# domain-specific knowledge
sub pad_top {
  my $self = shift;
  return 0;
}
sub pad_bottom {
  my $self = shift;
  return 0;
}
sub pad_left {
  my $self = shift;
  return 0;
}
sub pad_right {
  my $self = shift;
  return 0;
}

# move relative to parent
sub move {
  my $self = shift;
  my ($dx,$dy) = @_;
  $self->{left} += $dx;
  $self->{top}  += $dy;
}

# get an option
sub option {
  my $self = shift;
  my ($option_name,$partno) = @_;
  my $factory = $self->factory;
  return unless $factory;
  $factory->option($self,$option_name,$partno);
}

# some common options
sub color {
  my $self = shift;
  my $color = shift;
  my $partno = shift;
  my $index = $self->option($color,$partno);
  # turn into a color index
  return $self->factory->translate_color($index) if defined $index;
  return 0;
}

sub connector {
  return shift->option('connector',@_);
}

# return value:
#              0    no bumping
#              +1   bump down
#              -1   bump up
sub bump {
  my $self = shift;
  return $self->option('bump');
}

sub fgcolor {
  shift->color('fgcolor');
}
sub bgcolor {
  shift->color('bgcolor');
}
sub font {
  shift->option('font');
}
sub fontcolor {
  my $self = shift;
  $self->color('fontcolor') || $self->fgcolor;
}
sub connector_color {
  my $self = shift;
  my $partno = shift;
  $self->color('connector_color',$partno) || $self->fgcolor;
}

# handle collision detection
sub layout {
  my $self = shift;
  return $self->{layout_height} if exists $self->{layout_height};

  my @parts = $self->parts 
    or return $self->{layout_height} = $self->height + $self->pad_top + $self->pad_bottom;
  my $bump_direction = $self->bump;

  unless ($bump_direction) { # no layout to do.  everything overlaps 
    return $self->{layout_height} = $self->height;
  }

  $_->layout foreach @parts;  # recursively lay out

  my @occupied;
  my $rightmost = -2;
  for my $g (sort { $a->left <=> $b->left} @parts) {

    my $pos = 0;
    while (1) {
      # look for collisions
      last if $g->left > $rightmost + 2;
      my $bottom = $pos + $g->layout_height;

      my $collision = 0;
      for my $old (@occupied) {
	last if $old->right + 2 < $g->left;
	next if $old->bottom < $pos;
	next if $old->top > $bottom;
	$collision = $old;
	last;
      }
      last unless $collision;
      if ($bump_direction > 0) {
	$pos += $collision->height + BUMP_SPACING;                    # collision, so bump

      } else {
	$pos -= $g->height - BUMP_SPACING;
      }
    }
    $g->move(0,$pos);
    @occupied = sort { $b->right <=> $a->right } ($g,@occupied);
    $rightmost = $g->right if $g->right > $rightmost;
  }

  # If -1 bumping was allowed, then normalize so that the top glyph is at zero
  if ($bump_direction < 0) {
    my ($topmost) = sort {$a->top <=> $b->top} @parts;
    my $offset = 0 - $topmost->top;
    $_->move(0,$offset) foreach @parts;
  }

  # find new height
  my $bottom = 0;
  foreach (@parts) {
    $bottom = $_->bottom if $_->bottom > $bottom;
  }
  return $self->{layout_height} = $self->pad_bottom + $self->pad_top + $bottom - $self->top  + 1;
}

sub draw {
  my $self = shift;
  my $gd = shift;
  my ($left,$top,$partno,$total_parts) = @_;

  $self->layout;
  if (my @parts = $self->parts) {
    my $connector =  $self->connector;
    my $x = $left;
    my $y = $top  + $self->top + $self->pad_top;
    for (my $i=0; $i<@parts; $i++) {
      $parts[$i]->draw($gd,$x,$y,$i,scalar(@parts));
    }
    $self->draw_connectors($gd,$x,$y) if $connector;
  } else {  # no part
    $self->draw_component($gd,$left,$top,$partno,$total_parts);
  }
}

sub draw_connectors {
  my $self = shift;
  my $gd = shift;
  my ($dx,$dy) = @_;
  my @parts = sort { $a->left <=> $b->left } $self->parts;
  for (my $i = 0; $i < @parts-1; $i++) {
    my($xl,$xt,$xr,$xb) = $parts[$i]->bounds;
    my($yl,$yt,$yr,$yb) = $parts[$i+1]->bounds;

    my $left   = $dx + $xr;
    my $right  = $dx + $yl;
    my $top1     = $dy + $xt;
    my $bottom1  = $dy + $xb;
    my $top2     = $dy + $yt;
    my $bottom2  = $dy + $yb;

    $self->draw_connector($gd,$i,
			  $top1,$bottom1,$left,
			  $top2,$bottom2,$right,
			 );
  }
}

sub draw_connector {
  my $self   = shift;
  my $gd     = shift;
  my $partno = shift;

  my $color          = $self->connector_color($partno||0);
  my $connector_type = $self->connector($partno) or return;
  if ($connector_type eq 'hat') {
    $self->draw_hat_connector($gd,$color,@_);
  } elsif ($connector_type eq 'solid') {
    $self->draw_solid_connector($gd,$color,@_);
  } elsif ($connector_type eq 'dashed') {
    $self->draw_dashed_connector($gd,$color,@_);
  } else {
    ; # draw nothing
  }
}

sub draw_hat_connector {
  my $self = shift;
  my $gd   = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  my $center1  = ($top1 + $bottom1)/2;
  my $quarter1 = $top1 + ($bottom1-$top1)/4;
  my $center2  = ($top2 + $bottom2)/2;
  my $quarter2 = $top2 + ($bottom2-$top2)/4;

  if ($center1 != $center2) {
    $self->draw_solid_connector($gd,$color,@_);
    return;
  }

  if ($right - $left > 3) {  # room for the inverted "V"
      my $middle = $left + ($right - $left)/2;
      $gd->line($left,$center1,$middle,$top1,$color);
      $gd->line($middle,$top1,$right,$center1,$color);
    } elsif ($right-$left > 1) { # no room, just connect
      $gd->line($left,$quarter1,$right,$quarter1,$color);
    }

}

sub draw_solid_connector {
  my $self = shift;
  my $gd   = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  my $center1  = ($top1 + $bottom1)/2;
  my $center2  = ($top2 + $bottom2)/2;

  $gd->line($left,$center1,$right,$center2,$color);
}

sub draw_dashed_connector {
  my $self = shift;
  my $gd   = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  my $center1  = ($top1 + $bottom1)/2;
  my $center2  = ($top2 + $bottom2)/2;

  $gd->setStyle($color,$color,gdTransparent,gdTransparent,);
  $gd->line($left,$center1,$right,$center2,gdStyled);
}

sub filled_box {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = @_;

  my $linewidth = $self->option('linewidth') || 1;
  $gd->filledRectangle($x1,$y1,$x2,$y2,$self->bgcolor);
  $gd->rectangle($x1,$y1,$x2,$y2,$self->fgcolor);

  # if the left end is off the end, then cover over
  # the leftmost line
  my ($width) = $gd->getBounds;
  $gd->line($x1,$y1,$x1,$y2,$self->bgcolor)
    if $x1 < 0;

  $gd->line($x2,$y1,$x2,$y2,$self->bgcolor)
    if $x2 > $width;
}

sub filled_oval {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = @_;
  my $cx = ($x1+$x2)/2;
  my $cy = ($y1+$y2)/2;

  my $linewidth = $self->option('linewidth') || 1;
  if ($linewidth > 1) {
    my $pen = $self->make_pen($linewidth);
    # draw a box
    $gd->setBrush($pen);
    $gd->arc($cx,$cy,$x2-$x1,$y2-$y1,0,360,gdBrushed);
  } else {
    $gd->arc($cx,$cy,$x2-$x1,$y2-$y1,0,360,$self->fgcolor);
  }

  # and fill it
  $gd->fill($cx,$cy,$self->bgcolor);
}
sub fill {
  my $self = shift;
  my $gd   = shift;
  my ($x1,$y1,$x2,$y2) = @_;
  if ( ($x2-$x1) >= 2 && ($y2-$y1) >= 2 ) {
    $gd->fill($x1+1,$y1+1,$self->bgcolor);
  }
}

sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  my($x1,$y1,$x2,$y2) = $self->bounds(@_);
  $self->filled_box($gd,
		    $x1, $y1,
		    $x2, $y2);
}

sub subseq {
  my $class = shift;
  my $feature = shift;
  return $feature->merged_segments if $feature->can('merged_segments');
  return $feature->segments        if $feature->can('segments');
  return $feature->sub_SeqFeature  if $feature->can('sub_SeqFeature');
}

sub default_factory {
  croak "no default factory implemented";
}

1;
