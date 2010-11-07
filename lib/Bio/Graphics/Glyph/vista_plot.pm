package Bio::Graphics::Glyph::vista_plot;

use strict;
use base qw(Bio::Graphics::Glyph::wiggle_minmax
            Bio::Graphics::Glyph::wiggle_xyplot 
            Bio::Graphics::Glyph::wiggle_density
            Bio::Graphics::Glyph::wiggle_whiskers
            Bio::Graphics::Glyph::heat_map 
            Bio::Graphics::Glyph::smoothing); 

use Bio::Graphics::Glyph::wiggle_density;
# qw(draw_segment);

our $VERSION = '1.0';

sub my_options {
    {
        start_color =>  [
            'color',
            'white',
            'Beginning of the color gradient, expressed as a named color or',
            'RGB hex string.'],
        end_color   => [
            'color',
            'red',
            'End of the color gradient.'],
        min_peak => [
            'integer',
            1,
            "Minimum value of the peak feature's \"score\" attribute."],
        max_peak => [
            'integer',
            255,
            "Maximum value of the peak feature's \"score\" attribute."],
        min_score => [
            'integer',
            undef,
            "Minimum value of the signal graph feature's \"score\" attribute."],
        max_score => [
            'integer',
            undef,
            "Maximum value of the signal graph feature's \"score\" attribute."],
        peakwidth => [
            'integer',
            3,
            "Line width determine the thickness of the line representing a peak."],
        glyph_subtype => [
	    ['peaks+signal','peaks','signal','density'],
            'vista',
            "What to show, peaks or signal, both (vista plot) or density graph."],
        graph_type => [
	     ['whiskers','histogram','boxes','line','points','linepoints'],
            'whiskers',
            "Type of signal graph to show."],
	alpha  => [
	    'integer',
	    100,
	    "Alpha transparency of peak regions",
	],
    };
}

