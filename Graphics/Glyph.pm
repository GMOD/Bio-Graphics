package Bio::Graphics::Glyph;
use GD;

use strict;
use Carp 'croak';
use constant BUMP_SPACING => 2; # vertical distance between bumped glyphs

my %LAYOUT_COUNT;

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
    my $right        = (sort { $b<=>$a } map {$_->right} @subglyphs)[0];
    $self->{width}   = $right - $self->{left} + 1;
    $self->{parts}   = \@subglyphs;
  }

  else {
    my ($left,$right) = $factory->map_pt($self->start,$self->stop);
    ($left,$right) = ($right,$left) if $left > $right;  # paranoia
    $self->{left}    = $left;
    $self->{width}   = $right - $left + 1;
  }

  #Glyphs that don't actually fill their space, but merely mark a point.
  #They need to have their collision bounds altered.  We will (for now)
  #hard code them to be in the center or their feature.
  $self->{point} = $arg{-point} ? $self->height : undef;
  if($self->option('point')){
    my ($left,$right) = $factory->map_pt($self->start,$self->stop);
#    my $center = int(($self->{right} + $self->{left}) / 2);
    my $center = int(($left+$right)/2);

    $self->{width} = $self->height;
    $self->{left}  = $center - ($self->{width});
    $self->{right} = $center + ($self->{width});
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
sub point   { shift->{point}   }
sub scale   { shift->factory->scale }
sub start   {
  my $self = shift;
  return $self->{start} if exists $self->{start};
  $self->{start} = $self->{feature}->start;
}
sub stop    {
  my $self = shift;
  return $self->{stop} if exists $self->{stop};
  $self->{stop} = $self->{feature}->stop;
}
sub end     { shift->stop }
sub map_pt  { shift->{factory}->map_pt(@_) }

# add a feature (or array ref of features) to the list
sub add_feature {
  my $self       = shift;
  my $factory    = $self->factory;
  for my $feature (@_) {
    if (ref $feature eq 'ARRAY') {
      $self->add_group(@$feature);
    } else {
      push @{$self->{parts}},$factory->make_glyph($feature);
    }
  }
}

# link a set of features together so that they bump as a group
sub add_group {
  my $self = shift;
  my @features = @_;
  my $f    = Bio::Graphics::Feature->new(
				     -segments=>\@features,
				     -type => 'group'
					);
  $self->add_feature($f);
}

sub top {
  my $self = shift;
  my $g = $self->{top};
  $self->{top} = shift if @_;
  $g;
}
sub left {
  my $self = shift;
  return $self->{cache_left} if exists $self->{cache_left};
  $self->{cache_left} = $self->{left} - $self->pad_left;
}
sub right {
  my $self = shift;
  return $self->{cache_right} if exists $self->{cache_right};
  $self->{cache_right} = $self->left + $self->layout_width - 1;
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
sub calculate_boundaries {return shift->bounds(@_);}#is this right?
                                                    #should be gd->getBounds()?
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
  my $gd = shift;

  #doing double duty now.
  unless ($gd) {
    return ($self->left,$self->top,$self->right,$self->bottom);
  }

  my ($x1,$y1,$x2,$y2) = @_;

  my $fg = $self->fgcolor;
  my $bg = $self->bgcolor;
  my $linewidth = $self->option('linewidth') || 1;

#  $gd->rectangle($x1,$y1,$x2,$y2,$bg);

  $fg = $self->set_pen($linewidth,$fg) if $linewidth > 1;

  # draw a box
  $gd->rectangle($x1,$y1,$x2,$y2,$fg);

  # if the left end is off the end, then cover over
  # the leftmost line
  my ($width) = $gd->getBounds;

  $bg = $self->set_pen($linewidth,$bg) if $linewidth > 1;

  $gd->line($x1,$y1+$linewidth,$x1,$y2-$linewidth,$bg)
    if $x1 < $self->panel->pad_left;

  $gd->line($x2,$y1+$linewidth,$x2,$y2-$linewidth,$bg)
    if $x2 > $width - $self->panel->pad_right;
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
      push @result,[$part->feature,$x1,$top+$self->top+$y1,$x2,$top+$self->top+$y2];
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

  # because the feature parts use *absolute* not relative addressing
  # we need to move each of the parts horizontally, but not vertically
  $_->move($dx,0) foreach $self->parts;
}

# get an option
sub option {
  my $self = shift;
  my $option_name = shift;
  my $factory = $self->factory;
  return unless $factory;
  $factory->option($self,$option_name,@{$self}{qw(partno total_parts)});
}

# some common options
sub color {
  my $self = shift;
  my $color = shift;
  my $index = $self->option($color);
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
sub font2color {
  my $self = shift;
  $self->color('font2color') || $self->fontcolor;
}
sub tkcolor { shift->color('tkcolor') } # "track color"
sub connector_color {
  my $self = shift;
  $self->color('connector_color') || $self->fgcolor;
}

# handle collision detection
sub layout {
  my $self = shift;
  return $self->{layout_height} if exists $self->{layout_height};

  (my @parts = $self->parts)
    || return $self->{layout_height} = $self->height + $self->pad_top + $self->pad_bottom;

  my $bump_direction = $self->bump;

  $_->layout foreach @parts;  # recursively lay out

  if (@parts == 1 || !$bump_direction) {
    my $highest = 0;
    foreach (@parts) {
      my $height = $_->layout_height;
      $highest = $height > $highest ? $height : $highest;
    }
    return $self->{layout_height} = $highest + $self->pad_top + $self->pad_bottom;
  }

  my %occupied;
  for my $g (sort { $a->left <=> $b->left } @parts) {

    my $pos = 0;

    while (1) {
      # look for collisions
      my $bottom = $pos + $g->{layout_height};

      my $collision;
      for my $old (sort {$b->[2]<=> $a->[2]} values %occupied) {
	last if $old->[2] + 2 < $g->left;
	next if $old->[3]  < $pos;
	next if $old->[1] > $bottom;
	$collision = $old;
	last;
      }
      last unless $collision;

      if ($bump_direction > 0) {
	$pos += $collision->[3]-$collision->[1] + BUMP_SPACING;                    # collision, so bump

      } else {
#	$pos -= $g->{layout_height} - BUMP_SPACING;
	$pos -= BUMP_SPACING;
      }
    }
    $g->move(0,$pos);
    $occupied{$g} = [$g->left,$g->top,$g->right,$g->bottom];
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

  local($self->{partno},$self->{total_parts});
  @{$self}{qw(partno total_parts)} = ($partno,$total_parts);

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
    $self->draw_component($gd,$left,$top);
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

    $self->draw_connector($gd,
			  $top1,$bottom1,$left,
			  $top2,$bottom2,$right,
			 );
  }
}

sub draw_connector {
  my $self   = shift;
  my $gd     = shift;

  my $color          = $self->connector_color;
  my $connector_type = $self->connector or return;
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

  my $fg = $self->fgcolor;
  my $bg = $self->bgcolor;
  my $linewidth = $self->option('linewidth') || 1;

  $gd->filledRectangle($x1,$y1,$x2,$y2,$bg);

  $fg = $self->set_pen($linewidth,$fg) if $linewidth > 1;

  # draw a box
  $gd->rectangle($x1,$y1,$x2,$y2,$fg);

  # if the left end is off the end, then cover over
  # the leftmost line
  my ($width) = $gd->getBounds;

  $bg = $self->set_pen($linewidth,$bg) if $linewidth > 1;

  $gd->line($x1,$y1+$linewidth,$x1,$y2-$linewidth,$bg)
    if $x1 < $self->panel->pad_left;

  $gd->line($x2,$y1+$linewidth,$x2,$y2-$linewidth,$bg)
    if $x2 > $width - $self->panel->pad_right;
}

sub filled_oval {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = @_;
  my $cx = ($x1+$x2)/2;
  my $cy = ($y1+$y2)/2;

  my $fg = $self->fgcolor;
  my $linewidth = $self->linewidth;

  $fg = $self->set_pen($linewidth) if $linewidth > 1;
  $gd->arc($cx,$cy,$x2-$x1,$y2-$y1,0,360,$fg);

  # and fill it
  $gd->fill($cx,$cy,$self->bgcolor);
}

sub oval {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = @_;
  my $cx = ($x1+$x2)/2;
  my $cy = ($y1+$y2)/2;

  my $fg = $self->fgcolor;
  my $linewidth = $self->linewidth;

  $fg = $self->set_pen($linewidth) if $linewidth > 1;
  $gd->arc($cx,$cy,$x2-$x1,$y2-$y1,0,360,$fg);
}

sub linewidth {
  shift->option('linewidth') || 1;
}

sub fill {
  my $self = shift;
  my $gd   = shift;
  my ($x1,$y1,$x2,$y2) = @_;
  if ( ($x2-$x1) >= 2 && ($y2-$y1) >= 2 ) {
    $gd->fill($x1+1,$y1+1,$self->bgcolor);
  }
}
sub set_pen {
  my $self = shift;
  my ($linewidth,$color) = @_;
  $linewidth ||= $self->linewidth;
  $color     ||= $self->fgcolor;
  return $color unless $linewidth > 1;
  $self->panel->set_pen($linewidth,$color);
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
  return;
}

# synthesize a key glyph
sub keyglyph {
  my $self = shift;

  my $scale = 1/$self->scale;  # base pairs/pixel

  # two segments, at pixels 0->50, 60->80
  my $offset = $self->panel->offset;


  my $feature =
    Bio::Graphics::Feature->new(
				-segments=>[ [ 0*$scale +$offset,50*$scale+$offset],
					     [60*$scale+$offset, 80*$scale+$offset]
					   ],
				-name => $self->option('key'),
				-strand => '+1');
  my $factory = $self->factory->clone;
  $factory->set_option(label => 1);
  $factory->set_option(bump  => 0);
  $factory->set_option(connector  => 'solid');
  return $factory->make_glyph($feature);
}

sub all_callbacks {
  my $self = shift;
  my $track_level = $self->option('all_callbacks');
  return $track_level if defined $track_level;
  return $self->panel->all_callbacks; 
}

sub default_factory {
  croak "no default factory implemented";
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph - Base class for Bio::Graphics::Glyph objects

=head1 SYNOPSIS

See L<Bio::Graphics::Panel>.

=head1 DESCRIPTION

Bio::Graphics::Glyph is the base class for all glyph objects.  Each
glyph is a wrapper around an Bio:SeqFeatureI object, knows how to
render itself on an Bio::Graphics::Panel, and has a variety of
configuration variables.

End developers will not ordinarily work directly with
Bio::Graphics::Glyph objects, but with Bio::Graphics::Glyph::generic
and its subclasses.  Similarly, most glyph developers will want to
subclass from Bio::Graphics::Glyph::generic because the latter
provides labeling and arrow-drawing facilities.

=head1 METHODS

This section describes the class and object methods for
Bio::Graphics::Glyph.

=head2 CONSTRUCTORS

Bio::Graphics::Glyph objects are constructed automatically by an
Bio::Graphics::Glyph::Factory, and are not usually created by
end-developer code.

=over 4

=item $glyph = Bio::Graphics::Glyph->new(-feature=>$feature,-factory=>$factory)

Given a sequence feature, creates an Bio::Graphics::Glyph object to
display it.  The B<-feature> argument points to the Bio:SeqFeatureI
object to display, and B<-factory> indicates an
Bio::Graphics::Glyph::Factory object from which the glyph will fetch
all its run-time configuration information.  Factories are created and
manipulated by the Bio::Graphics::Panel object.

A standard set of options are recognized.  See L<OPTIONS>.

=back

=head2 OBJECT METHODS

Once a glyph is created, it responds to a large number of methods.  In
this section, these methods are grouped into related categories.

Retrieving glyph context:

=over 4

=item $factory = $glyph->factory

Get the Bio::Graphics::Glyph::Factory associated with this object.
This cannot be changed once it is set.

=item $panel = $glyph->panel

Get the Bio::Graphics::Panel associated with this object.  This cannot
be changed once it is set.

=item $feature = $glyph->feature

Get the sequence feature associated with this object.  This cannot be
changed once it is set.

=back

Retrieving glyph options:

=over 4

=item $fgcolor = $glyph->fgcolor

=item $bgcolor = $glyph->bgcolor

=item $fontcolor = $glyph->fontcolor

=item $fontcolor = $glyph->font2color

=item $fillcolor = $glyph->fillcolor

These methods return the configured foreground, background, font,
alternative font, and fill colors for the glyph in the form of a
GD::Image color index.

=item $color = $glyph->tkcolor

This method returns a color to be used to flood-fill the entire glyph
before drawing (currently used by the "track" glyph).

=item $width = $glyph->width([$newwidth])

Return the width of the glyph, not including left or right padding.
This is ordinarily set internally based on the size of the feature and
the scale of the panel.

=item $width = $glyph->layout_width

Returns the width of the glyph including left and right padding.

=item $width = $glyph->height

Returns the height of the glyph, not including the top or bottom
padding.  This is calculated from the "height" option and cannot be
changed.


=item $font = $glyph->font

Return the font for the glyph.

=item $option = $glyph->option($option)

Return the value of the indicated option.

=item $index = $glyph->color($color)

Given a symbolic or #RRGGBB-form color name, returns its GD index.

=back

Retrieving information about the sequence:

=over 4

=item $start = $glyph->start

=item $end   = $glyph->end

These methods return the start and end of the glyph in base pair
units.

=item $offset = $glyph->offset

Returns the offset of the segment (the base pair at the far left of
the image).

=item $length = $glyph->length

Returns the length of the sequence segment.

=back


Retrieving formatting information:

=over 4

=item $top = $glyph->top

=item $left = $glyph->left

=item $bottom = $glyph->bottom

=item $right = $glyph->right

These methods return the top, left, bottom and right of the glyph in
pixel coordinates.

=item $height = $glyph->height

Returns the height of the glyph.  This may be somewhat larger or
smaller than the height suggested by the GlyphFactory, depending on
the type of the glyph.

=item $scale = $glyph->scale

Get the scale for the glyph in pixels/bp.

=item $height = $glyph->labelheight

Return the height of the label, if any.

=item $label = $glyph->label

Return a human-readable label for the glyph.

=back

These methods are called by Bio::Graphics::Track during the layout
process:

=over 4

=item $glyph->move($dx,$dy)

Move the glyph in pixel coordinates by the indicated delta-x and
delta-y values.

=item ($x1,$y1,$x2,$y2) = $glyph->box

Return the current position of the glyph.

=back

These methods are intended to be overridden in subclasses:

=over 4

=item $glyph->calculate_height

Calculate the height of the glyph.

=item $glyph->calculate_left

Calculate the left side of the glyph.

=item $glyph->calculate_right

Calculate the right side of the glyph.

=item $glyph->draw($gd,$left,$top)

Optionally offset the glyph by the indicated amount and draw it onto
the GD::Image object.


=item $glyph->draw_label($gd,$left,$top)

Draw the label for the glyph onto the provided GD::Image object,
optionally offsetting by the amounts indicated in $left and $right.

=back

These methods are useful utility routines:

=over 4

=item $pixels = $glyph->map_pt($bases);

Map the indicated base position, given in base pair units, into
pixels, using the current scale and glyph position.

=item $glyph->filled_box($gd,$x1,$y1,$x2,$y2)

Draw a filled rectangle with the appropriate foreground and fill
colors, and pen width onto the GD::Image object given by $gd, using
the provided rectangle coordinates.

=item $glyph->filled_oval($gd,$x1,$y1,$x2,$y2)

As above, but draws an oval inscribed on the rectangle.

=back

=head2 OPTIONS

The following options are standard among all Glyphs.  See individual
glyph pages for more options.

  Option      Description               Default
  ------      -----------               -------

  -fgcolor    Foreground color		black

  -outlinecolor				black
	      Synonym for -fgcolor

  -bgcolor    Background color          white

  -fillcolor  Interior color of filled  turquoise
	      images

  -linewidth  Width of lines drawn by	1
		    glyph

  -height     Height of glyph		10

  -font       Glyph font		gdSmallFont

  -label      Whether to draw a label	false

You may pass an anonymous subroutine to -label, in which case the
subroutine will be invoked with the feature as its single argument.
The subroutine must return a string to render as the label.

=head1 SUBCLASSING Bio::Graphics::Glyph

By convention, subclasses are all lower-case.  Begin each subclass
with a preamble like this one:

 package Bio::Graphics::Glyph::crossbox;

 use strict;
 use vars '@ISA';
 @ISA = 'Bio::Graphics::Glyph';

Then override the methods you need to.  Typically, just the draw()
method will need to be overridden.  However, if you need additional
room in the glyph, you may override calculate_height(),
calculate_left() and calculate_right().  Do not directly override
height(), left() and right(), as their purpose is to cache the values
returned by their calculating cousins in order to avoid time-consuming
recalculation.

A simple draw() method looks like this:

 sub draw {
  my $self = shift;
  $self->SUPER::draw(@_);
  my $gd = shift;

  # and draw a cross through the box
  my ($x1,$y1,$x2,$y2) = $self->calculate_boundaries(@_);
  my $fg = $self->fgcolor;
  $gd->line($x1,$y1,$x2,$y2,$fg);
  $gd->line($x1,$y2,$x2,$y1,$fg);
 }

This subclass draws a simple box with two lines criss-crossed through
it.  We first call our inherited draw() method to generate the filled
box and label.  We then call calculate_boundaries() to return the
coordinates of the glyph, disregarding any extra space taken by
labels.  We call fgcolor() to return the desired foreground color, and
then call $gd->line() twice to generate the criss-cross.

For more complex draw() methods, see Bio::Graphics::Glyph::transcript
and Bio::Graphics::Glyph::segments.

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Ace::Sequence>, L<Ace::Sequence::Feature>, L<Bio::Graphics::Panel>,
L<Bio::Graphics::Track>, L<Bio::Graphics::Glyph::anchored_arrow>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::box>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
