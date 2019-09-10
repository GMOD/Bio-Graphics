package Bio::Graphics::Glyph::xyplot;

use strict;
#use GD 'gdTinyFont';

use base qw(Bio::Graphics::Glyph::segments Bio::Graphics::Glyph::minmax);
use constant DEFAULT_POINT_RADIUS=>4;
use Bio::Root::Version;
our $VERSION = ${Bio::Root::Version::VERSION};

use constant DEBUG=>0;
use constant EXTRA_LABEL_PAD=>8;

sub my_description { 
    return <<'END';
This glyph is used for drawing features that have a position on the
genome and a numeric value.  It can be used to represent gene
prediction scores, motif-calling scores, percent similarity,
microarray intensities, or other features that require a line plot.

The plot is designed to work on a single feature group that contains
subfeatures. It is the subfeatures that carry the score
information. For a more efficient implementation that is suitable for
dense genome-wide data, use Bio::Graphics::Wiggle and the
wiggle_xyplot glyph.
END

}
sub my_options {
    {
	point_radius => [
	      'integer',
	      1,
	      'When drawing data points, this specifies the radius of each point.',
	    ],
	 clip => [
	     'boolean',
	     0,
	     'If min_score and/or max_score are manually specified,',
	     'then setting this to true will cause values outside the',
	     'range to be clipped.'
	    ],
	 graph_type => [
	     ['histogram','line','points','linepoints'],
	     'histogram',
	     'Type of graph to generate. Options are "boxes",',
	     '"line","points", or "linepoints".',
	     'The deprecated "boxes" subtype is equivalent to "histogram".'
	     ],
	 point_symbol => [
	     'string',
	     'none',
	     'Symbol to use for each data point when drawing line graphs.',
	     'Options are "triangle", "square", "disc", "filled_triangle",',
	     '"filled_square", "filled_disc", "point" and "none"',
	 ],
	 scale => [
	     'string',
	     'three',
	     'Position where the Y axis scale is drawn, if any.',
	     'Options are one of "left", "right", "both", "three" or "none".',
	     '"three" will cause the scale to be drawn in the left, right and center.',
	 ],

	 scale_color => [
	     'color',
	     'fgcolor',
	     'Color of the X and Y scales. Defaults to the same as fgcolor.',
	 ],
    };
}

my %SYMBOLS = (
	       triangle => \&draw_triangle,
	       square   => \&draw_square,
	       disc     => \&draw_disc,
	       point    => \&draw_point,
	      );

sub extra_label_pad {
    return EXTRA_LABEL_PAD;
}

# Default pad_left is recursive through all parts. We certainly
# don't want to do this for all parts in the graph.
sub pad_left {
  my $self = shift;
  return 0 unless $self->level == 0;
  my $left = $self->SUPER::pad_left(@_);
  my $side = $self->_determine_side;
  $left += $self->extra_label_pad if $self->label_position eq 'left' && $side =~ /left|both|three/;
  return $left;
}

# Default pad_left is recursive through all parts. We certainly
# don't want to do this for all parts in the graph.
sub pad_right {
  my $self = shift;
  return 0 unless $self->level == 0;
  return $self->SUPER::pad_right(@_);
}

sub point_radius {
  shift->option('point_radius') || DEFAULT_POINT_RADIUS;
}

sub pad_top {
  my $self = shift;
  my $pad = $self->Bio::Graphics::Glyph::generic::pad_top(@_);
  if ($pad < $self->font_height($self->getfont('gdTinyFont'))+8) {
      $pad = $self->font_height($self->getfont('gdTinyFont'))+8;  # extra room for the scale
  }
  $pad;
}

sub pad_bottom {
  my $self = shift;
  my $pad  = $self->Bio::Graphics::Glyph::generic::pad_bottom(@_);
  if ($pad < $self->font_height($self->getfont('gdTinyFont'))/4) {
      $pad = $self->font_height($self->getfont('gdTinyFont'))/4;  # extra room for the scale
  }
  $pad;
}

sub scalecolor {
  my $self = shift;
  local $self->{default_opacity} = 1;
  my $color = $self->color('scale_color') || $self->fgcolor;
}

sub default_scale
{
  return 'three';
}

sub record_label_positions { 
    my $self = shift;
    my $rlp  = $self->option('record_label_positions');
    return $rlp if defined $rlp;
    return -1;
}

