#!perl
use Config;
use File::Basename qw(&basename &dirname);
use Cwd;

$origdir = cwd;
chdir dirname($0);
$file = basename($0, '.PL','.PLS');

open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{startperl} -w
!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';

# Bio::DB::GFF/Bio::Graphics-based annotation browser
# $Id: gbrowse.PLS,v 1.3 2001-11-18 15:10:39 lstein Exp $

use lib '/home/lstein/projects/Bio-Graphics/blib/lib';
use strict;
use Bio::DB::GFF;
use Bio::Graphics;
use Bio::Graphics::Browser;
use Digest::MD5 'md5_hex';
use File::Path 'mkpath';
use Carp;
use CGI qw(:standard 'center');
use vars qw($CONFIG %DB $MAX_SEGMENT $DEFAULT_SEGMENT);

# if you change the zoom/nav icons, you must change this as well.
use constant MAG_ICON_HEIGHT => 20;
use constant MAG_ICON_WIDTH  => 8;
use constant MAX_SEGMENT     => 1_000_000;
use constant DEFAULT_SEGMENT => 100_000;
use constant OVERVIEW_RATIO  => 0.8;

###################################################################
# Non-modperl users should change this constant if needed
#
my $CONF_DIR = '/usr/local/apache/conf/gbrowse.conf';
#
###################################################################


BEGIN {
  if ($ENV{MOD_PERL}) {
# causes iterator breakage
# eval "use Apache::DBI";
    eval "use Apache";
    my $conf = Apache->request->dir_config('DasConfigFile');
    $CONF_DIR ||= Apache->server_root_relative($conf) if $conf;
    warn <<END if Apache::DBI->can('connect_on_init');
WARNING: APACHE::DBI DETECTED.
THIS WILL CAUSE THE GFF DUMP TO FAIL INTERMITTENTLY.
THIS SCRIPT DOES NOT BENEFIT FROM APACHE::DBI
END
;
  }
}


# preliminaries -- set up some globals
$CONFIG         = Bio::Graphics::Browser->new($CONF_DIR)
  or die "Couldn't open configuration directory: $!";

$MAX_SEGMENT     = $CONFIG->setting('max segment')     || MAX_SEGMENT;
$DEFAULT_SEGMENT = $CONFIG->setting('default segment') || DEFAULT_SEGMENT;

## PAGE SETTINGS ##############################################################################
#
# Recover a hashref which contains page-specific settings
# (this involves reading a cookie or possibly a database record in some future implementation
my $page_settings = get_settings();

# Now adjust those settings based on submitted CGI parameters
adjust_settings($page_settings);
###############################################################################################

## GETTING THE SEGMENT ########################################################################
my $segment      = get_segment($page_settings);
###############################################################################################

## DUMPS ######################################################################################
if ( (my $dump = param('dump')) && $segment) {
  if ($dump eq 'FastA') {
    print header(-attachment   => "$segment.fa",
		 -type         => 'text/plain');
    dump_fasta($segment,$page_settings);
  }

  elsif($dump eq 'GFF') {
    print header(-attachment   => "$segment.gff",
		 -type         => 'text/plain');
    dump_gff($segment,$page_settings);
  }
  exit 0;
}
###############################################################################################


## PRINTING THE PAGE ##########################################################################
print header(-cookie => settings2cookie($page_settings));

my $description = $CONFIG->setting('description');
print
  start_html(-title => 'Genome browser',
	    -style  => {src=>$CONFIG->setting('stylesheet')},
	    ),
  h1($description);

print h2("Showing",commas($segment->length),"bp from",
	 $segment->ref.", positions ".commas($segment->start)." to ".commas($segment->stop))
  if $segment;

print h2({-class=>'error'},"The landmark named",i(param('name')),"is not recognized.",
	 "You may need to qualify it with the type, as in",i("PCR_Product:".param('name')))
  if $page_settings->{name} && !$segment;

print start_form(-action=>url(-relative=>1));

print navigation_table($segment,$page_settings);

