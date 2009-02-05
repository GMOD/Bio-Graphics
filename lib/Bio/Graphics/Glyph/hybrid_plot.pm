package Bio::Graphics::Glyph::hybrid_plot;

use strict;
use base qw(Bio::Graphics::Glyph::xyplot Bio::Graphics::Glyph::minmax Bio::Graphics::Glyph::smoothing);
use constant DEFAULT_POINT_RADIUS=>4;
use Bio::Root::Version;
our $VERSION = ${Bio::Root::Version::VERSION};

use constant DEBUG=>0;

sub _check_uni {
 return shift->option('u_method') || 'match';
}

# First things first, determine the available methods:
sub lookup_draw_method {
  my $self = shift;
  my $type = shift;

  return '_draw_histogram'            if $type eq 'histogram';
  return '_draw_boxes'                if $type eq 'boxes';
  #return qw(_draw_line _draw_points)  if $type eq 'linepoints';
  return '_draw_line'                 if $type eq 'line';
  #return '_draw_points'               if $type eq 'points';
  return;
}

# Override height and pad functions (needed to correctly space features with different sources):
sub height {
  my $self = shift;
  my $h    = $self->SUPER::height;
  return $self->feature->method eq $self->_check_uni ? 3 : $h;
}

sub pad_top {
  my $self = shift;
  return $self->feature->method eq $self->_check_uni ? 0 : $self->SUPER::pad_top;
}

sub pad_bottom {
  my $self = shift;
  return $self->feature->method eq $self->_check_uni ? 0 : $self->SUPER::pad_bottom;
}

# we override the draw method so that it dynamically creates the parts needed
# from the wig file rather than trying to fetch them from the database
sub draw {

 my $self = shift;
 my ($gd,$dx,$dy) = @_;
 my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);
 my $height = $bottom - $top;
 my $feature     = $self->feature;

 # Zoom test
 my $t_id = $feature->method;
 if($t_id && $t_id eq $self->_check_uni){return Bio::Graphics::Glyph::generic::draw_component($self,@_);}

 my ($wigfileA) = $feature->attributes('wigfileA');
 my ($wigfileB) = $feature->attributes('wigfileB');
 my @wiggles = ($wigfileA,$wigfileB);

 my $type           = $self->option('graph_type') || $self->option('graphtype') || 'boxes';
 my (@draw_methods) = $self->lookup_draw_method($type);
 $self->throw("Invalid graph type '$type'") unless @draw_methods;
 my($scale,$y_origin,$min_score,$max_score);

 $self->panel->startGroup($gd);

 for(my $w = 0; $w < @wiggles; $w++){
  $self->draw_wigfile($feature,$wiggles[$w],@_) if $wiggles[$w];
  my @parts = $self->parts;
  ($min_score,$max_score) = $self->minmax(\@parts);
  $scale  = $max_score > $min_score ? $height/($max_score-$min_score) : 1;
  
  # position of "0" on the scale
  $y_origin = $min_score <= 0 ? $bottom - (0 - $min_score) * $scale : $bottom;
  $y_origin    = $top if $max_score < 0;

  my $clip_ok = $self->option('clip');
  my $alpha_c = $self->option('alpha') || 0;
   
  $self->{_clip_ok}   = $clip_ok;
  $self->{_scale}     = $scale;
  $self->{_min_score} = $min_score;
  $self->{_max_score} = $max_score;
  $self->{_top}       = $top;
  $self->{_bottom}    = $bottom;
  $self->{_alpha}     = $alpha_c;

  foreach (@parts) {
   my $s = $_->score;
   $_->{_y_position}   = $self->score2position($s);
   warn "y_position = $_->{_y_position}" if DEBUG;
  }

  $self->panel->startGroup($gd);
  $self->_draw_scale($gd,$scale,$min_score,$max_score,$dx,$dy,$y_origin);
  $self->panel->endGroup($gd);
  
  for my $draw_method (@draw_methods) {
   $self->$draw_method($gd,$dx,$dy,$y_origin,$w);
  }
 }

 $self->draw_label(@_)       if $self->option('label');
 $self->draw_description(@_) if $self->option('description');
 $self->panel->endGroup($gd);
}


# draw wigfile
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
  
  $wig->smoothing($self->get_smoothing);
  $wig->window($self->smooth_window);

  my $panel_start = $self->panel->start;
  my $panel_end   = $self->panel->end;
  my $start       = $feature->start > $panel_start ? $feature->start : $panel_start;
  my $end         = $feature->end   < $panel_end   ? $feature->end   : $panel_end;

  $self->wig($wig);
  $self->create_parts_for_feature($wig,$start,$end);
}

sub wig {
  my $self = shift;
  my $d = $self->{wig};
  $self->{wig} = shift if @_;
  $d;
}