sub graph_type {
    my $self = shift;
	$self->option('graph_type')       || 
	$self->option('graphtype')        ||
	'boxes';
}

sub draw {
  my $self = shift;
  my ($gd,$dx,$dy) = @_;

  my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);
  my @parts = $self->parts;

  return $self->SUPER::draw(@_) unless @parts > 0;

  $self->panel->startGroup($gd);

  my ($min_score,$max_score) = $self->minmax(\@parts);

  my $side = $self->_determine_side();

  # if a scale is called for, then we adjust the max and min to be even
  # multiples of a power of 10.
  if ($side) {
    $max_score = max10($max_score);
    $min_score = min10($min_score);
  }

  my $height = $bottom - $top;
  my $scale  = $max_score > $min_score ? $height/($max_score-$min_score)
                                       : 1;
  my $x = $left;
  my $y = $top + $self->pad_top;

  # position of "0" on the scale
  my $y_origin = $min_score <= 0 ? $bottom - (0 - $min_score) * $scale : $bottom;
  $y_origin    = $top if $max_score < 0;

  my $clip_ok = $self->option('clip');
  $self->{_clip_ok}   = $clip_ok;
  $self->{_scale}     = $scale;
  $self->{_min_score} = $min_score;
  $self->{_max_score} = $max_score;
  $self->{_top}       = $top;
  $self->{_bottom}    = $bottom;

  # now seed all the parts with the information they need to draw their positions
  foreach (@parts) {
    my $s = $_->score;
    $_->{_y_position}   = $self->score2position($s);
    warn "y_position = $_->{_y_position}" if DEBUG;
  }
  my $type           = $self->option('graph_type') || $self->option('graphtype') || 'boxes';
  my (@draw_methods) = $self->lookup_draw_method($type);
  $self->throw("Invalid graph type '$type'") unless @draw_methods;

  $self->panel->startGroup($gd);
  $self->_draw_grid($gd,$scale,$min_score,$max_score,$dx,$dy,$y_origin);

  $self->panel->endGroup($gd);

  for my $draw_method (@draw_methods) {
    $self->$draw_method($gd,$dx,$dy,$y_origin);
  }

  $self->panel->startGroup($gd);
  $self->_draw_scale($gd,$scale,$min_score,$max_score,$dx,$dy,$y_origin);
  $self->panel->endGroup($gd);
  
  $self->draw_label(@_)       if $self->option('label') or $self->record_label_positions;
  $self->draw_description(@_) if $self->option('description');
  $self->draw_legend(@_)      if $self->option('overlay');

  $self->panel->endGroup($gd);
}

sub lookup_draw_method {
  my $self = shift;
  my $type = shift;

  return '_draw_boxes'                if $type eq 'histogram';  # same thing
  return '_draw_boxes'                if $type eq 'boxes';
  return qw(_draw_line _draw_points)  if $type eq 'linepoints';
  return '_draw_line'                 if $type eq 'line';
  return '_draw_points'               if $type eq 'points';
  return;
}

sub normalize_track {
    my $self  = shift;
    my @glyphs_in_track = @_;
    my ($global_min,$global_max);
    for my $g (@glyphs_in_track) {
	my ($min_score,$max_score) = $g->minmax($g->get_parts);
	$global_min = $min_score if !defined $global_min || $min_score < $global_min;
	$global_max = $max_score if !defined $global_max || $max_score > $global_max;
    }
    # note that configure applies to the whole track
    $glyphs_in_track[0]->configure(-min_score => $global_min);
    $glyphs_in_track[0]->configure(-max_score => $global_max);
}

sub get_parts {
    my $self = shift;
    my @parts = $self->parts;
    return \@parts;
}

sub score {
  my $self    = shift;
  my $s       = $self->option('score');
  return $s   if defined $s;
  return eval { $self->feature->score };
}

sub score2position {
  my $self  = shift;
  my $score = shift;

  return undef unless defined $score;

  if ($self->{_clip_ok} && $score < $self->{_min_score}) {
    return $self->{_bottom};
  }

  elsif ($self->{_clip_ok} && $score > $self->{_max_score}) {
    return $self->{_top};
  }

  else {
    warn "score = $score, _top = $self->{_top}, _bottom = $self->{_bottom}, max = $self->{_max_score}, min=$self->{_min_score}" if DEBUG;
    my $position      = ($score-$self->{_min_score}) * $self->{_scale};
    warn "position =$position" if DEBUG;
    return $self->{_bottom} - $position;
  }
}

