package Bio::Graphics::Glyph::vista_plot;

use strict;
use base qw(Bio::Graphics::Glyph::wiggle_xyplot Bio::Graphics::Glyph::heat_map Bio::Graphics::Glyph::smoothing); 

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
        linewidth => [
            'integer',
            3,
            "Line width determine the thickness of the line representing a peak."],
        only_show => [
            'string',
            'both',
            "What to show, peaks or signal (both is the default)."]
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
                 min_score max_score low_rgb low_hsv high_rgb score_range/;

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


# we override the draw method so that it dynamically creates the parts needed
# from the wig file rather than trying to fetch them from the database
sub draw {
 
 my $self = shift;
 my($gd,$dx,$dy) = @_;
 my($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);
 my $feature  = $self->feature;
 my $db;
 my $x = $left;
 my $y = $top + $self->pad_top;
 my $alpha_c = $self->option('alpha') || 0;
 my $only_show = $self->option('only_show') || 'both';
 
 # Draw dual graph if we have both types of attributes, BigWig and wiggle format supported
 my %features = (wig=>$feature->attributes('wigfile'),peak=>$feature->attributes('peak_type'),fasta=>$feature->attributes('fasta'));

 $self->panel->startGroup($gd);

 # Signal Graph drawing:
 if ($features{wig} && $features{wig}=~/\.wi\w[1,2]$/ && ($only_show eq 'signal' || $only_show eq 'both')) {
  $self->draw_wigfile($feature,$features{wig},@_);
 }elsif($features{wig} && $features{wig}=~/\.bw$/i && $features{fasta} && ($only_show eq 'signal' || $only_show eq 'both')) {
   use Bio::DB::BigWig 'binMean';
   use Bio::DB::Sam;
   my $wig = Bio::DB::BigWig->new(-bigwig => "$features{wig}",
                                  -fasta  => Bio::DB::Sam::Fai->open("$features{fasta}"));
  
   my ($summary) = $wig->features(-seq_id => $feature->segment->ref,
                                  -start  => $self->panel->start,
                                  -end    => $self->panel->end,
                                  -type   => 'summary'); 
   my $stats = $summary->statistical_summary($self->width);
   my @vals  = map {$_->{validCount} ? $_->{sumData}/$_->{validCount}:0} @$stats;
   $self->draw_coverage($self,\@vals,@_);
 }

 # Peak drawing:
 if ($features{peak} && ($only_show eq 'peaks' || $only_show eq 'both'))  {
  my $p_type = $features{peak};
  $db = $feature->object_store;
  my @peaks = $db->features(-seq_id => $feature->segment->ref,
                            -start  => $self->panel->start,
                            -end    => $self->panel->end,
                            -type   => $p_type); 
  my $x_scale     = $self->scale;
  my $panel_start = $self->panel->start;
  my $f_start     = $feature->start > $panel_start
                          ? $feature->start
                          : $panel_start;  
  my $lw  = $self->option('linewidth') || 3;
  my($max_s,$min_s) = ($self->option('max_peak'),$self->option('min_peak'));
  ($max_s,$min_s) = (255,1) if (!$max_s || !$min_s);
  my $grad_ok = 0;
  if ($max_s  && $min_s) {
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
             my @rgb = $self->calculate_color($score);
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
            $gd->setThickness(0.5);
   }
  }
}
$self->panel->endGroup($gd);
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

  my $s_range = $s_stop - $s_start;
  my $v_range = $v_stop - $v_start;

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
  $self->score_range($max - $min);
  $self->min_score($min);
  $self->max_score($max);

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



# Need to override this so we have a nice image map for overlayed peaks
sub boxes {
  my $self = shift;
  my($left,$top,$parent) = @_;
  my $feature = $self->feature;
  my @result;
  my($handle) = $feature->attributes('peak_type');
  
  if (!$handle) {
   return wantarray ? () : \();
  }

  my $db      = $feature->object_store;
  
  $parent ||=$self;
  $top  += 0; $left += 0;
  
  if ($handle)  {
   my @peaks = $db->features(-seq_id=>$feature->segment->ref,
                             -start=>$self->panel->start,
                             -end=>$self->panel->end,
                             -type=>$handle);
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

The glyph will draw wiggle file first, than overlay the peaks (if there is any)
over signal graph. Options like 'balloon hover' and 'link' are available to
customize interaction with peaks in detail view

B<BigWig support:>

Supported bigwig format also requires another attribute to be supplied in load gff file (fasta) which specifies sequence index file for the organism
in use. The data file should have the 'bw' extension - it is used to detect the BigWig format by vista_plot

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
 linewidth       = 3
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

B<only_show>
display only peaks, signal or both

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