sub create_parts_for_feature {
  my $self = shift;
  my ($dense,$start,$end) = @_;

  my $span = $self->scale> 1 ? $end - $start : $self->width;
  my $data = $dense->values($start,$end,$span);
  my $points_per_span = ($end-$start+1)/$span;
  my @parts;

  for (my $i=0; $i<$span;$i++) {
     my $offset = int($i * $points_per_span);
     my $value  = shift @$data;
     next unless defined $value;
     push @parts,
     Bio::Graphics::Feature->new(-score => $value,
    				 -start => $start + $offset,
				 -end   => $start + $offset);
				 }
    $self->{parts} = [];
    $self->add_feature(@parts);
}

# Adding alpha channel to a color:
sub add_alpha {
 my($self,$im,$color,$alpha) = @_;
 my($r,$g,$b) = $im->rgb($color);
 return $im->colorAllocateAlpha($r,$g,$b,$alpha);
}

# OVERRIDEN:
sub score2position {
  my($self,$score) = @_;

  return undef unless defined $score;
  if ($self->{_clip_ok} && $score < $self->{_min_score}) {
   $score = $self->{_min_score}
  }

  elsif ($self->{_clip_ok} && $score > $self->{_max_score}) {
    $score = $self->{_max_score};
  }

    warn "score = $score, _top = $self->{_top}, _bottom = $self->{_bottom}, max = $self->{_max_score}, min=$self->{_min_score}" if DEBUG;
    my $position      = $score * $self->{_scale};
    warn "position = $position" if DEBUG;
    return $position;
}

#Here we override some drawing methods for xyplot so we can have 'dual graph'
# boxes:
sub _draw_boxes {
  my ($self,$gd,$left,$top,$bottom,$mode) = @_;
  my @parts    = $self->parts;
  return $self->SUPER::_draw_boxes(@_) unless @parts > 0;
  my ($px1,$py1,$px2,$py2) = $self->bounds($left,$top);
  my $height   = $self->height;

  my $lw = $self->linewidth;
  my $positive = $self->pos_color || $self->fgcolor;
  my $negative = $self->neg_color || $self->bgcolor;
  
  # Set up alpha channel here
  my $_alpha = $self->{_alpha};
  $_alpha = $_alpha <=127 ? $_alpha : 0; # Reset to zero if illegal value is passed

  if($_alpha > 0){
   $gd->alphaBlending(1);
   $positive = $self->add_alpha($gd,$positive,$_alpha);
   $negative = $self->add_alpha($gd,$negative,$_alpha);
  }

  # draw each of the boxes as a rectangle
  foreach my $part(@parts) {
    next unless $part->{_y_position};
    my ($x1,$y1,$x2,$y2) = $part->calculate_boundaries($px1,$py1-$self->pad_top);


    $x2 = $x1+1 if $x2-$x1 < 1;
    $mode == 0 ? $self->filled_box($gd,$x1,$y2-$part->{_y_position},$x2,$y2,$positive,$positive,$lw) : $self->filled_box($gd,$x1,$y2-$part->{_y_position},$x2,$y2,$negative,$negative,$lw);
   }

}

# lines:
sub _draw_line {
 my $self = shift;
 my ($gd,$left,$top,$bottom,$mode) = @_;
 my ($px1,$py1,$px2,$py2) = $self->bounds($left,$top);

 my @parts  = $self->parts;
 return $self->SUPER::_draw_boxes(@_) unless @parts > 0;
 my $positive = $self->pos_color || $self->fgcolor;
 my $negative = $self->neg_color || $self->bgcolor;

 # connect to center positions of each interval
 my $first_part = shift @parts;
 my ($x1,$y1,$x2,$y2) = $first_part->calculate_boundaries($px1,$py1-$self->pad_top);
 my $current_x = ($x1+$x2)/2;
 my $current_y = $first_part->{_y_position};

 for my $part (@parts) {
  ($x1,$y1,$x2,$y2) = $part->calculate_boundaries($px1,$py1-$self->pad_top);
   my $next_x = ($x1+$x2)/2;
   my $next_y = $part->{_y_position};
   if(defined $current_y and defined $next_y){
    $mode == 0 ? $gd->line($current_x,$y2-$current_y,$next_x,$y2-$next_y,$positive) : $gd->line($current_x,$y2-$current_y,$next_x,$y2-$next_y,$negative);
   }
  ($current_x,$current_y) = ($next_x,$next_y);
 }

}