sub log10 { log(shift)/log(10) }
sub max10 {
  my $a = shift;
  return 0 if $a==0;
  return -min10(-$a) if $a<0;
  return max10($a*10)/10 if $a < 1;

  my $l=int(log10($a));
  $l = 10**$l; 
  my $r = $a/$l;
  return $r*$l if int($r) == $r;
  return $l*int(($a+$l)/$l);
}
sub min10 {
  my $a = shift;
  return 0 if $a==0;
  return -max10(-$a) if $a<0;
  return min10($a*10)/10 if $a < 1;

  my $l=int(log10($a));
  $l = 10**$l; 
  my $r = $a/$l; 
  return $r*$l if int($r) == $r;
  return $l*int($a/$l);
}

sub _draw_boxes {
  my $self = shift;
  my ($gd,$left,$top,$y_origin) = @_;

  my @parts    = $self->parts;
  my $lw       = $self->linewidth;
  # Make the boxes transparent
  my $positive = $self->pos_color + 1073741824;
  my $negative = $self->neg_color + 1073741824;
  my $height   = $self->height;

  my $midpoint = $self->midpoint ? $self->score2position($self->midpoint) 
                                 : $y_origin;

  my $partcolor = $self->code_option('part_color');
  my $factory  = $self->factory;

  # draw each of the boxes as a rectangle
  for (my $i = 0; $i < @parts; $i++) {

    my $part = $parts[$i];
    my $next = $parts[$i+1];
	
    my ($color,$negcolor);

    # special check here for the part_color being defined so as not to introduce lots of
    # checking overhead when it isn't
    if ($partcolor) {
	$color    = $self->translate_color($factory->option($part,'part_color',0,0));
	$negcolor = $color;
    } else {
	$color    = $positive;
	$negcolor = $negative;
    }

    my ($x1,$y1,$x2,$y2) = $part->calculate_boundaries($left,$top);
    next unless defined $part->{_y_position};
    # prevent boxes from being less than 1 pixel
    $x2 = $x1+1 if $x2-$x1 < 1;
    if ($part->{_y_position} < $midpoint) {
	$gd->filledRectangle($x1,$part->{_y_position},$x2,$y_origin,$color);
    } else {
	$gd->filledRectangle($x1,$y_origin,$x2,$part->{_y_position},$negcolor);
    }
  }

  # That's it.
}

sub _draw_line {
  my $self = shift;
  my ($gd,$left,$top) = @_;

  my @parts  = $self->parts;
  my $fgcolor = $self->fgcolor;
  my $bgcolor = $self->bgcolor;

  # connect to center positions of each interval
  my $first_part = shift @parts;
  my ($x1,$y1,$x2,$y2) = $first_part->calculate_boundaries($left,$top);
  my $current_x = ($x1+$x2)/2;
  my $current_y = $first_part->{_y_position};

  for my $part (@parts) {  
    
    ($x1,$y1,$x2,$y2) = $part->calculate_boundaries($left,$top);
    my $next_x = ($x1+$x2)/2;
    my $next_y = $part->{_y_position};
    $gd->line($current_x,$current_y,$next_x,$next_y,$fgcolor)
	if defined $current_y and defined $next_y;
    ($current_x,$current_y) = ($next_x,$next_y);
  }

}

sub _draw_points {
  my $self = shift;
  my ($gd,$left,$top) = @_;
  my $symbol_name = $self->option('point_symbol') || 'point';
  my $filled      = $symbol_name =~ s/^filled_//;
  my $symbol_ref  = $SYMBOLS{$symbol_name};

  my @parts   = $self->parts;
  my $fgcolor = $self->fgcolor;
  my $bgcolor = $self->bgcolor;
  my $pr      = $self->point_radius;

  my $partcolor = $self->code_option('part_color');
  my $factory  = $self->factory;

  for my $part (@parts) {
    my ($x1,$y1,$x2,$y2) = $part->calculate_boundaries($left,$top);
    my $x = ($x1+$x2)/2;
    my $y = $part->{_y_position};
    next unless defined $y;

    my $color;
    if ($partcolor) {
      $color    = $self->translate_color($factory->option($part,'part_color',0,0));
    } else {
      $color    = $fgcolor;
    }

    $symbol_ref->($gd,$x,$y,$pr,$color,$filled);
  }
}

