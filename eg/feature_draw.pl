#!/usr/bin/perl

use strict;
use lib '..';
use Bio::Graphics::Panel;
use Bio::Graphics::Feature;
use Bio::Graphics::FeatureFile;

unshift @ARGV,'test_data.txt' unless @ARGV;

use constant WIDTH  => 600;  # default width
my @COLORS = qw(cyan blue red yellow green wheat turquoise orange);  # default colors
my $color = 0;      # position in color cycle

my $data = Bio::Graphics::FeatureFile->new(-file => '-');

# general configuration of the image here
my $width         = $data->setting(general => 'pixels') || $data->setting(general => 'width') || WIDTH;
my ($start,$stop) = $data->setting(general => 'bases') =~ /([\d-]+)(?:-|\.\.)([\d-]+)/;

$start = $data->min unless defined $start;
$stop  = $data->max unless defined $stop;

# Use the order of the stylesheet to determine features.  Whatever is left
# over is presented in alphabetic order
my %types = map {$_=>1} $data->configured_types;

my @configured_types   = grep {exists $data->features->{$_}} $data->configured_types;
my @unconfigured_types = sort grep {!exists $types{$_}}      $data->types;

# create the segment,the panel and the arrow with tickmarks
my $segment = Bio::Graphics::Feature->new(-start=>$start,-stop=>$stop);
my $panel = Bio::Graphics::Panel->new(-segment   => $segment,
				      -width     => $width,
				      -key_style => 'between');
$panel->add_track($segment,-glyph=>'arrow',-tick=>2);

my @base_config = $data->style('general');

for my $type (@configured_types,@unconfigured_types) {
  my @config = ( -glyph   => 'segments',         # really generic
		 -bgcolor => $COLORS[$color++ % @COLORS],
		 -label   => 1,
		 -key     => $type,
		 @base_config,             # global
		 $data->style($type),  # feature-specificp
	       );
  my $features = $data->features($type);
  $panel->add_track($features,@config);
}

my $gd = $panel->gd;
print $gd->can('gif') ? $gd->gif : $gd->png;