if ($segment) {
  print overview($segment,$page_settings);

  if ($segment->length <= $MAX_SEGMENT) {
    print image_and_map($segment,$page_settings);
  } else {
    print p(i(
	      "Detailed view is limited to",
	      commas($MAX_SEGMENT),"bases.",
	      "Click in the overview to select a region",commas($DEFAULT_SEGMENT),'bp wide.'));
  }
}

print settings_table($page_settings);

print end_form(), $CONFIG->setting('footer'),end_html;

###############################################################################################

# read from cookie, if there is one
# if not, set  from defaults
sub get_settings {
  my %settings = cookie('gbrowse');

  # slight violation of the logic here, but the current configuration
  # source must be modified before anything else happens.
  $settings{source} = param('source') if param('source');
  $CONFIG->source($settings{source}) if defined $settings{source};

  my $ok = 1;
  if (%settings) {  # if cookie is there, then validate it
    $ok &&= defined $settings{width} && $settings{width} > 100 && $settings{width} < 5000;
    my %ok_sources = map {$_=>1} $CONFIG->sources;
    $ok &&= $ok_sources{$settings{source}};
    my %ok_labels       = map {$_=>1} $CONFIG->labels;
    my @selected_labels = split $;,$settings{labels} if defined $settings{labels};
    foreach (@selected_labels) {
      $ok &&= $ok_labels{$_};
    }
    $settings{labels} = \@selected_labels if $ok;
  }

  if (!$ok || !%settings) {
    %settings = ();
    @settings{'name','ref','start','stop'} = ('','','','');
    $settings{source} = $CONFIG->source;
    $settings{width}  = $CONFIG->setting('default width');
    $settings{labels} = [$CONFIG->default_labels];
  }

  \%settings;
}

sub settings2cookie {
  my $settings = shift;
  my %settings = %$settings;
  for my $key (keys %settings) {
    if (ref($settings{$key}) eq 'ARRAY') {
      $settings{$key} = join $;,@{$settings{$key}};
    }
  }
  my $cookie = cookie(-name    => 'gbrowse',
		      -value   => \%settings,
		      -expires => '+3M');
  return $cookie;
}

sub adjust_settings {
  my $settings = shift;
  $settings->{source} = param('source') if param('source');
  if (my @selected = param('label')) {
    $settings->{labels} = \@selected;
  }
  $settings->{width} = param('width')   if param('width');
  $settings->{source} = param('source') if param('source');

  if (param('ref') && grep {/zoom|nav|overview/} param() ) {
    $settings->{ref}   = param('ref');
    $settings->{start} = param('start') if param('start') =~ /^[\d-]+/;
    $settings->{stop}  = param('stop')  if param('stop')  =~ /^[\d-]+/;
    zoomnav($settings);
    $settings->{name} = "$settings->{ref}:$settings->{start}..$settings->{stop}";
    param(name=>$settings->{name});
  }

  if ( param('name')) {
    $settings->{name}  = param('name');
  }

}

# prints the zooming and navigation bar
sub navigation_table {
  my $segment = shift;
  my $settings = shift;
  my $buttonsDir    = $CONFIG->setting('buttons');
  my $table = '';

  $table .= table({-border=>0, -width=>$settings->{width}},
		  TR({-class=>'searchbody'},
		     td({-align=>'left', -colspan=>2},
			'Search using a sequence name, gene name, locus, or other landmark.',
			'Examples:',i('IV,'),i('CHROMOSOME_IV,'),i('I:120000..130000,'),i('unc-9,'),i('clone:B0019,'),
			i('PCR_Product:sjj_B0019.1'))
		    ),
		  TR({-class=>'searchbody'},
		     td({-align=>'left', -colspan=>2},
		     'To center on a location, click the ruler.  User the Scroll/Zoom buttons to',
		     'change magnification and position.')
		    ),
		  TR({-class=>'searchtitle', -align=>'left'},
		     td({-class=>'searchtitle',-colspan=>$segment ? 1 : 2}, b('Landmark or Region'),
			textfield(-name=>'name',-size=>28),
			submit(-name=>'Go')),
		     td({-align=>'LEFT'},
			$segment ? ('Scroll/Zoom: ',slidertable($segment,$buttonsDir)) : ''
		       ),
		    ));
}