sub _determine_side
{
  my $self = shift;
  my $side = $self->option('scale');
  return if $side eq 'none';
  $side   ||= $self->default_scale();
  return $side;
}

sub _draw_scale {
  my $self = shift;
  my ($gd,$scale,$min,$max,$dx,$dy,$y_origin) = @_;
  my ($x1,$y1,$x2,$y2) = $self->calculate_boundaries($dx,$dy);

  my $crosses_origin = $min < 0 && $max > 0;

  my $side = $self->_determine_side() or return;

  my $fg    = $self->scalecolor;
  my $font  = $self->font('gdTinyFont');

  my $middle = ($x1+$x2)/2;

  # minor ticks - multiples of 10
  my $y_scale = $self->minor_ticks($min,$max,$y1,$y2);

  my $p  = $self->panel;
  my $gc = $self->translate_color($p->gridcolor);
  my $mgc= $self->translate_color($p->gridmajorcolor);

  $gd->line($x1,$y1,$x1,$y2,$fg) if $side eq 'left'  || $side eq 'both' || $side eq 'three';
  $gd->line($x2,$y1,$x2,$y2,$fg) if $side eq 'right' || $side eq 'both' || $side eq 'three';
  $gd->line($middle,$y1,$middle,$y2,$fg) if $side eq 'three';

  $gd->line($x1,$y_origin,$x2,$y_origin,$mgc);

  my @points = ([$y1,$max],[$y2,$min]);
  push @points,$crosses_origin ? [$y_origin,0] : [($y1+$y2)/2,($min+$max)/2];

  my $last_font_pos = -99999999999;

  for (sort {$a->[0]<=>$b->[0]} @points) {
    $gd->line($x1-3,$_->[0],$x1,$_->[0],$fg) if $side eq 'left'  || $side eq 'both' || $side eq 'three';
    $gd->line($x2,$_->[0],$x2+3,$_->[0],$fg) if $side eq 'right' || $side eq 'both' || $side eq 'three';
    $gd->line($middle,$_->[0],$middle+3,$_->[0],$fg) if $side eq 'three';

    my $font_pos = $_->[0]-($self->font_height($font)/2);
    $font_pos-=2 if $_->[1] < 0;  # jog a little bit for neg sign

    next unless $font_pos > $last_font_pos + $self->font_height($font)/2; # prevent labels from clashing
    if ($side eq 'left' or $side eq 'both' or $side eq 'three') {
      $gd->string($font,
		  $x1 - $self->string_width($_->[1],$font) - 3,$font_pos,
		  $_->[1],
		  $fg);
    }
    if ($side eq 'right' or $side eq 'both' or $side eq 'three') {
      $gd->string($font,
		  $x2 + 5,$font_pos,
		  $_->[1],
		  $fg);
    }
    if ($side eq 'three') {
      $gd->string($font,
		  $middle + 5,$font_pos,
		  $_->[1],
		  $fg);
    }
    $last_font_pos = $font_pos;
  }

  for (my $y = $y2-$y_scale; $y > $y1; $y -= $y_scale) {
      my $yr = int($y+0.5);
      $gd->line($x1-3,$yr,$x1,$yr,$fg) if $side eq 'left' or $side eq 'both' or $side eq 'three';
      $gd->line($x2,$yr,$x2+3,$yr,$fg) if $side eq 'right' or $side eq 'both' or $side eq 'three';
      $gd->line($middle-1,$yr,$middle+2,$yr,$fg) if $side eq 'three';
  }


}

sub _draw_grid {
    my $self = shift;
    my ($gd,$scale,$min,$max,$dx,$dy,$y_origin) = @_;
    my $side = $self->_determine_side();
    return unless $side;

    my ($x1,$y1,$x2,$y2) = $self->calculate_boundaries($dx,$dy);
    my $p  = $self->panel;
    my $gc = $self->translate_color($p->gridcolor);
    my $y_scale = $self->minor_ticks($min,$max,$y1,$y2);

    for (my $y = $y2-$y_scale; $y > $y1; $y -= $y_scale) {
	my $yr = int($y+0.5);
	$gd->line($x1-1,$yr,$x2,$yr,$gc);
    }
    $gd->line($x1,$y1,$x2,$y1,$gc);
    $gd->line($x1,$y2,$x2,$y2,$gc);
}