# histogram
sub _draw_histogram {
  my $self = shift;
  my ($gd,$left,$top,$bottom,$mode) = @_;
  my ($px1,$py1,$px2,$py2) = $self->bounds($left,$top);

  my @parts  = $self->parts;
  return $self->SUPER::_draw_boxes(@_) unless @parts > 0;
  my $positive = $self->pos_color || $self->fgcolor;
  my $negative = $self->neg_color || $self->bgcolor;

  # draw each of the component lines of the histogram surface
  for (my $i = 0; $i < @parts; $i++) {
   my $part = $parts[$i];
   my $next = $parts[$i+1];
   next unless $part->{_y_position};
   my ($x1,$y1,$x2,$y2) = $part->calculate_boundaries($px1,$py1-$self->pad_top);
   
   $mode == 0 ? $gd->line($x1,$y2-$part->{_y_position},$x2,$y2-$part->{_y_position},$positive) : $gd->line($x1,$y2-$part->{_y_position},$x2,$y2-$part->{_y_position},$negative);
   next unless $next->{_y_position};
   my ($x3,$y3,$x4,$y4) = $next->calculate_boundaries($px1,$py1-$self->pad_top);
   if ($x2 == $x3) {# connect vertically to next level
      $mode == 0 ? $gd->line($x2,$y2-$part->{_y_position},$x2,$y2-$next->{_y_position},$positive) :  $gd->line($x2,$y2-$part->{_y_position},$x2,$y2-$next->{_y_position},$negative);
    } else {
      if($mode == 0){
       $gd->line($x2,$y2-$part->{_y_position},$x2,$y2,$positive); # to bottom
       $gd->line($x2,$y2,$x3,$y2,$positive);              # to right
       $gd->line($x3,$y2,$x3,$y2-$next->{_y_position},$positive); # up
      }else{
       $gd->line($x2,$y2-$part->{_y_position},$x2,$y2,$negative); # to bottom
       $gd->line($x2,$y2,$x3,$y2,$negative);              # to right
       $gd->line($x3,$y2,$x3,$y2-$next->{_y_position},$negative); # up
       }
    }
   }

 # end points: from bottom to first
 my ($x1,$y1,$x2,$y2) = $parts[0]->calculate_boundaries($px1,$py1-$self->pad_top);
 my $first_y    = $parts[0]->{_y_position};
 $mode == 0 ? $gd->line($x1,$y2,$x1,$y2-$first_y,$positive) : $gd->line($x1,$y2,$x1,$y2-$first_y,$negative);
 # from last to bottom
 my ($x3,$y3,$x4,$y4) = $parts[-1]->calculate_boundaries($px1,$py1-$self->pad_top);
 my $last_y     = $parts[-1]->{_y_position};
 $mode == 0 ? $gd->line($x4,$y2-$last_y,$x4,$y2,$positive) : $gd->line($x4,$y2-$last_y,$x4,$y2,$negative);

}

1;

__END__

=head1 NAME


Bio::Graphics::Glyph::hybrid_plot - An xyplot plot drawing dual graph using data from two wiggle files per track

=head1 SYNOPSIS


See <Bio::Graphics::Panel> <Bio::Graphics::Glyph> and <Bio::Graphics::Glyph::xyplot>.

=head1 DESCRIPTION


Note that for full functionality this glyph requires Bio::Graphics::Glyph::box (box glyph is used for drawing individual
matches for small RNA alignments at a high zoom level, specified by semantic zooming in GBrowse conf file)
Unlike the regular xyplot, this glyph draws two overlapping graphs
using value data in Bio::Graphics::Wiggle file format:

track type=wiggle_0 name="Experiment" description="snRNA seq data" visibility=pack viewLimits=-2:2 color=255,0,0 altColor=0,0,255 windowingFunction=mean smoothingWindow=16
 
 2L 400 500 0.5
 2L 501 600 0.5
 2L 601 700 0.4
 2L 701 800 0.1
 2L 800 900 0.1
  
##gff-version 3

2L      Sample_rnaseq  rnaseq_wiggle 41   3009 . . . ID=Samlpe_2L;Name=Sample;Note=YourNoteHere;wigfileA=/datadir/track_001.2L.wig;wigfileB=/datadir/track_002.2L.wig
  

The "wigfileA" and "wigfileB" attributes give a relative or absolute pathname to 
Bio::Graphics::Wiggle format files for two concurrent sets of data. Basically,
these wigfiles contain the data on signal intensity (counts) for sequences 
aligned with genomic regions. In wigfileA these data are additive, so for each
sequence region the signal is calculated as a sum of signals from overlapping
matches. In wigfileB the signal represents the maximum value among all sequences
aligned with the current region so the user can see the difference between
accumulated signal from overlapping multiple matches (which may likely be
just noise from products of degradation) and signal from unique sequences.  
It is essential that wigfile entries in gff file do not have score, because
score used to differentiate between data for dual graph and data for matches
(individual features visible at higher magnification)

=head2 OPTIONS

In addition to some of the xyplot glyph options, the following options are
recognized:

 Name        Value        Description
 ----        -----        -----------

 wigfileA    path name    Path to a Bio::Graphics::Wiggle file for accumulated vales in 10-base bins

 wigfileB    path name    Path to a Bio::Graphics::Wiggle file for max values in 10-base bins

 pos_color   color        When drawing bicolor plots, the fill color to use for max values
																									      neg_color   color        When drawing bicolor plots, the fill color to use for total (accumulated) values
	
 alpha       number       For blending colors ofthe overlapping graphs (between 1 and 127) truecolor must be enabled

 u_method    method name  Use method of [method name] to identify individual features (like alignment matches) 
                          to show at high zoom level. By default it is set to 'match'

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

Peter Ruzanov E<lt>pruzanov@oicr.on.caE<gt>.

Copyright (c) 2008 Ontario Institute for Cancer Research

This package and its accompanying libraries is free software; you can
redistribute it and/or modify it under the terms of the GPL (either
version 1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text. In addition,
please see DISCLAIMER.txt for disclaimers of warranty.

=cut