sub slidertable {
  my ($segment,$buttonsDir) = @_;

  my @lines;
  push @lines,hidden(-name=>'start',-value=>$segment->start,-override=>1);
  push @lines,hidden(-name=>'stop',-value=>$segment->end,-override=>1);
  push @lines,hidden(-name=>'ref',-value=>$segment->ref,-override=>1);
  push @lines, (image_button(-src=>"$buttonsDir/green_l2.gif",-name=>'nav0',-border=>'0',-title=>"b1"),
		image_button(-src=>"$buttonsDir/green_l1.gif",-name=>'nav1',-border=>'0',-title=>"b2"),
		zoomBar($segment,$buttonsDir),
		image_button(-src=>"$buttonsDir/green_r1.gif",-name=>'nav2',-border=>'0',-title=>"b3"),
		image_button(-src=>"$buttonsDir/green_r2.gif",-name=>'nav3',-border=>'0',-title=>"b4"),
	       );

  #  print end_form;
  my $str	= join('', @lines);
  return $str;
}

sub zoomBar {
  my ($segment,$buttonsDir) = @_;

  my @letters;
  my @ranges	= get_ranges();
  my $span = $segment->length;
  my $pixels_per_range = MAG_ICON_HEIGHT/@ranges;

  for(my $i=0; $i < @ranges; $i++){
    my $altText	   = qq{show $ranges[$i] bp};
    my $titleText  = qq{show $ranges[$i] bp};
    my $color;
    if($i>0){
      $color = ($ranges[$i-1] < $span) && ($ranges[$i] >= $span) ? 'red' : 'green';
    }else{
      $color = ($ranges[$i] >= $span) ? 'red' : 'green';
    }
    my $c = $i+1;
    $letters[$i] = image_button(-src    => "$buttonsDir/$color$c.gif",
				-name   => "zoom${i}",
				-alt    => $altText,
				-border => 0,
#				-height => ($i+1)*$pixels_per_range,
#				-width  => MAG_ICON_WIDTH,
				-title  => $titleText);
  }

  return join(' ', @letters);
}


sub settings_table {
  my $settings = shift;

  my @widths = split /\s+/,$CONFIG->setting('image widths');
  @widths = (640,800,1024) unless @widths;

  # set up the dumps line.
  my($ref,$start,$stop,$source) = @{$settings}{qw(ref start stop source)};
  my $self     = url(-relative=>1);
  my @dumps    = ( ['FastA',"$self?dump=FastA;start=$start;stop=$stop;ref=$ref;source=$source"],
		   ['GFF'  ,"$self?dump=GFF;start=$start;stop=$stop;ref=$ref;source=$source"]);

  my $ds        = join(', ', (map{a({-href=>"@$_->[1]"},"@$_->[0]")} @dumps));

  my @labels = $CONFIG->labels;
  my $selected_labels = $settings->{labels};

  my $sTable 	= '';
  $sTable.= table({-border=>0,-width=>$settings->{width}},
		  TR(
		     th({-class=>'searchtitle', -colspan=>3, -align=>'left'},'Genome Browser Search Settings:')),
		  TR( td({-class=>'searchbody'},'Dump view as: '),
		      td({-class=>'searchbody',-colspan=>2}, $ds)),
		  TR(	td({-class=>'searchbody', -valign=>'top'}, 'Show features: '),
			td({-class=>'searchbody',-colspan=>2},
			   checkbox_group(-name=>'label',
					  -values   => \@labels,
					  -defaults => $selected_labels,
					  -cols     => 3,
					  -override => 1,
					 ))),
		  $CONFIG->sources > 1 ?
		  (TR({-class=>'searchbody'},
		      td('Data Source:'),
		      td({-colspan=>2},
			 popup_menu(-name   => 'source',
				    -values => [$CONFIG->sources],
				    -labels => { map {$_ => $CONFIG->description($_)} $CONFIG->sources},
				    -default => $CONFIG->source
				   )))
		   ) : '',
		  TR( td({-class=>'searchbody'},'Image Width: '),
		      td(
			 radio_group( -name=>'width',
				      -values=>\@widths,
				      -default=>$settings->{width},
				      -override=>1
				    )
			),
		      td({-class=>'searchbody',-align=>'left'},
			 hidden('ref'),hidden('start'),hidden('stop'),
			 submit(-name=>'Change Settings')))
		 );
  return $sTable;
}

