package Bio::Graphics::Glyph::wiggle_xyplot;

use strict;
use base qw(Bio::Graphics::Glyph::xyplot Bio::Graphics::Glyph::smoothing);
use IO::File;
use File::Spec;

# we override the draw method so that it dynamically creates the parts needed
# from the wig file rather than trying to fetch them from the database
sub draw {
  my $self = shift;
  my ($gd,$dx,$dy) = @_;

  my $feature     = $self->feature;
  my ($wigfile)   = $feature->attributes('wigfile');
  return $self->draw_wigfile($feature,$self->rel2abs($wigfile),@_) if $wigfile;

  my ($wigdata) = $feature->attributes('wigdata');
  return $self->draw_wigdata($feature,$wigdata,@_) if $wigdata;

  my ($densefile) = $feature->attributes('densefile');
  return $self->draw_densefile($feature,$self->rel2abs($densefile),@_) if $densefile;

  return $self->SUPER::draw(@_);
}

sub draw_wigfile {
  my $self = shift;
  my $feature = shift;
  my $wigfile = shift;

  eval "require Bio::Graphics::Wiggle" unless Bio::Graphics::Wiggle->can('new');
  my $wig = eval { Bio::Graphics::Wiggle->new($wigfile) };
  unless ($wig) {
      warn $@;
      return $self->SUPER::draw(@_);
  }
  $self->_draw_wigfile($feature,$wig,@_);
}

sub draw_wigdata {
    my $self    = shift;
    my $feature = shift;
    my $data    = shift;
    

    eval "require MIME::Base64" 
	unless MIME::Base64->can('decode_base64');
    my $unencoded_data = MIME::Base64::decode_base64($data);

    my $wig = eval { Bio::Graphics::Wiggle->new() };
    unless ($wig) {
	warn $@;
	return $self->SUPER::draw(@_);
    }

    $wig->import_from_wif($unencoded_data);

    $self->_draw_wigfile($feature,$wig,@_);
}

sub _draw_wigfile {
    my $self    = shift;
    my $feature = shift;
    my $wig     = shift;

    $wig->smoothing($self->get_smoothing);
    $wig->window($self->smooth_window);

    my $panel_start = $self->panel->start;
    my $panel_end   = $self->panel->end;
    my $start       = $feature->start > $panel_start ? $feature->start : $panel_start;
    my $end         = $feature->end   < $panel_end   ? $feature->end   : $panel_end;

    $self->wig($wig);
    my $parts = $self->create_parts_for_dense_feature($wig,$start,$end);
    $self->draw_plot($parts,@_);
}