sub minor_ticks {
    my $self = shift;
    my ($min,$max,$top,$bottom) = @_;

    my $interval = 1;
    my $height   = $bottom-$top;
    my $y_scale  = 1;
    if ($max > $min) {
	while ($height/(($max-$min)/$interval) < 2) { $interval *= 10 }
	$y_scale = $height/(($max-$min)/$interval);
    }

}

# Let the feature attributes override the labelcolor
sub labelcolor {
  my $self = shift;
  my ($labelcolor) = eval {$self->feature->get_tag_values('labelcolor')};
  return $labelcolor ? $self->translate_color($labelcolor)
                     : $self->SUPER::labelcolor;
}

# we are unbumpable!
sub bump {
  return 0;
}

sub connector {
  my $self = shift;
  my $type = $self->option('graph_type');
  return 1 if $type eq 'line' or $type eq 'linepoints';
}

sub height {
  my $self = shift;
  return $self->option('graph_height') || $self->SUPER::height;
}

sub draw_description {
    my $self = shift;
    return  if $self->bump eq 'overlap';
    return $self->SUPER::draw_description(@_);
}

sub draw_triangle {
  my ($gd,$x,$y,$pr,$color,$filled) = @_;
  $pr /= 2;
  my ($vx1,$vy1) = ($x-$pr,$y+$pr);
  my ($vx2,$vy2) = ($x,  $y-$pr);
  my ($vx3,$vy3) = ($x+$pr,$y+$pr);
  my $poly = GD::Polygon->new;
  $poly->addPt($vx1,$vy1,$vx2,$vy2);
  $poly->addPt($vx2,$vy2,$vx3,$vy3);
  $poly->addPt($vx3,$vy3,$vx1,$vy1);
  if ($filled) {
    $gd->filledPolygon($poly,$color);
  } else {
    $gd->polygon($poly,$color);
  }
}

sub draw_square {
  my ($gd,$x,$y,$pr,$color,$filled) = @_;
  $pr /= 2;
  my $poly = GD::Polygon->new;
  $poly->addPt($x-$pr,$y-$pr);
  $poly->addPt($x+$pr,$y-$pr);
  $poly->addPt($x+$pr,$y+$pr);
  $poly->addPt($x-$pr,$y+$pr);
  if ($filled) {
    $gd->filledPolygon($poly,$color);
  } else {
    $gd->polygon($poly,$color);
  }
}
sub draw_disc {
  my ($gd,$x,$y,$pr,$color,$filled) = @_;
  if ($filled) {
    $gd->filledArc($x,$y,$pr,$pr,0,360,$color);
  } else {
    $gd->arc($x,$y,$pr,$pr,0,360,$color);
  }
}
sub draw_point {
  my ($gd,$x,$y,$pr,$color) = @_;
  $gd->setPixel($x,$y,$color);
}

sub keyglyph {
  my $self = shift;

  my $scale = 1/$self->scale;  # base pairs/pixel

  my $feature =
    Bio::Graphics::Feature->new(
				-segments=>[ [ 0*$scale,9*$scale],
					     [ 10*$scale,19*$scale],
					     [ 20*$scale, 29*$scale]
					   ],
				-name => 'foo bar',
				-strand => '+1');
  ($feature->segments)[0]->score(10);
  ($feature->segments)[1]->score(50);
  ($feature->segments)[2]->score(25);
  my $factory = $self->factory->clone;
  $factory->set_option(label => 1);
  $factory->set_option(bump  => 0);
  $factory->set_option(connector  => 'solid');
  my $glyph = $factory->make_glyph(0,$feature);
  return $glyph;
}

sub symbols {
    my $self = shift;
    return \%SYMBOLS;
}

