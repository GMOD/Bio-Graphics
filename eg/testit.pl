#!/usr/bin/perl -w

use lib '.','./blib/lib','../blib/lib';
use strict;

use Bio::Graphics::Panel;
use Bio::Graphics::Feature;

my $ftr = 'Bio::Graphics::Feature';

my $segment = $ftr->new(-start=>1,-end=>1000,-name=>'ZK154',-type=>'clone');
my $zk154_1 = $ftr->new(-start=>300,-end=>800,-name=>'ZK154.1',-type=>'gene');
my $zk154_2 = $ftr->new(-start=>380,-end=>500,-name=>'ZK154.2',-type=>'gene');

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

my $predicted_exon1 = $ftr->new(-start=>32,-stop=>42,
				-type=>'exon',-source=>'predicted');
my $predicted_exon2 = $ftr->new(-start=>55,-stop=>85,
				-type=>'exon',-source=>'predicted');

my $confirmed_exon3 = $ftr->new(-start=>150,-stop=>190,
				-type=>'exon',-source=>'confirmed');
my $partial_gene = $ftr->new(-segments=>[$predicted_exon1,$predicted_exon2,$confirmed_exon3],
			     -name => 'partial_gene');

my $panel = Bio::Graphics::Panel->new(-segment => $segment,
				      -width   => 600);
$panel->add_track(
		  transcript2 => [$abc3,$zed_27],
		  -label => 1,
		  -bump => 1,
		 );
$panel->add_track(
		  arrow => $segment,
		  -label => 1,
		  -bump => 0,
		  -tick => 2,
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
		  -bump => 1);
$panel->add_track(generic => [$segment,$zk154_1,$zk154_2,[$xyz4,$zed_27]],
		  -label     => 1,
		  -bgcolor   => sub { shift->type eq 'predicted' ? 'green' : 'blue'},
		  -connector => sub { my $type = shift->type;
				      $type eq 'transcript' ? 'hat'
				    : $type eq 'alignment'  ? 'solid'
				    : undef},
		  -connector_color => 'black',
		  -height => 10,
		  -bump => 1);
$panel->add_track(
		  [$abc3,$zed_27,$partial_gene],
		  -bgcolor   => sub { shift->source_tag eq 'predicted' ? 'green' : 'blue'},
		  -map   => sub { my $feature = shift; 
				  return $feature->source_tag eq 'predicted' 
				    ? 'oval' : 'transcript'},
		  -label => 1,
		  -bump => -1,
		 );
#print $panel->png;

my $gd    = $panel->gd;
my @boxes = $panel->boxes;
my $red   = $panel->translate_color('red');
for my $box (@boxes) {
  my ($feature,@points) = @$box;
#  $gd->rectangle(@points,$red);
}
print $gd->png;