sub draw_plot {
    my $self            = shift;
    my $parts           = shift;
    my ($gd,$dx,$dy)    = @_;

    my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);
    my ($min_score,$max_score)     = $self->minmax($parts);
    my $side = $self->_determine_side();

    # if a scale is called for, then we adjust the max and min to be even
    # multiples of a power of 10.
    if ($side) {
	$max_score = Bio::Graphics::Glyph::xyplot::max10($max_score);
	$min_score = Bio::Graphics::Glyph::xyplot::min10($min_score);
    }

    my $height = $bottom - $top;
    my $y_scale  = $max_score > $min_score ? $height/($max_score-$min_score)
	                                   : 1;
    my $x = $left;
    my $y = $top + $self->pad_top;
    
    my $x_scale = $self->scale;
    my $panel_start = $self->panel->start;
    my $feature     = $self->feature;
    my $f_start = $feature->start > $panel_start ? $feature->start : $panel_start;

    # position of "0" on the scale
    my $y_origin = $min_score <= 0 ? $bottom - (0 - $min_score) * $y_scale : $bottom;
    $y_origin    = $top if $max_score < 0;
    $y_origin    = int($y_origin+0.5);

    $self->_draw_scale($gd,$x_scale,$min_score,$max_score,$dx,$dy,$y_origin);

    my $lw       = $self->linewidth;
    my $positive = $self->pos_color;
    my $negative = $self->neg_color;
    my $midpoint = $self->midpoint;

    my @points = map {
	my ($start,$end,$score) = @$_;
	my $x1     = $left    + ($start - $f_start) * $x_scale;
	my $x2     = $left    + ($end   - $f_start) * $x_scale;
#	warn "($start,$end,$score, x1=$x1, x2=$x2";
	if ($x2 >= $left and $x1 <= $right) {
	    my $y1     = $bottom  - ($score - $min_score) * $y_scale;
	    my $y2     = $y_origin;
	    $y1        = $top    if $y1 < $top;
	    $y1        = $bottom if $y1 > $bottom;
	    $x1        = $left   if $x1 < $left;
	    $x2        = $right  if $x2 > $right;
 
	    my $color = $score > $midpoint ? $positive : $negative;
	    [int($x1+0.5),int($y1+0.5),int($x2+0.5),int($y2+0.5),$color,$lw];
	} else {
	    ();
	}
    } @$parts;

    my $type           = $self->option('graph_type') || $self->option('graphtype') || 'boxes';
    if ($type eq 'boxes') {
	for (@points) {
	    my ($x1,$y1,$x2,$y2,$color,$lw) = @$_;
	    $self->filled_box($gd,$x1,$y1,$x2,$y2,$color,$color,$lw);
	}
    }

    if ($type eq 'line' or $type eq 'linepoints') {
	my $current = shift @points;
	my $lw      = $self->option('linewidth');
	$gd->setThickness($lw) if $lw > 1;
	for (@points) {
	    my ($x1,$y1,$x2,$y2,$color,$lw) = @$_;
	    $gd->line(@{$current}[0,1],@{$_}[0,1],$color);
	    $current = $_;
	}
	$gd->setThickness(1);
    }

    if ($type eq 'points' or $type eq 'linepoints') {
	my $symbol_name = $self->option('point_symbol') || 'point';
	my $filled      = $symbol_name =~ s/^filled_//;
	my $symbol_ref  = $self->symbols->{$symbol_name};
	my $pr          = $self->point_radius;
	for (@points) {
	    my ($x1,$y1,$x2,$y2,$color,$lw) = @$_;
	    $symbol_ref->($gd,$x1,$y1,$pr,$color,$filled);
	}
    }

    if ($type eq 'histogram') {
	my $current = shift @points;
	for (@points) {
	    my ($x1, $y1, $x2, $y2, $color, $lw)  = @$_;
	    my ($y_start,$y_end) = $y1 < $y_origin ? ($y1,$y_origin) : ($y_origin,$y1);
	    $self->filled_box($gd,$current->[0],$y_start,$x2,$y_end,$color,$color,1);
	    $current = $_;
	}	
    }

    if ($self->option('variance_band') && 
	(my ($mean,$variance) = $self->global_mean_and_variance())) {
	my $y1             = $bottom - ($mean+$variance - $min_score) * $y_scale;
	my $y2             = $bottom - ($mean-$variance - $min_score) * $y_scale;
	my $y              = $bottom - ($mean - $min_score) * $y_scale;
	my $mean_color     = $self->panel->translate_color('yellow:0.80');
	my $variance_color = $self->panel->translate_color('grey:0.25');
	$gd->filledRectangle($left,$y1,$right,$y2,$variance_color);
	$gd->line($left,$y,$right,$y,$mean_color);

	my $fcolor=$self->panel->translate_color('grey:0.50');
	my $font  = $self->font('gdTinyFont');
	my $x1    = $left - length('+1sd') * $font->width;
	my $x2    = $left - length('mn')   * $font->width;
	$gd->string($font,$x1,$y1-$font->height/2,'+1sd',$fcolor);
	$gd->string($font,$x1,$y2-$font->height/2,'-1sd',$fcolor);
	$gd->string($font,$x1,$y2-$font->height/2,'-1sd',$fcolor);
	$gd->string($font,$x2,$y -$font->height/2,'mn',  $variance_color);
    }
}

sub global_mean_and_variance {
    my $self = shift;
    my $wig = $self->wig or return;
    return ($wig->mean,$wig->stdev);
}