# computes the new values for start and stop when the user made use of the zooming bar or navigation bar
sub zoomnav {
  my $settings = shift;
  return unless $settings->{ref};
  my $start = $settings->{start};
  my $stop  = $settings->{stop};

  # get zoom parameters
  my ($zoom) = grep {/^zoom\d+/} param();
  my ($nav)  = grep {/^nav\d+/}  param();
  my $overview_x     = param('overview.x');
  my $segment_length = param('seg_length');

  my $zoomlevel = $1 if $zoom && $zoom =~ /(\d+)/;
  my $navlevel  = $1 if $nav && $nav  =~ /(\d+)/;
  my ($center, $ohalf, $nhalf, $span);

  my @ranges	= get_ranges();
  $span	        = $stop - $start + 1;

  if (defined $zoomlevel) {
    $center	    = int($span / 2) + $start;
    my $range	    = int(($ranges[$zoomlevel])/2);
    ($start, $stop) = ($center - $range , $center + $range -1);
  }

  elsif (defined $navlevel){
    if($navlevel == 0){ $start -= int($span / 2); $stop -= int($span / 2)}
    if($navlevel == 1){ $start -= int($span / 4); $stop -= int($span / 4)}
    if($navlevel == 2){ $start += int($span / 4); $stop += int($span / 4)}
    if($navlevel == 3){ $start += int($span / 2); $stop += int($span / 2)}
  }

  elsif (defined $overview_x && defined $segment_length) {
    my $overview_width = $settings->{width} * OVERVIEW_RATIO;
    my $click_position = $segment_length * $overview_x/$overview_width;
    $span = $DEFAULT_SEGMENT if $span > $MAX_SEGMENT;
    $start = int($click_position - $span/2);
    $stop  = $start + $span - 1;
  }

  $start = 1 if $start < 1;
  $settings->{start} = $start;
  $settings->{stop}  = $stop;
}


# interesting heuristic way of fetching sequence segments based on educated guesses
sub get_segment {
  my $settings = shift;

  my $db = open_database();
  $db->debug(0);
  my $segment;

  if (my $name = $settings->{name}) {
    my ($class,$start,$stop);
    if ($name =~ /(\w+):([\d]+)(?:-|\.\.|,)?([\d]+)/) {
      $name = $1;
      $start = $2;
      $stop = $3;
    }

    elsif ($name =~ /^(\w+):(.+)$/) {
      $class = $1;
      $name  = $2;
    }

    my @argv = (-name  => $name);
    push @argv,(-class => $class) if defined $class;
    push @argv,(-start => $start) if defined $start;
    push @argv,(-stop  => $stop)  if defined $stop;
    $segment = $db->segment(@argv);

    # Here's the heuristic part.  Try various abbreviations that
    # people tend to use for chromosomal addressing.
    if (!$segment && $name =~ /^([\dIVXA-F]+)$/) {
      my $id = $1;
      foreach (qw(CHROMOSOME_ Chr chr)) {
	my $n = "${_}${id}";
	my @argv = (-name  => $n);
	push @argv,(-class => $class) if defined $class;
	push @argv,(-start => $start) if defined $start;
	push @argv,(-stop  => $stop)  if defined $stop;
	$segment ||= $db->segment(@argv);
      }
    }
    # try things that look like genes
    if (!$segment && $name =~ /[a-zA-Z]-?\d+/) {
      $segment = $db->segment(Locus => $name);
    }

    # try to remove the chr CHROMOSOME_I
    if (!$segment && $name =~ /^(chromosome_?|chr)/i) {
      (my $chr = $name) =~ s/^(chromosome_?|chr)//i;
      warn "chr = $chr";
      $segment = $db->segment($chr);
    }

  }

  elsif (my $ref = $settings->{ref}) {
    my @argv = (-name  => $ref);
    push @argv,(-start => $settings->{start}) if defined $settings->{start};
    push @argv,(-stop  => $settings->{stop})  if defined $settings->{stop};
    $segment = $db->segment(@argv);
  }

  return unless $segment;

  $segment->absolute(1);

  # set CGI name parameter to match segment.
  # this prevents any confusion over (ref,start,stop) and (name) addressing.
  $settings->{ref}   = $segment->ref;
  $settings->{start} = $segment->start;
  $settings->{stop}  = $segment->stop;

  return $segment;
}

