#!/usr/bin/perl

use strict;
use Getopt::Long;
use File::Spec;
use IO::Dir;
use Bio::Graphics::Panel;
use Bio::Graphics::Feature;
use File::Temp 'tempfile';

my $MANUAL = 0;
my $LIST   = 0;
my $PICT   = 0;
my $VIEW   = 0;

my $usage = <<USAGE;
Usage: $0 [options] glyph_type 

Give usage information about Bio::Graphics glyphs.

 Options:
    -m --manual   Print the full manual page for the glyph, followed
                     by a summary of its options.
    -l --list     List all glyphs that are available for use.
    -p --picture  Create a PNG picture of what the indicated glyph looks like.
                    The PNG will be written to stdout
    -v --view     Launch a viewer ("xv", "display" or "firefox") to show the
                    glyph.

If neither -m nor -l are specified, the default is to print a summary
of the glyph\'s options.
USAGE

GetOptions ('manual'   => \$MANUAL,
	    'list'     => \$LIST,
	    'picture'  => \$PICT,
	    'view'     => \$VIEW,
	   ) or die $usage;

my $glyph = shift;
$glyph || $LIST or die $usage;

if ($LIST) {
    print_list();
    exit 0;
}

my $class = "Bio::Graphics::Glyph::$glyph";
eval "require $class;1" 
    or die "Unknown glyph $class. Please run $0 -l for a list of valid glyphs.\n";

if ($PICT || $VIEW) {
    print_picture($glyph,$VIEW);
    exit 0;
}

system "perldoc",$class if $MANUAL;
$class->options_man();

exit 0;

sub print_list {
    my %glyphs;
    for my $inc (@INC) {
	my $dir = File::Spec->catfile($inc,'Bio','Graphics','Glyph');
	next unless -d $dir;
	my $d = IO::Dir->new($dir) or die "Couldn't open $dir for reading: $!";
	while (defined(my $entry = $d->read)) {
	    next unless $entry =~ /\.pm$/;
	    my $f  = File::Spec->catfile($dir,$entry);
	    my $io = IO::File->new($f) or next;
	    while (<$io>) {
		chomp;
		next unless /^=head1 NAME/../=head1 (SYNOPSIS|DESCRIPTION)/;
		my ($name,$description) = /^Bio::Graphics::Glyph::(\w+)\s+(.+)/ or next;
		$description =~ s/^[\s-]+//;
		next if $description =~ /base class/;
		$glyphs{$name} = $description;
	    }
	}
    }
    for my $name (sort keys %glyphs) {
	my $description = $glyphs{$name};
	printf "%-20s %s\n",$name,$description;
    }

    exit 0;
}

sub print_picture {
    my $glyph  = shift;
    my $viewit = shift;
    my $ex_image = 
	'http://www.catch-fly.com/sites/awhittington/_files/Image/Drosophila-melanogaster.jpg';
    my $f1   = Bio::Graphics::Feature->new(-start => 1,
					   -end   => 100,
					   -score => 100,
					   -strand=> +1);
    my $f2   = Bio::Graphics::Feature->new(-start => 200,
					   -end   => 300,
					   -score => -50,
					   -strand=> +1);
    my $f3   = Bio::Graphics::Feature->new(-start => 400,
					   -end   => 500,
					   -score => 75,
					   -strand=> +1);
    my $feature = Bio::Graphics::Feature->new(-type=>'test',
					      -name=>"$glyph",
					      -desc=>'test description',
					      -strand=>+1,
					      -start=>1,
					      -end=>500,
					      -attributes=>{
						  image=>$ex_image
					      }
	);

    unless ($glyph eq 'image') { # cheat a little
	$feature->add_SeqFeature($_) foreach ($f1,$f2,$f3);
    }
    my $panel = Bio::Graphics::Panel->new(-length => 500,
					  -width  => 250,
					  -pad_left => 20,
					  -pad_right => 20,
					  -pad_top   => 10,
					  -pad_bottom => 10,
					  -key_style  => 'between',
					  -truecolor  => 1,
	);
    $panel->add_track($feature,
		      -glyph       => $glyph,
		      -label       => 1,
		      -description => 1,
		      -height      => 30,
		      -bgcolor     => 'blue',
		      -autoscale   => 'local',
		      -key         => 'no connector',
	);
    $panel->add_track($feature,
		      -glyph       => $glyph,
		      -label       => 1,
		      -description => 1,
		      -height      => 30,
		      -bgcolor     => 'blue',
		      -connector   => 'solid',
		      -autoscale   => 'local',
		      -key         => 'solid connector',
	);

    $panel->add_track($feature,
		      -glyph       => $glyph,
		      -label       => 1,
		      -description => 1,
		      -height      => 30,
		      -bgcolor     => 'blue',
		      -connector   => 'hat',
		      -autoscale   => 'local',
		      -key         => 'hat connector',
	);


    my $png = $panel->png;
    unless ($viewit) {
	print $png;
	return;
    }
    
    # special stuff for displaying on linux systems
    for my $viewer (qw(xv display)) { # can read from stdin
	`which $viewer` or next;
	my $child = open my $fh,"|-";
	if ($child) {
	    print $fh $png;
	    close $fh;
	    return;
	} else {
	    fork() && exit 0;
	    exec $viewer,'-';
	}
    }

    # if we get here, then launch firefox
    my ($fh,$filename) = tempfile(SUFFIX=>'.png',
				  UNLINK=>1,
	);
    print $fh $png;
    close $fh;
    my $child = fork() && sleep 2 && exit 0;
    exec 'firefox',$filename;
}


1;