sub minmax {
    my $self   = shift;
    my $parts  = shift;

    my $autoscale  = $self->option('autoscale') || '';
    my $min_score  = $self->option('min_score');
    my $max_score  = $self->option('max_score');

    my $do_min     = !defined $min_score;
    my $do_max     = !defined $max_score;

    if ($autoscale eq 'global') {
	if (my $wig = $self->wig) {	
	    $min_score = $wig->min if $do_min;
	    $max_score = $wig->max if $do_max;
	}
    }

    if (($do_min or $do_max) and ($autoscale ne 'global')) {
	my $first = $parts->[0];
	for my $part (@$parts) {
	    my $s = $part->[2];
	    next unless defined $s;
	    $min_score = $s if $do_min && (!defined $min_score or $s < $min_score);
	    $max_score = $s if $do_max && (!defined $max_score or $s > $max_score);
	}
    }

    return ($min_score,$max_score);
}

sub wig {
    my $self = shift;
    my $d = $self->{wig};
    $self->{wig} = shift if @_;
    $d;
}

sub series_mean {
    my $self = shift;
    my $wig = $self->wig or return;
    return eval {$wig->mean} || undef;
}

sub draw_densefile {
    my $self = shift;
    my $feature = shift;
    my $densefile = shift;
    
    my ($denseoffset) = $feature->attributes('denseoffset');
    my ($densesize)   = $feature->attributes('densesize');
    $denseoffset ||= 0;
    $densesize   ||= 1;
    
    my $smoothing      = $self->get_smoothing;
    my $smooth_window  = $self->smooth_window;
    my $start          = $self->smooth_start;
    my $end            = $self->smooth_end;

    my $fh         = IO::File->new($densefile) or die "can't open $densefile: $!";
    eval "require Bio::Graphics::DenseFeature" unless Bio::Graphics::DenseFeature->can('new');
    my $dense = Bio::Graphics::DenseFeature->new(-fh=>$fh,
						 -fh_offset => $denseoffset,
						 -start     => $feature->start,
						 -smooth    => $smoothing,
						 -recsize   => $densesize,
						 -window    => $smooth_window,
	) or die "Can't initialize DenseFeature: $!";
    my $parts = $self->create_parts_for_dense_feature($dense,$start,$end);
    $self->draw_plot($parts);
}

sub create_parts_for_dense_feature {
    my $self = shift;
    my ($dense,$start,$end) = @_;


    my $span = $self->scale> 1 ? $end - $start : $self->width;
    my $data = $dense->values($start,$end,$span);
    my $points_per_span = ($end-$start+1)/$span;
    my @parts;

    for (my $i=0; $i<$span;$i++) {
	my $offset = $i * $points_per_span;
	my $value  = shift @$data;
	next unless defined $value;
	push @parts,[$start + int($i * $points_per_span),
		     $start + int($i * $points_per_span),
		     $value];
    }
    return \@parts;
}

sub subsample {
  my $self = shift;
  my ($data,$start,$span) = @_;
  my $points_per_span = @$data/$span;
  my @parts;
  for (my $i=0; $i<$span;$i++) {
    my $offset = $i * $points_per_span;
    my $value  = $data->[$offset + $points_per_span/2];
    push @parts,Bio::Graphics::Feature->new(-score => $value,
					    -start => int($start + $i * $points_per_span),
					    -end   => int($start + $i * $points_per_span));
  }
  return @parts;
}

sub create_parts_for_segment {
  my $self = shift;
  my ($seg,$start,$end) = @_;
  my $seg_start = $seg->start;
  my $seg_end   = $seg->end;
  my $step      = $seg->step;
  my $span      = $seg->span;

  # clip, because wig files do no clipping
  $seg_start = $start      if $seg_start < $start;
  $seg_end   = $end        if $seg_end   > $end;

  return unless $start < $end;

  # get data values across the area
  my @data = $seg->values($start,$end);

  # create a series of parts
  my @parts;
  for (my $i = $start; $i <= $end ; $i += $step) {
    my $data_point = shift @data;
    push @parts,Bio::Graphics::Feature->new(-score => $data_point,
					   -start => $i,
					   -end   => $i + $step - 1);
  }
  $self->{parts} = [];
  $self->add_feature(@parts);
}

sub rel2abs {
    my $self = shift;
    my $wig  = shift;
    my $path = $self->option('basedir');
    return File::Spec->rel2abs($wig,$path);
}


1;

__END__

=head1 NAME