sub open_database {
  my $source  = $CONFIG->source;
  return $DB{$source} if $DB{$source};

  my $dsn     = $CONFIG->setting('database') or die "No database defined in $source";
  my $adaptor = $CONFIG->setting('adaptor') || 'dbi::mysqlopt';
  my @argv = (-adaptor => $adaptor,
	      -dsn     => $dsn);
  if (my $fasta = $CONFIG->setting('fasta_files')) {
    push @argv,(-fasta=>$fasta);
  }
  if (my $user = $CONFIG->setting('user')) {
    push @argv,(-user=>$user);
  }
  if (my $pass = $CONFIG->setting('pass')) {
    push @argv,(-pass=>$pass);
  }
  if (my @aggregators = split /\s+/,$CONFIG->setting('aggregators')) {
    push @argv,(-aggregator => \@aggregators);
  }
  $DB{$source} = Bio::DB::GFF->new(@argv) or die "Couldn't open database: ",Bio::DB::GFF->error;
  return $DB{$source};
}

sub image_and_map {
  my ($segment,$settings) = @_;
  return unless $segment;

  $CONFIG->width($settings->{width});

  my($image,$map) = $CONFIG->image_and_map($segment,$settings->{labels});
  my ($width,$height) = $image->getBounds;

  my $signature = md5_hex($segment,@{$settings->{labels}},$settings->{width},$settings->{source});
  my $url       = generate_image($image,$signature);
  my $img     = center(img({-src=>$url,-usemap=>'#hmap',-width => $width,-height => $height,-border=>0}));
  my $img_map = make_map($map);
  return join "\n",$img,$img_map;
}

sub overview {
  my ($segment,$settings) = @_;
  return unless $segment;
  $CONFIG->width($settings->{width}*OVERVIEW_RATIO);

  my ($image,$length) = $CONFIG->overview($segment) or return;
  my ($width,$height) = $image->getBounds;
  my $signature = md5_hex($segment,$width);
  my $url = generate_image($image,$signature);
  return table(TR(
		  td({-class=>'searchbody',-align=>'CENTER'},
		     image_button(-name=>'overview',
				  -src=>$url,
				  -width=>$width,
				  -height=>$height,
				  -border=>0,
				  -align=>'MIDDLE')
		    )
		 )
	      ).hidden(-name=>'seg_length',-value=>$length,-override=>1);
}

sub generate_image {
  my ($image,$signature) = @_;

  my $extension = $image->can('png') ? 'png' : 'gif';
  my ($uri,$path) = picture_tmpdir();
  my $url         = sprintf("%s/%s.%s",$uri,$signature,$extension);
  my $imagefile   = sprintf("%s/%s.%s",$path,$signature,$extension);
  open (F,">$imagefile") || die("Can't open image file $imagefile for writing: $!\n");
  print F $image->can('png') ? $image->png : $image->gif;
  close F;
  return $url;
}

sub picture_tmpdir {
  my $tmpuri = $CONFIG->setting('tmpimages') or die "no tmpimages option defined, can't generate a picture";
  my $tmpdir;
  if ($ENV{MOD_PERL}) {
    my $r = Apache->request;
    my $subr   = $r->lookup_uri($tmpuri);
    $tmpdir = $subr->filename;
  } else {
    $tmpdir = "$ENV{DOCUMENT_ROOT}/$tmpuri";
  }
  mkpath($tmpdir,0,0777) unless -d $tmpdir;
  return ($tmpuri,$tmpdir);
}