sub my_description {
    return <<END;
This glyph draws peak calls (features with discreet boundaries,
i.e. putative transcription sites, over signal graph (wiggle_xyplot)
requires a special load gff file that uses attributes 'wigfile' and 'peak_type'
BigWig support is available also, see POD documentation for more details

Example:

2L   chip_seq  vista    5407   23011573    .     .     .     Name=Chip-Seq Experiment 1;wigfile=SomeWigFile.wigdb;peak_type=transcript_region:exp1

END
}


BEGIN {
  no strict 'refs';

  my @subs = qw/ h_start   s_start   v_start h_range s_range  v_range
                 min_peak_score max_peak_score low_rgb low_hsv high_rgb peak_score_range/;

  for my $sub ( @subs ) {
    *{$sub} = sub {
      my ($self, $v) = @_;
      my $k = "_$sub";

      if (defined $v) {
        $self->{$k} = $v;
      }

      return $self->{$k};
    }
  }
}

sub peakwidth {
  shift->option('peakwidth') || 3;
}

sub alpha_c {
    my $self = shift;
    return $self->option('alpha') || 100;
}

# Need to override wiggle_xyplot padding function to enable adequate height control in density mode
sub pad_top {
  my $self = shift;
  return 0 if $self->glyph_subtype eq 'density';
  my $pad = $self->Bio::Graphics::Glyph::generic::pad_top(@_);
  if ($pad < ($self->font('gdTinyFont')->height)) {
    $pad = $self->font('gdTinyFont')->height;  # extra room for the scale
  }
  $pad;
}

sub bigwig_summary {
    my $self = shift;
    my $d    = $self->{bigwig_summary};
    $self->{bigwig_summary} = shift if @_;
    $d;
}

# Need to override this too b/c we need unconventional mean and stdev calculation
sub global_mean_and_variance {
    my $self = shift;
    if (my $wig = $self->wig) {
        return ($wig->mean,$wig->stdev);
    } elsif (my $sum = $self->bigwig_summary){
        return eval{($sum->global_mean,$sum->global_stdev)};
    }
    return;
}

sub glyph_subtype {
    my $self = shift;
    my $only_show = $self->option('only_show') || $self->option('glyph_subtype') || 'vista';
    $only_show    = 'vista' if $only_show eq 'both' || $only_show eq 'peaks+signal';
    return $only_show;
}

sub graph_type {
    my $self = shift;
    return $self->option('graph_type') || 'whiskers';
}

# we override the draw method so that it dynamically creates the parts needed
# from the wig file rather than trying to fetch them from the database
sub draw {
    my $self = shift;
    my($gd,$dx,$dy) = @_;

    my $only_show = $self->glyph_subtype;
    my $feature   = $self->feature;
 
    # Draw dual graph if we have both types of attributes, BigWig and wiggle format supported
    my %features = (wig=>$feature->attributes('wigfile'),
		    peak=>$feature->attributes('peak_type'),
		    fasta=>$feature->attributes('fasta'));
    $self->panel->startGroup($gd);
    $self->draw_signal($only_show,\%features,@_) if $only_show =~ /signal|density|vista/;
    $self->draw_peaks(\%features,@_)             if $features{peak} && $only_show =~ /peaks|vista|both/;
    $self->panel->endGroup($gd);
}

sub draw_signal {
    my $self        = shift;
    my $signal_type = shift;
    my $paths       = shift;

    my $feature  = $self->feature;

    # Signal Graph drawing:
    if ($paths->{wig} && $paths->{wig}=~/\.wi\w{1,3}$/) {
	eval "require Bio::Graphics::Wiggle" unless Bio::Graphics::Wiggle->can('new');
	my $wig = eval { Bio::Graphics::Wiggle->new($paths->{wig}) };
	$self->wig($paths->{wig});
	$self->draw_wigfile($feature,$self->wig($wig),@_);
    } elsif ($paths->{wig} && $paths->{wig}=~/\.bw$/i) { 
	eval "use Bio::DB::BigWig 'binMean'" unless Bio::DB::BigWig->can('new');
	my @args = (-bigwig => "$paths->{wig}");
	if ($paths->{fasta}) {
	    eval "use Bio::DB::Sam"              unless Bio::DB::Sam::Fai->can('open');
	    my $fasta_accessor = Bio::DB::Sam::Fai->can('open') ? Bio::DB::Sam::Fai->open("$paths->{fasta}")
		                                                : Bio::DB::Fasta->new("$paths->{fasta}");
	    push @args,(-fasta  => $fasta_accessor);
	}
	my $bigwig = Bio::DB::BigWig->new(@args);
	my ($summary) = $bigwig->features(-seq_id => $feature->segment->ref,
					  -start  => $self->panel->start,
					  -end    => $self->panel->end,
					  -type   => 'summary');

	if ($signal_type ne 'density' and  $self->graph_type eq 'whiskers') {
	    local $self->{feature} = $summary;
	    $self->Bio::Graphics::Glyph::wiggle_whiskers::draw(@_);
	} else {
	    my $stats = $summary->statistical_summary($self->width);
	    my @vals  = map {$_->{validCount} ? Bio::DB::BigWig::binMean($_) : 0} @$stats; 
	    $self->bigwig_summary($summary);
	    $signal_type eq 'density' ? $self->Bio::Graphics::Glyph::wiggle_density::draw_coverage($feature,\@vals,@_) 
		                      : $self->Bio::Graphics::Glyph::wiggle_xyplot::draw_coverage($feature,\@vals,@_);
	}
    }
}

sub draw_peaks {
    my $self = shift;
    my $paths = shift;
    my($gd,$dx,$dy) = @_;
    my($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);

    # Peak drawing:
    my $alpha_c = $self->alpha_c;
    my $feature = $self->feature;
    
    my $p_type = $paths->{peak};
    my @peaks = $self->peaks();
    my $x_scale     = $self->scale;
    my $panel_start = $self->panel->start;
    my $f_start     = $feature->start > $panel_start
	? $feature->start
	: $panel_start;  
    my $lw  = $self->peakwidth;
    my($max_s,$min_s) = ($self->option('max_peak'),$self->option('min_peak'));
    $max_s          = 255 if !defined $max_s;
    $min_s          = 1   if !defined $min_s;
    my $grad_ok = 0;
    if (defined $max_s && defined $min_s) {
	$grad_ok = $self->calculate_gradient($min_s,$max_s);
    }

    foreach my $peak (@peaks) {
	my $x1     = $left    + ($peak->{start} - $f_start) * $x_scale;
	my $x2     = $left    + ($peak->{stop}  - $f_start) * $x_scale;
	if ($x2 >= $left and $x1 <= $right) {
	    my $y1     = $top;
	    my $y2     = $bottom; 
	    $x1        = $left   if $x1 < $left;
	    $x2        = $right  if $x2 > $right;
	    $alpha_c = $alpha_c <=127 ? $alpha_c : 0; # Reset to zero if illegal value is passed
	    my $score = $peak->{score};
	    if ($score eq "."){$score = 255;} # Set score to 255 if peak is unscored 
	    my $color;
	    if ($grad_ok && defined $score && $score!=255) {
		my @rgb = $self->Bio::Graphics::Glyph::heat_map::calculate_color($score,
										 $self->min_peak_score,
										 $self->max_peak_score,
										 $self->peak_score_range);
		$color = $self->color_index(@rgb);
	    }else{
		$color = $self->fgcolor;
	    }

	    my $bgcolor = $self->bgcolor;
		
	    if($alpha_c > 0){
		$gd->alphaBlending(1);
		$bgcolor = $self->add_alpha($gd,$bgcolor,$alpha_c);
	    }
	    
	    $self->filled_box($gd,int($x1+0.5),int($y1+0.5),int($x2+0.5),int($y2+0.5),$bgcolor,$bgcolor,0.5) if abs($y2-$y1) > 0;
	    $gd->setThickness($lw);
	    $gd->line(int($x1+0.5),int($y1+0.5),int($x2+0.5),int($y1+0.5),$color);
	    $gd->setThickness(1);
	}
    }
}

# Adding alpha channel to a color:
sub add_alpha {
 my($self,$im,$color,$alpha) = @_;
 my($r,$g,$b) = $im->rgb($color);
 return $im->colorAllocateAlpha($r,$g,$b,$alpha);
}

# Slightly modified function from heat_map.pm
sub calculate_gradient {
  my($self, $min, $max) = @_;
  my $start_color = lc $self->option('start_color') || 'white';
  my $stop_color  = lc $self->option('end_color')   || 'red';
  my $hsv_start   = $self->color2hsv($start_color);
  my $hsv_stop    = $self->color2hsv($stop_color);

  my ($h_start,$s_start,$v_start) = @$hsv_start;
  my ($h_stop,$s_stop,$v_stop )   = @$hsv_stop;

  my $s_range = abs($s_stop - $s_start);
  my $v_range = abs($v_stop - $v_start);

  my $h_range;
  # special case: if start hue = end hue, we want to go round
  # the whole wheel once. Otherwise round the wheel clockwise
  # or counterclockwise depending on start and end coordinate
  if ($h_start != $h_stop) {
   my $direction = abs($h_stop - $h_start)/($h_stop - $h_start);
   my ($sstart,$sstop) = sort {$a <=> $b} ($h_start,$h_stop);
   $direction *= -1 if $sstop - $sstart > 256/2; #reverse the direction if we cross 0
   $h_range = ($sstop - $sstart) <= 256/2 ? ($sstop - $sstart)*$direction : (256 - $sstop + $sstart)*$direction;
  }
  else {
   $h_range = 256;
  }
 # darkness or monochrome gradient?
  if ( !_isa_color($start_color) || !_isa_color($stop_color) ) {
    # hue (H) is fixed
    $h_range = 0;

    #    gradient         S       V    
    # white -> color    0->255   255
    # color -> white    255->0   255
    # white -> black    0        255->0
    # black -> white    0        0->255
    # black -> color    0->255   0->255
    # color -> black    255->0   255->0
    if ( $start_color eq 'white' && _isa_color($stop_color) ) {
      $s_range = 255;
      $s_start = 0;
      $v_range = 0;
      $v_start = 255;
      $h_start = $h_stop;
    }
    elsif ( _isa_color($start_color) && $stop_color eq 'white' ) {
      $s_range = -255;
      $s_start = 255;
      $v_range = 0;
      $v_start = 255;
    }
    elsif ( $start_color eq 'white' ) { # end black
      $s_range = 0;
      $s_start = 0;
      $v_range = -255;
      $v_start = 255;
    }
    elsif ( $stop_color eq 'white' ) { # start black
      $s_range = 0;
      $s_start = 0;
      $v_range = 255;
      $v_start = 0;
    }
    elsif ( _isa_color($start_color) ) { # end black
      $s_range = 255;
      $s_start = 0;
      $v_range = 255;
      $v_start = 0;
    }
    elsif ( _isa_color($stop_color) ) { # start black
      $s_range = -255;
      $s_start = 255;
      $v_range = -255;
      $v_start = 255;
    }

  }

  # store gradient info
  $self->h_range($h_range);
  $self->h_start($h_start);
  $self->s_start($s_start);
  $self->v_start($v_start);
  $self->s_range($s_range);
  $self->v_range($v_range);

  # store score info
  $self->peak_score_range($max - $min);
  $self->min_peak_score($min);
  $self->max_peak_score($max);

  # store color extremes
  my @low_rgb  = $self->HSVtoRGB(@$hsv_start);
  my @high_rgb = $self->HSVtoRGB(@$hsv_stop);
  $self->low_hsv($hsv_start);
  $self->high_rgb(\@high_rgb);
  $self->low_rgb(\@low_rgb);
  return 1;
}


sub _isa_color {
  my $color = shift;
  return $color =~ /white|black|FFFFFF|000000/i ? 0 : 1;
}

sub level { -1 }

# Need to override this so we have a nice image map for overlayed peaks
sub boxes {
  my $self = shift;

  return if $self->glyph_subtype eq 'density'; # No boxes for density plot
  my($left,$top,$parent) = @_;
  
  my $feature = $self->feature;
  my @result;
  my($handle) = $feature->attributes('peak_type');
  
  if (!$handle) {
   return wantarray ? () : \();
  }

  $parent ||=$self;
  $top  += 0; $left += 0;
  
  if ($handle)  {
   my @peaks = $self->peaks;
   $self->add_feature(@peaks);
 
   my $x_scale = $self->scale;
   my $panel_start = $self->panel->start;
   my $f_start     = $feature->start > $panel_start
                      ? $feature->start
                      : $panel_start;

   for my $part ($self->parts) { 
    my $x1 = int(($part->{start} - $f_start) * $x_scale);
    my $x2 = int(($part->{stop}  - $f_start) * $x_scale);
    my $y1 = 0;
    my $y2 = $part->height + $self->pad_top;
    $x2++ if $x1==$x2;
    next if $x1 <= 0;
    push @result,[$part->feature,
                  $left + $x1,$top+$self->top+$self->pad_top+$y1,
                  $left + $x2,$top+$self->top+$self->pad_top+$y2,
                  $parent];
   }
  }

  return wantarray ? @result : \@result;
}


# Modified and fused functions from wiggle_density.pm and wiggle_xyplot.pm
sub _draw_wigfile {
    my $self = shift;
    my $feature = shift;
    my $wig     = shift;

    $wig->smoothing($self->get_smoothing);
    $wig->window($self->smooth_window);

    my ($gd,$left,$top) = @_;
    my ($start,$end) = $self->effective_bounds($feature); 

    if ($self->glyph_subtype eq 'density') {
     my ($x1,$y1,$x2,$y2) = $self->bounds($left,$top);
     $self->draw_segment($gd,
                         $start,$end,
                         $wig,$start,$end,
                         1,1,
                         $x1,$y1,$x2,$y2);
     $self->draw_label(@_)       if $self->option('label');
     $self->draw_description(@_) if $self->option('description');
    } else {
     my ($start,$end) = $self->effective_bounds($feature);
     $self->wig($wig);
     my $parts = $self->create_parts_for_dense_feature($wig,$start,$end);
     $self->draw_plot($parts,@_);
    }
}

sub draw_segment {
  my $self = shift;
  my ($gd,
      $start,$end,
      $seg_data,
      $seg_start,$seg_end,
      $step,$span,
      $x1,$y1,$x2,$y2) = @_;

  # clip, because wig files do no clipping
  $seg_start = $start      if $seg_start < $start;
  $seg_end   = $end        if $seg_end   > $end;

  # figure out where we're going to start
  my $scale           = $self->scale;  # pixels per base pair
  my $pixels_per_span = $scale * $span + 1;
  my $pixels_per_step = 1;
  my $length          = $end-$start+1;

  # if the feature starts before the data starts, then we need to draw
  # a line indicating missing data (this only happens if something went
  # wrong upstream)
  if ($seg_start > $start) {
    my $terminus = $self->map_pt($seg_start);
    $start = $seg_start;
    $x1    = $terminus;
  }
  # if the data ends before the feature ends, then we need to draw
  # a line indicating missing data (this only happens if something went
  # wrong upstream)
  if ($seg_end < $end) {
    my $terminus = $self->map_pt($seg_end);
    $end = $seg_end;
    $x2    = $terminus;
  }

  return unless $start < $end;

  # get data values across the area
  my $samples = $length < $self->panel->width ? $length
                                              : $self->panel->width;
  my $data    = ref $seg_data eq 'ARRAY' ? $seg_data
                                         : $seg_data->values($start,$end,$samples);

  # scale the glyph if the data end before the panel does
  my $data_width = $end - $start;
  my $data_width_ratio;
  if ($data_width < $self->panel->length) {
    $data_width_ratio = $data_width/$self->panel->length;
  }
  else {
    $data_width_ratio = 1;
  }

  return unless $data && ref $data && @$data > 0;

  my ($min_value,$max_value) = $self->Bio::Graphics::Glyph::wiggle_minmax::minmax($data);
  my $t = 0; for (@$data) {$t+=$_}

  # allocate colors
  # There are two ways to do this. One is a scale from min to max. The other is a
  # bipartite scale using one color range from zero to min, and another color range
  # from 0 to max. The latter behavior is triggered when the config file contains
  # entries for "pos_color" and "neg_color" and the data ranges from < 0 to > 0.

  my $poscolor       = $self->pos_color;
  my $negcolor       = $self->neg_color;

  my $data_midpoint  =   $self->midpoint;
  my $bicolor   = $poscolor != $negcolor
                       && $min_value < $data_midpoint
                       && $max_value > $data_midpoint;

  my ($rgb_pos,$rgb_neg,$rgb);
  if ($bicolor) {
      $rgb_pos = [$self->panel->rgb($poscolor)];
      $rgb_neg = [$self->panel->rgb($negcolor)];
  } else {
      $rgb = $max_value > $min_value ? ([$self->panel->rgb($poscolor)] || [$self->panel->rgb($self->bgcolor)]) 
                                     : ([$self->panel->rgb($negcolor)] || [$self->panel->rgb($self->bgcolor)]);
  }


  my %color_cache;

  @$data = reverse @$data if $self->flip;

  if (@$data <= $self->panel->width) { # data fits in width, so just draw it

    $pixels_per_step = $scale * $step;
    $pixels_per_step = 1 if $pixels_per_step < 1;
    my $datapoints_per_base  = @$data/$length;
    my $pixels_per_datapoint = $self->panel->width/@$data * $data_width_ratio;

    for (my $i = 0; $i <= @$data ; $i++) {
      my $x          = $x1 + $pixels_per_datapoint * $i;
      my $data_point = $data->[$i];
      defined $data_point || next;
      $data_point    = $min_value if $min_value > $data_point;
      $data_point    = $max_value if $max_value < $data_point;
      my ($r,$g,$b)  = $bicolor
          ? $data_point > $data_midpoint ? $self->parse_color($data_point,$rgb_pos,
                                                              $data_midpoint,$max_value)
                                         : $self->parse_color($data_point,$rgb_neg,
                                                              $data_midpoint,$min_value)
          : $self->parse_color($data_point,$rgb,
                               $min_value,$max_value);
      my $idx        = $color_cache{$r,$g,$b} ||= $self->panel->translate_color($r,$g,$b);
      $self->filled_box($gd,$x,$y1,$x+$pixels_per_datapoint,$y2,$idx,$idx);
    }

  } else {     # use Sheldon's code to subsample data
      $pixels_per_step = $scale * $step;
      my $pixels = 0;

      # only draw boxes 2 pixels wide, so take the mean value
      # for n data points that span a 2 pixel interval
      my $binsize = 2/$pixels_per_step;
      my $pixelstep = $pixels_per_step;
      $pixels_per_step *= $binsize;
      $pixels_per_step *= $data_width_ratio;
      $pixels_per_span = 2;

      my $scores = 0;
      my $defined;

      for (my $i = $start; $i < $end ; $i += $step) {
        # draw the box if we have accumulated >= 2 pixel's worth of data.
        if ($pixels >= 2) {
          my $data_point = $defined ? $scores/$defined : 0;
          $scores  = 0;
          $defined = 0;

          $data_point    = $min_value if $min_value > $data_point;
          $data_point    = $max_value if $max_value < $data_point;
          my ($r,$g,$b)  = $bicolor
              ? $data_point > $data_midpoint ? $self->parse_color($data_point,$rgb_pos,
                                                                  $data_midpoint,$max_value)
                                             : $self->parse_color($data_point,$rgb_neg,
                                                                  $data_midpoint,$min_value)
              : $self->parse_color($data_point,$rgb,
                                   $min_value,$max_value);
          my $idx        = $color_cache{$r,$g,$b} ||= $self->panel->translate_color($r,$g,$b);
          $self->filled_box($gd,$x1,$y1,$x1+$pixels_per_span,$y2,$idx,$idx);
          $x1 += $pixels;
          $pixels = 0;
        }

        my $val = shift @$data;
        # don't include undef scores in the mean calculation
        # $scores is the numerator; $defined is the denominator
        $scores += $val if defined $val;
        $defined++ if defined $val;

        # keep incrementing until we exceed 2 pixels
        # the step is a fraction of a pixel, not an integer
        $pixels += $pixelstep;
      }
  }
}

sub parse_color {
  my $self = shift;
  my ($s,$rgb,$min_score,$max_score) = @_;
  $s ||= $min_score;

  return 0 if $max_score==$min_score; # avoid div by zero

  my $relative_score = ($s-$min_score)/($max_score-$min_score);
  $relative_score -= .1 if $relative_score == 1;
  return map { int(254.9 - (255-$_) * min(max( $relative_score, 0), 1)) } @$rgb;
}

sub peaks {
    my $self = shift;
    return @{$self->{_peaks}} if $self->{_peaks};

    my $feature = $self->feature;
    my $db = $feature->object_store;
    my ($p_type) = $feature->attributes('peak_type');

    unless ($db && $p_type) {
	$self->{_peaks}	 = [];
	return;
    }

    my @peaks = $db->features(-seq_id => $feature->segment->ref,
			      -start  => $self->panel->start,
			      -end    => $self->panel->end,
			      -type   => $p_type); 

    $self->{_peaks} = \@peaks;
    return @{$self->{_peaks}};
}

sub min { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }

1;

=head1 NAME

Bio::Graphics::Glyph::vista_plot - The "vista_plot" glyph

=head1 SYNOPSIS

See 
L<Bio::Graphics::Glyph>, L<Bio::Graphics::Glyph::wiggle_xyplot> and L<Bio::Graphics::Glyph::heat_map>.

=head1 DESCRIPTION

This glyph draws peak calls (features with discreet boundaries,
i.e. putative transcription sites, over signal graph (wiggle_xyplot)
requires a special load gff file that uses attributes 'wigfile' and 'peak_type'

B<Example:>

2L  chip_seq  vista  5407   23011573  .  .  .  Name=ChipSeq Exp 1;wigfile=SomeWigFile.wigdb;peak_type=binding_site:exp1

The glyph will draw the wiggle file first, than overlay the peaks (if there are any)
over signal graph. Elsewhere in the GFF3 file, there should be one or more features 
of type "binding_site:exp1", e.g.:

2L  exp1  binding_site  91934  92005  .  .  .

Options like 'balloon hover' and 'link' are available to customize
interaction with peaks in detail view.

B<BigWig support:>

Supported bigwig format also requires another attribute to be supplied
in load gff file (fasta) which specifies sequence index file for the
organism in use. The data file should have the 'bw' extension - it is
used to detect the BigWig format by vista_plot

3L  chip_seq  vista   1    24543530  .  .  .   Name=ChipSeq Exp 2;wigfile=SomeBigWigFile.bw;peak_type=binding_site:exp2;fasta=YourOrganism.fasta

Note that all attributes should be present in load gff, as the code currently does not handle situation when
only some of the attributes are in gff. To omit peak or signal drawing use "" (i.e. peak_type="")
In both cases, the stanza code will look the same (only essential parameters shown):

 [VISTA_PLOT]
 feature         = vista:chip_seq
 glyph           = vista_plot
 label           = 1 
 smoothing       = mean
 smoothing_window = 10
 bump density    = 250
 autoscale       = local
 variance_band   = 1
 max_peak        = 255
 min_peak        = 1
 peakwidth       = 3
 start_color     = lightgray
 end_color       = black
 pos_color       = blue
 neg_color       = orange
 bgcolor         = orange
 alpha           = 80
 fgcolor         = black
 database        = database_with_load_gff_data
 box_subparts    = 1
 bicolor_pivot   = min
 key             = VISTA plot 

=head1 OPTIONS

Options are the same as for wiggle_xyplot and heat_map

B<Additional parameters:>

B<alpha>
set transparency for peak area.

B<glyph_subtype>
Display only 'peaks', 'signal', 'density' or 'peaks+signal'. 
Aliases for 'peaks+signal' include "both" and "vista".

B<Recommended global settings:>

for proper peak drawing transparency should be enabled
by setting 
B<truecolors=1> 
in I<GBrowse.conf> file

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>
L<Bio::Graphics::Glyph>
L<Bio::Graphics::Glyph::wiggle_xyplot>
L<Bio::Graphics::Glyph::heat_map>
L<GD>        

=head1 AUTHOR

Peter Ruzanov pruzanov@oicr.on.ca

Copyright (c) 2010 Ontario Institute for Cancer Research

 This package and its accompanying libraries is free software; you can
 redistribute it and/or modify it under the terms of the GPL (either
 version 1, or at your option, any later version) or the Artistic
 License 2.0.  Refer to LICENSE for the full license text. In addition,
 please see DISCLAIMER.txt for disclaimers of warranty.

=cut