Bio::Graphics::Glyph::wiggle_xyplot - An xyplot plot compatible with dense "wig"data

=head1 SYNOPSIS

  See <Bio::Graphics::Panel> and <Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph works like the regular xyplot but takes value data in
Bio::Graphics::Wiggle file format:

TODO! UPDATE DOCUMENTATION FOR DENSE FILES

 reference = chr1
 ChipCHIP Feature1 1..10000 wigfile=./test.wig
 ChipCHIP Feature2 10001..20000 wigfile=./test.wig
 ChipCHIP Feature3 25001..35000 wigfile=./test.wig

The "wigfile" attribute gives a relative or absolute pathname to a
Bio::Graphics::Wiggle format file. The data consist of a packed binary
representation of the values in the feature, using a constant step
such as present in tiling array data. Wigfiles are created using the
Bio::Graphics::Wiggle module or the wiggle2gff3.pl script, currently
both part of the gbrowse package.

=head2 OPTIONS

In addition to all the xyplot glyph options, the following options are
recognized:

   Name        Value        Description
   ----        -----        -----------

   basedir     path         Path to be used to resolve "wigfile" and "densefile"
                                tags giving relative paths. Default is to use the
                                current working directory. Absolute wigfile &
                                densefile paths will not be changed.

   autoscale   "local" or "global"
                             If one or more of min_score and max_score options 
                             are absent, then these values will be calculated 
                             automatically. The "autoscale" option controls how
                             the calculation is done. The "local" value will
                             scale values according to the minimum and maximum
                             values present in the window being graphed. "global"   
                             will use chromosome-wide statistics for the entire
                             wiggle or dense file to find min and max values.

   smoothing   method name  Smoothing method: one of "mean", "max", "min" or "none"

   smoothing_window 
               integer      Number of values across which data should be smoothed.

   bicolor_pivot
               name         Where to pivot the two colors when drawing bicolor plots.
                               Options are "mean" and "zero". A numeric value can
                               also be provided.

   pos_color   color        When drawing bicolor plots, the fill color to use for values
                              that are above the pivot point.

   neg_color   color        When drawing bicolor plots, the fill color to use for values
                              that are below the pivot point.

=head2 SPECIAL FEATURE TAGS

The glyph expects one or more of the following tags (attributes) in
feature it renders:

   Name        Value        Description
   ----        -----        -----------

   wigfile     path name    Path to the Bio::Graphics::Wiggle file for vales.
                            (required)

   densefile   path name    Path to a Bio::Graphics::DenseFeature object
                               (deprecated)

   denseoffset integer      Integer offset to where the data begins in the
                               Bio::Graphics::DenseFeature file (deprecated)

   densesize   integer      Integer size of the data in the Bio::Graphics::DenseFeature
                               file (deprecated)

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Glyph>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::cds>,
L<Bio::Graphics::Glyph::crossbox>,
L<Bio::Graphics::Glyph::diamond>,
L<Bio::Graphics::Glyph::dna>,
L<Bio::Graphics::Glyph::dot>,
L<Bio::Graphics::Glyph::ellipse>,
L<Bio::Graphics::Glyph::extending_arrow>,
L<Bio::Graphics::Glyph::generic>,
L<Bio::Graphics::Glyph::graded_segments>,
L<Bio::Graphics::Glyph::heterogeneous_segments>,
L<Bio::Graphics::Glyph::line>,
L<Bio::Graphics::Glyph::pinsertion>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::rndrect>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::ruler_arrow>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,
L<Bio::Graphics::Glyph::transcript2>,
L<Bio::Graphics::Glyph::translation>,
L<Bio::Graphics::Glyph::allele_tower>,
L<Bio::DB::GFF>,
L<Bio::SeqI>,
L<Bio::SeqFeatureI>,
L<Bio::Das>,
L<GD>

=head1 AUTHOR

Lincoln Stein E<lt>steinl@cshl.eduE<gt>.

Copyright (c) 2007 Cold Spring Harbor Laboratory

This package and its accompanying libraries is free software; you can
redistribute it and/or modify it under the terms of the GPL (either
version 1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text. In addition,
please see DISCLAIMER.txt for disclaimers of warranty.

=cut
