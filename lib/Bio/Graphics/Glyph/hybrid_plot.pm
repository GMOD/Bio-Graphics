package Bio::Graphics::Glyph::hybrid_plot;

use strict;
use base qw(Bio::Graphics::Glyph::wiggle_xyplot Bio::Graphics::Glyph::smoothing);
use constant DEBUG=>0;
use constant NEGCOL=>"orange";
use constant POSCOL=>"blue";


#Checking the method for individual features (RNA-Seq reads)
sub _check_uni {
 return shift->option('u_method') || 'match';
}


# Override height and pad functions (needed to correctly space features with different sources):
sub height {
  my $self = shift;
  my $h    = $self->SUPER::height;
  return $self->feature->method eq $self->_check_uni ? 3 : $h;
}

sub pad_top {
  my $self = shift;
  return $self->feature->method eq $self->_check_uni ? 0 : 4;
}

sub pad_bottom {
  my $self = shift;
  return $self->feature->method eq $self->_check_uni ? 0 : 4;
}

# we override the draw method so that it dynamically creates the parts needed
# from the wig file rather than trying to fetch them from the database
sub draw {
 
 my $self = shift;
 my ($gd,$dx,$dy) = @_;
 my ($left,$top,$right,$bottom) = $self->calculate_boundaries($dx,$dy);
 my $height   = $bottom - $top;
 my $feature  = $self->feature;
 
 
 #Draw individual features for reads (they unlike wiggle features will have scores)
 my $t_id = $feature->method;
 if($t_id && $t_id eq $self->_check_uni){return Bio::Graphics::Glyph::generic::draw_component($self,@_);}

 #Draw dual graph if we don't have a score
 my @wiggles = ($feature->attributes('wigfileA'),$feature->attributes('wigfileB'));
 my($scale,$y_origin,$min_score,$max_score);

 $self->panel->startGroup($gd);

 for(my $w = 0; $w < @wiggles; $w++){
  if($w > 0){$self->configure(-pos_color, NEGCOL);}
  else{$self->configure(-pos_color, POSCOL);}
  
  $self->draw_wigfile($feature,$wiggles[$w],@_) if $wiggles[$w];
  my @parts = $self->parts;
  ($min_score,$max_score) = $self->minmax(\@parts);
  $scale  = $max_score > $min_score ? $height/($max_score-$min_score) : 1;
  
  # position of "0" on the scale (We need to draw the scale again due to some glithes with color)
  $y_origin = $min_score <= 0 ? $bottom - (0 - $min_score) * $scale : $bottom;
  $y_origin    = $top if $max_score < 0;

  $self->panel->startGroup($gd);
  $self->_draw_scale($gd,$scale,$min_score,$max_score,$dx,$dy,$y_origin);
  $self->panel->endGroup($gd);
 }
}

1;

__END__

=head1 NAME


Bio::Graphics::Glyph::hybrid_plot - An xyplot plot drawing dual graph using data from two wiggle files per track

=head1 SYNOPSIS


See <Bio::Graphics::Panel> <Bio::Graphics::Glyph> and <Bio::Graphics::Glyph::wiggle_xyplot>.

=head1 DESCRIPTION


Note that for full functionality this glyph requires Bio::Graphics::Glyph::generic (generic glyph is used for drawing individual
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
matches (signal). In wigfileB the signal represents the maximum value among all 
sequences (signal quality) aligned with the current region so the user can see
the difference between accumulated signal from overlapping multiple matches 
(which may likely be just a noise from products of degradation) and high-quality 
signal from unique sequences.
 
It is essential that wigfile entries in gff file do not have score, because
score used to differentiate between data for dual graph and data for matches
(individual features visible at higher magnification). After an update to
wiggle_xyplot code colors for dual plot are now hard-coded (blue for signal and
orange for signal quality). Alpha channel is also handled by wiggle_xyplot code now.

=head2 OPTIONS

In addition to some of the wiggle_xyplot glyph options, the following options are
recognized:

 Name        Value        Description
 ----        -----        -----------

 wigfileA    path name    Path to a Bio::Graphics::Wiggle file for accumulated vales in 10-base bins

 wigfileB    path name    Path to a Bio::Graphics::Wiggle file for max values in 10-base bins

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