sub draw_label {
    my $self = shift;
    my ($gd,$left,$top,$partno,$total_parts) = @_;
    my $label = $self->label or return;

    if ($self->bump eq 'overlap') {
	my $x    = $self->left + $left + $self->pad_left;
	$x  = $self->panel->left + 1 if $x <= $self->panel->left;
	$x += ($self->panel->glyph_scratch||0);

	my $font  = $self->labelfont;
	my $width = $self->string_width($label,$font)+4;
	my $height= $self->string_height('',$font);
	unless ($self->record_label_positions) {
	    $gd->filledRectangle($x,$top,$x+$width+6,$top+$height,$self->bgcolor);
	    local $self->{default_opacity} = 1;
	    $gd->string($font,$x+3,$top,$label,$self->contrasting_label_color($gd,$self->bgcolor));
	}
	$self->panel->glyph_scratch($self->panel->glyph_scratch + $width);
	$self->panel->add_key_box($self,$label,$x,$top) if $self->record_label_positions;

    } elsif ($self->label_position eq 'left') {
	  my $font = $self->labelfont;
	  my $x = $self->left + $left - $self->string_width($label,$font) - $self->extra_label_pad;
	  my $y = $self->{top} + $top;

	  $self->render_label($gd,
			      $font,
			      $x,
			      $y,
			      $label);

    } else {
	$self->SUPER::draw_label(@_);
    }

}

sub contrasting_label_color {
    my $self = shift;
    my ($gd,$bgcolor) = @_;
    my ($r,$g,$b)   = $gd->rgb($bgcolor);
    my $avg         = ($r+$g+$b)/3;
    return $self->translate_color($avg > 128 ? 'black' : 'white');
}

