package Bio::Graphics::Glyph::wiggle_whiskers;

use strict;
use base qw(Bio::Graphics::Glyph::xyplot
            Bio::Graphics::Glyph::minmax);

sub my_description {
    return <<END;
This glyph draws quantitative data as an xyplot in which the interval
0 to mean is represented in black, mean to +/- stdev in grey, and
stdev to max/min in light grey. This colors can be customized. The
glyph currently only works for features that have a
statistical_summary() method, of which the only currently example is
Bio::DB::BigWig. The statistical_summary() method returns a hash with
the following keys:

  validCount   Number of intervals in the bin
  maxVal       Maximum value in the bin
  minVal       Minimum value in the bin
  sumData      Sum of the intervals in the bin
  sumSquares   Sum of the squares of the intervals in the bin
END
}

sub my_options {
    {
	mean_color => [
	    'color',
	    'black',
	    'The color drawn from the zero value to the mean value.'
	    ],
	mean_color_neg => [
	    'color',
	    'same as mean_color',
	    'The color drawn from the zero value to the mean value, for negative values.'
	    ],
	stdev_color => [
	    'color',
	    'grey',
	    'The color drawn from the mean value to +stdev.'
	    ],
	stdev_color_neg => [
	    'color',
	    'same as stdev_color',
	    'The color drawn from the mean value to -stdev.'
	    ],
	max_color => [
	    'color',
	    'lightgrey',
	    'The color drawn from +stdev to max.'
	    ],
	min_color => [
	    'color',
	    'same as max_color',
	    'The color drawn from -stdev to min.'
	],
	graph_type => [
	    'string',
	    'boxes',
	    'Type of graph to generate. Options are "boxes" (for a barchart),',
	    'or "whiskers" (for a whiskerplot showing mean, +/- stdev and max/min.'
	],
    }
}

sub graph_type {
    shift->option('graph_type') || 'boxes';
}

sub mean_color {
    my $self = shift;
    return $self->color('mean_color') || $self->translate_color('black');
}

sub mean_color_neg {
    my $self = shift;
    return $self->color('mean_color_neg') || $self->mean_color;
}

sub stdev_color {
    my $self = shift;
    return $self->color('stdev_color') || $self->translate_color('grey');
}

sub stdev_color_neg {
    my $self = shift;
    return $self->color('stdev_color_neg') || $self->stdev_color;
}
sub max_color {
    my $self = shift;
    return $self->color('max_color') || $self->translate_color('lightgrey');
}

sub min_color {
    my $self = shift;
    return $self->color('min_color') || $self->max_color;
}

sub draw {
  my $self = shift;
  my ($gd,$dx,$dy) = @_;
  my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);

  $self->panel->startGroup($gd);

  my $feature = $self->feature;
  my $stats = eval {$feature->statistical_summary($self->width)};
  unless ($stats) {
      warn "This glyph only works properly with features that have a statistical_summary() method";
      return;
  }

  my ($min_score,$max_score) = $self->minmax($stats);

  my $side = $self->_determine_side();

  # if a scale is called for, then we adjust the max and min to be even
  # multiples of a power of 10.
  if ($side) {
    $max_score = Bio::Graphics::Glyph::xyplot::max10($max_score);
    $min_score = Bio::Graphics::Glyph::xyplot::min10($min_score);
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

  $self->_draw_whiskers($gd,$dx,$dy,$y_origin,$stats);

  $self->panel->startGroup($gd);
  $self->_draw_scale($gd,$scale,$min_score,$max_score,$dx,$dy,$y_origin);
  $self->panel->endGroup($gd);

  $self->draw_label(@_)       if $self->option('label');
  $self->draw_description(@_) if $self->option('description');

  $self->panel->endGroup($gd);
}

sub minmax {
    my $self  = shift;
    my $stats = shift;

    my $max_score = $self->max_score;
    my $min_score = $self->min_score;

    my $do_min = !defined $min_score;
    my $do_max = !defined $max_score;

    if ($do_min || $do_max) {
	for my $bin (@$stats) {
	    $min_score = $bin->{minVal} if $do_min && 
		(!defined $min_score || $min_score > $bin->{minVal});
	    $max_score = $bin->{maxVal} if $do_max &&
		(!defined $max_score || $max_score < $bin->{maxVal});
	}
    }
    return ($min_score,$max_score);
}

sub _draw_whiskers {
    my $self = shift;
    my ($gd,$dx,$dy,$origin,$stats) = @_;
    my $scale = $self->{_scale};

    my $mean_color  = $self->mean_color;
    my $mean_color_neg  = $self->mean_color_neg;
    my $stdev_color = $self->stdev_color;
    my $stdev_color_neg = $self->stdev_color_neg;
    my $max_color   = $self->max_color;
    my $min_color   = $self->min_color;

    my $graph_type = $self->graph_type;

    my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);
    my $pos = $self->{flip} ? $right : $left;

    for my $bin (@$stats) {
	next unless $bin->{validCount};
	my $mean  = $bin->{sumData}/$bin->{validCount};
	my $stdev = $self->calcStdFromSums($bin->{sumData},
					   $bin->{sumSquares},
					   $bin->{validCount});
	my $max   = $bin->{maxVal};
	my $min   = $bin->{minVal};

	my $mean_pos = $self->score2position($mean);
	my $plus_one = $self->score2position($mean+$stdev);
	my $minus_one = $self->score2position($mean-$stdev);
	my $max_pos  = $self->score2position($max);
	my $min_pos   = $self->score2position($min);

	if ($graph_type eq 'boxes') {
	    if ($mean >= 0) {
		$gd->line($pos,$origin,$pos,$mean_pos,$mean_color);
		$gd->line($pos,$mean_pos,$pos,$plus_one,$stdev_color) if $mean_pos != $plus_one;
		$gd->line($pos,$plus_one,$pos,$max_pos,$max_color)    if $plus_one != $max_pos;
	    } else {
		$gd->line($pos,$origin,$pos,$mean_pos,$mean_color_neg);
		$gd->line($pos,$mean_pos,$pos,$minus_one,$stdev_color_neg) if $mean_pos != $minus_one;
		$gd->line($pos,$minus_one,$pos,$min_pos,$min_color)         if $minus_one != $min_pos;
	    }
	} 
	else {
	    $gd->setPixel($pos,$mean_pos,$mean_color);
	    $gd->line($pos,$mean_pos-1,$pos,$plus_one,$stdev_color)        if $plus_one != $mean_pos;
	    $gd->line($pos,$plus_one-1,$pos,$max_pos,$max_color)           if $max_pos != $mean_pos;
	    $gd->line($pos,$mean_pos+1,$pos,$minus_one,$stdev_color)       if $minus_one != $mean_pos;
	    $gd->line($pos,$minus_one+1,$pos,$min_pos,$min_color)          if $min_pos != $mean_pos;
	}
	
    } continue {
	$self->{flip} ? $pos-- : $pos++;
    }
}

sub calcStdFromSums {
    my $self = shift;
    my ($sum,$sumSquares,$n) = @_;
    my $var = $sumSquares - $sum*$sum/$n;
    if ($n > 1) {
	$var /= $n-1;
    }
    return 0 if $var < 0;
    return sqrt($var);
}

1;

