#!/usr/bin/perl -w

use lib '.','..','./blib/lib','../blib/lib';
use strict;

use Bio::Graphics::Panel;
use Bio::Graphics::Feature;

my $ftr = 'Bio::Graphics::Feature';

my $segment = $ftr->new(-start=>1,-end=>1000,-name=>'ZK154',-type=>'clone');
my $zk154_1 = $ftr->new(-start=>-50,-end=>800,-name=>'ZK154.1',-type=>'gene');
my $zk154_2 = $ftr->new(-start=>380,-end=>500,-name=>'ZK154.2',-type=>'gene');
my $zk154_3 = $ftr->new(-start=>900,-end=>1200,-name=>'ZK154.3',-type=>'gene');

my $zed_27 = $ftr->new(-segments=>[[400,500],[550,600],[800,950]],
		   -name=>'zed-27',
		   -subtype=>'exon',-type=>'transcript');
my $abc3 = $ftr->new(-segments=>[[100,200],[350,400],[500,550]],
		    -name=>'abc3',
		   -strand => -1,
		    -subtype=>'exon',-type=>'transcript');
my $xyz4 = $ftr->new(-segments=>[[40,80],[100,120],[200,280],[300,320]],
		     -name=>'xyz4',
		     -subtype=>'predicted',-type=>'alignment');

my $m3 = $ftr->new(-segments=>[[20,40],[30,60],[90,270],[290,300]],
		   -name=>'M3',
		   -subtype=>'predicted',-type=>'alignment');

my $fred_12 = $ftr->new(-segments=>[$xyz4,$zed_27],
			-type => 'group',
			-name =>'fred-12');

my $confirmed_exon1 = $ftr->new(-start=>1,-stop=>20,
				-type=>'exon',
				-source=>'confirmed',
				-name => 'confirmed1',
			       );
my $predicted_exon1 = $ftr->new(-start=>30,-stop=>50,
				-type=>'exon',
				-name=>'predicted1',
				-source=>'predicted');
my $predicted_exon2 = $ftr->new(-start=>60,-stop=>100,
				-name=>'predicted2',
				-type=>'exon',-source=>'predicted');

my $confirmed_exon3 = $ftr->new(-start=>150,-stop=>190,
				-type=>'exon',-source=>'confirmed',
			       -name=>'abc123');
my $partial_gene = $ftr->new(-segments=>[$confirmed_exon1,$predicted_exon1,$predicted_exon2,$confirmed_exon3],
			     -name => 'partial gene',
			     -type => 'transcript',
			     -source => '(from a big annotation pipeline)'
			    );

my $panel = Bio::Graphics::Panel->new(
				      -segment => $segment,
#				      -offset => 300,
#				      -length  => 1000,
				      -spacing => 15,
				      -width   => 600,
				      -pad_top  => 20,
				      -pad_bottom  => 20,
				      -pad_left => 20,
				      -pad_right=> 20,
#				      -bgcolor => 'teal',
#				      -key_style => 'between',
				      -key_style => 'bottom',
				     );
my @colors = $panel->color_names();

$panel->add_track(
		  crossbox => [$abc3,$zed_27],
#		  transcript2 => [$abc3,$zed_27],
		  -label => 1,
		  -bump => 1,
		  -key => 'Prophecies',
#		  -tkcolor => $colors[rand @colors],
		 );
$panel->add_track($segment,
		  -glyph => 'arrow',
		  -label => 'base pairs',
		  -bump => 0,
		  -height => 10,
		  -arrowstyle=>'regular',
		  -linewidth=>1,
#		  -tkcolor => $colors[rand @colors],
		  -tick => 2,
		 );
$panel->unshift_track(generic => [$segment,$zk154_1,$zk154_2,$zk154_3,[$xyz4,$zed_27]],
		      -label     => 1,
		      -bgcolor   => sub { shift->type eq 'predicted' ? 'olive' : 'red'},
		      -connector => sub { my $feature = shift;
					  my $type = $feature->type;
					  $type eq 'group'      ? 'dashed'
					    : $type eq 'transcript' ? 'hat'
					      : $type eq 'alignment'  ? 'solid'
						: undef},
		      -all_callbacks => 1,
		      -connector_color => 'black',
		      -height => 10,
		      -bump => 1,
		      -linewidth=>2,
		      #		  -tkcolor => $colors[rand @colors],
		      -key => 'Signs',
		 );

my $track = $panel->add_track('arrow',
			      -label   => 1,
			      -tkcolor => 'turquoise',
			      -key     => 'Dynamically Added');
$track->add_feature($zed_27,$abc3);
$track->add_group($confirmed_exon1,$predicted_exon1,$predicted_exon2,$confirmed_exon3);

$panel->add_track(
		  [$abc3,$zed_27,$partial_gene],
		  -bgcolor   => sub { shift->source_tag eq 'predicted' ? 'green' : 'blue'},
		  -glyph   => 'transcript',
#		  -glyph   => sub { my $feature = shift; 
#				    return $feature->source_tag eq 'predicted'
#				      ? 'ellipse' : 'transcript'},
		  -label       => sub { shift->sub_SeqFeature > 0 },
#		  -label       => 1,
#		  -description => sub { shift->sub_SeqFeature > 0 },
		  -description => sub {
		    my $feature = shift;
		    return 1   if $feature->type eq 'transcript';
		    return '*' if $feature->source_tag eq 'predicted';
		    return;
		  },
		  -font2color  => 'red',
		  -bump => +1,
#		  -tkcolor => $colors[rand @colors],
		  -key => 'Portents',
		 );
$panel->add_track(generic => [$segment,$zk154_1,[$zk154_2,$xyz4]],
		  -label     => 1,
		  -bgcolor   => sub { shift->type eq 'predicted' ? 'green' : 'blue'},
		  -connector => sub { my $type = shift->type;
				      $type eq 'transcript' ? 'hat'
				    : $type eq 'alignment'  ? 'solid'
				    : undef},
		  -connector_color => 'black',
		  -height => 10,
		  -bump => 1,
#		  -tkcolor => $colors[rand @colors],
		  -key => 'Signals',
		 );

#print $panel->png;

my $gd    = $panel->gd;
my @boxes = $panel->boxes;
my $red   = $panel->translate_color('red');
for my $box (@boxes) {
  my ($feature,@points) = @$box;
#  $gd->rectangle(@points,$red);
}
#$gd->filledRectangle(0,0,20,200,1);
#$gd->filledRectangle(600-20,0,600,200,1);
print $gd->png;