sub draw_legend {
  my $self = shift;
  my ($gd,$left,$top,$partno,$total_parts) = @_;
  return  if $self->bump eq 'overlap';

  my $color = $self->option('fgcolor'); 
  my $name = $self->feature->{name};

  my $label = "<a id=\"legend_$name\" target=\"_blank\" href=\"#\"> <font color=\'$color\';\">" . $name . "</font></a>" or return;

  my $font = $self->labelfont;
  my $x = $self->left + $left - $self->string_width($label,$font) - $self->extra_label_pad;
  my $y = $self->{top} + $top;
  my $is_legend = 1;
  $self->render_label($gd,
		      $font,
		      $x,
		      $y,
		      $label,
		      $is_legend);
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::xyplot - The xyplot glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used for drawing features that have a position on the
genome and a numeric value.  It can be used to represent gene
prediction scores, motif-calling scores, percent similarity,
microarray intensities, or other features that require a line plot.

The X axis represents the position on the genome, as per all other
glyphs.  The Y axis represents the score.  Options allow you to set
the height of the glyph, the maximum and minimum scores, the color of
the line and axis, and the symbol to draw.

The plot is designed to work on a single feature group that contains
subfeatures.  It is the subfeatures that carry the score
information. The best way to arrange for this is to create an
aggregator for the feature.  We'll take as an example a histogram of
repeat density in which interval are spaced every megabase and the
score indicates the number of repeats in the interval; we'll assume
that the database has been loaded in in such a way that each interval
is a distinct feature with the method name "density" and the source
name "repeat".  Furthermore, all the repeat features are grouped
together into a single group (the name of the group is irrelevant).
If you are using Bio::DB::GFF and Bio::Graphics directly, the sequence
of events would look like this:

  my $agg = Bio::DB::GFF::Aggregator->new(-method    => 'repeat_density',
                                          -sub_parts => 'density:repeat');
  my $db  = Bio::DB::GFF->new(-dsn=>'my_database',
                              -aggregators => $agg);
  my $segment  = $db->segment('Chr1');
  my @features = $segment->features('repeat_density');

  my $panel = Bio::Graphics::Panel->new(-pad_left=>40,-pad_right=>40);
  $panel->add_track(\@features,
                    -glyph => 'xyplot',
  		    -graph_type=>'points',
		    -point_symbol=>'disc',
		    -point_radius=>4,
		    -scale=>'both',
		    -height=>200,
  );

If you are using Generic Genome Browser, you will add this to the
configuration file:

  aggregators = repeat_density{density:repeat}
                clone alignment etc

Note that it is a good idea to add some padding to the left and right
of the panel; otherwise the scale will be partially cut off by the
edge of the image.

The "boxes" variant allows you to specify a pivot point such that
scores above the pivot point are drawn in one color, and scores below
are drawn in a different color. These "bicolor" plots are controlled
by the options -bicolor_pivot, -pos_color and -neg_color, as described
below.

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

  -label        Whether to draw a label	       0 (false)

  -description  Whether to draw a description  0 (false)

  -hilite       Highlight color                undef (no color)

In addition, the xyplot glyph recognizes the following
glyph-specific options:

  Option         Description                  Default
  ------         -----------                  -------

  -max_score   Maximum value of the	      Calculated
               feature's "score" attribute

  -min_score   Minimum value of the           Calculated
               feature's "score" attributes

  -graph_type  Type of graph to generate.     Histogram
               Options are: "histogram",
               "boxes", "line", "points",
               or "linepoints".

  -point_symbol Symbol to use. Options are    none
                "triangle", "square", "disc",
                "filled_triangle",
                "filled_square",
                "filled_disc","point",
                and "none".

  -point_radius Radius of the symbol, in      4
                pixels (does not apply
                to "point")

  -scale        Position where the Y axis     none
                scale is drawn if any.
                It should be one of
                "left", "right", "both" or "none"

  -graph_height Specify height of the graph   Same as the
                                              "height" option.

  -part_color  For boxes & points only,       none
               bgcolor of each part (should
               be a callback). Supersedes
               -neg_color.

  -scale_color Color of the scale             Same as fgcolor

  -clip        If min_score and/or max_score  false
               are manually specified, then
               setting this to true will
               cause values outside the
               range to be clipped.

  -bicolor_pivot                              0
               Where to pivot the two colors
               when drawing bicolor plots.
               Scores greater than this value will
               be drawn using -pos_color.
               Scores lower than this value will
               be drawn using -neg_color.

  -pos_color   When drawing bicolor plots,    same as bgcolor
               the fill color to use for
               values that are above 
               the pivot point.

  -neg_color   When drawing bicolor plots,    same as bgcolor
               the fill color to use for values
               that are below the pivot point.


Note that when drawing scales on the left or right that the scale is
actually drawn a few pixels B<outside> the boundaries of the glyph.
You may wish to add some padding to the image using -pad_left and
-pad_right when you create the panel.

The B<-part_color> option can be used to color each part of the
graph. Only the "boxes", "points" and "linepoints" styles are
affected by this.  Here's a simple example:

  $panel->add_track->(\@affymetrix_data,
                      -glyph      => 'xyplot',
                      -graph_type => 'boxes',
                      -part_color => sub {
                                   my $score = shift->score;
	                           return 'red' if $score < 0;
	                           return 'lightblue' if $score < 500;
                                   return 'blue'      if $score >= 500;
                                  }
                      );

=head2 METHODS

For those developers wishing to derive new modules based on this
glyph, the main method to override is:

=over 4

=item 'method_name' = $glyph-E<gt>lookup_draw_method($type)

This method accepts the name of a graph type (such as 'histogram') and
returns the name of a method that will be called to draw the contents
of the graph, for example '_draw_histogram'. This method will be
called with three arguments:

   $self->$draw_method($gd,$left,$top,$y_origin)

where $gd is the GD object, $left and $top are the left and right
positions of the whole glyph (which includes the scale and label), and
$y_origin is the position of the zero value on the y axis (in
pixels). By the time this method is called, the y axis and labels will
already have been drawn, and the scale of the drawing (in pixels per
unit score) will have been calculated and stored in
$self-E<gt>{_scale}. The y position (in pixels) of each point to graph
will have been stored into the part, as $part-E<gt>{_y_position}. Hence
you could draw a simple scatter plot with this code:

 sub lookup_draw_method {
    my $self = shift;
    my $type = shift;
    if ($type eq 'simple_scatterplot') {
      return 'draw_points';
    } else {
      return $self->SUPER::lookup_draw_method($type);
    }
 }

 sub draw_points {
  my $self = shift;
  my ($gd,$left,$top) = @_;
  my @parts   = $self->parts;
  my $bgcolor = $self->bgcolor;

  for my $part (@parts) {
    my ($x1,$y1,$x2,$y2) = $part->calculate_boundaries($left,$top);
    my $x = ($x1+$x2)/2;  # take center
    my $y = $part->{_y_position};
    $gd->setPixel($x,$y,$bgcolor);
 }

lookup_draw_method() may return multiple method names if needed. Each
will be called in turn.

=item $y_position = $self-E<gt>score2position($score)

Translate a score into a y pixel position, obeying clipping rules and
min and max values.

=back

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