sub get_ranges {
  my @ranges	= split /\s+/,$CONFIG->setting('zoom levels');
  @ranges       = qw(500 1000 5000 10000 25000 100000 200000 400000) unless @ranges;
  @ranges;
}

sub make_map {
  my $boxes = shift;
  my $map = qq(<map name="hmap">\n);

  # use the scale as a centering mechanism
  my $ruler = shift @$boxes;
  $map .= make_centering_map($ruler);

  foreach (@$boxes){
    my $alt   = make_alt($_->[0]);
    my $href  = make_href($_->[0]);
    $map .= qq(<AREA SHAPE="RECT" COORDS="$_->[1],$_->[2],$_->[3],$_->[4]" 
	       HREF="$href" ALT="$alt" TITLE="$alt">\n);
  }
  $map .= "</map>\n";
  $map;
}

sub make_centering_map {
  my $ruler = shift;
  return if $ruler->[3]-$ruler->[1] == 0;

  my $offset = $ruler->[0]->start;
  my $scale  = $ruler->[0]->length/($ruler->[3]-$ruler->[1]);

  # divide into ten intervals
  my $portion = ($ruler->[3]-$ruler->[1])/10;
  Delete_all();
  param(ref => scalar($ruler->[0]->ref));

  my @lines;
  for my $i (0..19) {
    my $x1 = $portion * $i;
    my $x2 = $portion * ($i+1);
    # put the middle of the sequence range into
    # the middle of the picture
    my $middle = $offset + $scale * ($x1+$x2)/2;
    my $start  = int($middle - $ruler->[0]->length/2);
    my $stop   = int($start + $ruler->[0]->length - 1);
    param(start => int($start));
    param(stop  => int($stop));
    param(nav   => 1);
    param(source=> $CONFIG->source);
    my $url = url(-relative=>1,-query=>1,-path_info=>1);
    push @lines,
      qq(<AREA SHAPE="RECT" COORDS="$x1,$ruler->[2],$x2,$ruler->[4]"
	 HREF="$url" ALT="center" TITLE="center">\n);
  }
  return join '',@lines;
}

sub make_href {
  my $feature = shift;
  my $href    = $CONFIG->make_link($feature);
  return $href;
}

sub make_alt {
  my $feature = shift;
  my $label = $feature->class .":".$feature->info;
  if ($feature->method =~ /^(similarity|alignment)$/) {
    $label .= " ".commas($feature->target->start)."..".commas($feature->target->end);
  } else {
    $label .= " ".commas($feature->start)."..".commas($feature->stop);
  }
  return $label;
}

sub dump_fasta {
  my $segment = shift;
  my $dna = $segment->dna;
  $dna =~ s/(.{1,60})/$1\n/g;
  print ">$segment\n";
  print $dna;
}

sub dump_gff {
  my $segment = shift;
  my $page_settings = shift;
  my $labels = $page_settings->{labels} or return;
  my $date = localtime;
  print "##gff-version 2\n";
  print "##date $date\n";
  print "##sequence-region ",join(' ',$segment->ref,$segment->start,$segment->stop),"\n";

  my $conf = $CONFIG->config;
  my @feature_types = map {$conf->label2type($_)} @$labels;

  my $iterator = $segment->features(-types=>\@feature_types,-iterator=>1) or return;
  while (my $f = $iterator->next_feature) {
    print $f->gff_string,"\n";
    for my $s ($f->sub_SeqFeature) {
      print $s->gff_string,"\n";
    }
  }
}

# I know there must be a more elegant way to insert commas into a long number...
sub commas {
  my $i = shift;
  $i = reverse $i;
  $i =~ s/(\d{3})/$1,/g;
  chop $i if $i=~/,$/;
  $i = reverse $i;
  $i;
}

!NO!SUBS!
close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
chdir $origdir;
