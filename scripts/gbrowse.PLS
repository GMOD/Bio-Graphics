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
# $Id: gbrowse.PLS,v 1.11 2001-11-28 04:07:01 lstein Exp $

use strict;
use Bio::DB::GFF;
use Bio::Graphics;
use Bio::Graphics::Browser;
use Digest::MD5 'md5_hex';
use File::Path 'mkpath';
use Carp;
use CGI qw(:standard escape center *table *dl *TR *td);
use vars qw($CONFIG %DB $MAX_SEGMENT $DEFAULT_SEGMENT);

# if you change the zoom/nav icons, you must change this as well.
use constant MAG_ICON_HEIGHT => 20;
use constant MAG_ICON_WIDTH  => 8;
use constant MAX_SEGMENT     => 1_000_000;
use constant TOO_MANY_SEGMENTS => 5_000;
use constant DEFAULT_SEGMENT => 100_000;
use constant OVERVIEW_RATIO  => 0.9;

###################################################################
# Non-modperl users should change this constant if needed
#
my $CONF_DIR = '/usr/local/wormbase/conf/gbrowse.conf';
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

## PAGE SETTINGS ##############################################################################
#
# Recover a hashref which contains page-specific settings
# (this involves reading a cookie or possibly a database record in some future implementation
my ($source,$old_source) = get_source();
$CONFIG->source($source);
my $page_settings = get_settings($source);

$MAX_SEGMENT     = $CONFIG->setting('max segment')     || MAX_SEGMENT;
$DEFAULT_SEGMENT = $CONFIG->setting('default segment') || DEFAULT_SEGMENT;

# Now adjust those settings based on submitted CGI parameters
# With the exception that we ignore parameter changes if the source has changed.
if (defined($old_source) && $source ne $old_source) {
  param(name => $page_settings->{name});  # restore old reference point
} else {
  adjust_settings($page_settings);        # set settings from CGI parameters
}
###############################################################################################

## GETTING THE SEGMENT ########################################################################
my @segments  = get_segment($page_settings);
@segments     = merge(\@segments) if @segments > 1 && @segments < TOO_MANY_SEGMENTS;
###############################################################################################

## DUMPS ######################################################################################
if ( (my $dump = param('dump')) && @segments == 1) {
  if ($dump eq 'FastA') {
    print header(-attachment   => "$segments[0].fa",
		 -type         => 'text/plain');
    dump_fasta($segments[0],$page_settings);
  }

  elsif($dump eq 'GFF') {
    print header(-attachment   => "$segments[0].gff",
		 -type         => 'text/plain');
    dump_gff($segments[0],$page_settings);
  }
  exit 0;
}
###############################################################################################


## PRINTING THE PAGE ##########################################################################
print header(-cookie => settings2cookie($page_settings));

my $description = $CONFIG->setting('description');
my $segment;

print
  start_html(-title => 'Genome browser',
	    -style  => {src=>$CONFIG->setting('stylesheet')},
	    ),
  h1($description);

if (@segments == 1) {
  $segment = $segments[0];
  print h2("Showing",commas($segment->length),"bp from",
	   $segment->ref.", positions ".commas($segment->start)." to ".commas($segment->stop));
} 

elsif (@segments > 1) {
  multiple_choices(\@segments,$page_settings);
}

elsif (my $n = $page_settings->{name}) {

  print h2({-class=>'error'},"The landmark named",i($n),"is not recognized.",
	   "You may need to qualify it with the type, as in",i("PCR_Product:$n"))
}

print start_form(-action=>url(-relative=>1,-path_info=>1));

print navigation_table($segment,$page_settings);

if ($segment) {
  my $cell = overview($segment,$page_settings);
  if ($segment->length <= $MAX_SEGMENT) {
    $cell .= image_and_map($segment,$page_settings);
  } else {
    $cell .= i(
	       "Detailed view is limited to",
	       commas($MAX_SEGMENT),"bases.",
	       "Click in the overview to select a region",commas($DEFAULT_SEGMENT),'bp wide.');
  }
  print table({-border=>0,-width=>$page_settings->{width}},
	      TR({-class=>'searchbody'},
		 td($cell)
		)
	     );
}

print settings_table($page_settings);

print end_form(), 
  $CONFIG->setting('footer'),
  p(i(font({-size=>'small'},
	   'Note: This page uses cookie to save and restore preference information. No information is shared.'))),
  end_html;

###############################################################################################

sub get_source {
  my $new_source = param('source');
  my $old_source = cookie('gbrowse_source') unless param('source') && request_method() eq 'GET';

  my $source   = $new_source || $old_source;
  $source ||= $CONFIG->source;  # the default, whatever it is
  return ($source,$old_source);
}

# read from cookie, if there is one
# if not, set  from defaults
sub get_settings {
  my $source   = shift;
  my %settings = cookie("gbrowse_$source");

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
    $settings{width}  = $CONFIG->setting('default width');
    $settings{source} = $CONFIG->source;
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
  my @cookies;
  my $source = $CONFIG->source;
  push @cookies,cookie(-name    => "gbrowse_$source",
		      -value   => \%settings,
		      -expires => '+3M');
  push @cookies,cookie(-name   => 'gbrowse_source',
		       -value  => $source,
		       -expires => '+3M');
  return \@cookies;
}

sub adjust_settings {
  my $settings = shift;
  if (my @selected = param('label')) {
    $settings->{labels} = \@selected;
  }
  $settings->{width}  = param('width')   if param('width');

  if (param('ref') && (request_method() eq 'GET' || grep {/zoom|nav|overview/} param()) ) {
    $settings->{ref}   = param('ref');
    $settings->{start} = param('start') if param('start') =~ /^[\d-]+/;
    $settings->{stop}  = param('stop')  if param('stop')  =~ /^[\d-]+/;
    zoomnav($settings);
    $settings->{name} = "$settings->{ref}:$settings->{start}..$settings->{stop}";
    param(name => $settings->{name});
  }
  $settings->{name}   = param('name')   if param('name');
  $settings->{source} = param('source') if param('source');

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
			show_examples()
		    )),
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
  push @lines, (image_button(-src=>"$buttonsDir/green_l2.gif",-name=>'nav0',-border=>0,-title=>"b1"),
		image_button(-src=>"$buttonsDir/green_l1.gif",-name=>'nav1',-border=>0,-title=>"b2"),
		zoomBar($segment,$buttonsDir),
		image_button(-src=>"$buttonsDir/green_r1.gif",-name=>'nav2',-border=>0,-title=>"b3"),
		image_button(-src=>"$buttonsDir/green_r2.gif",-name=>'nav3',-border=>0,-title=>"b4"),
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
				-border => ,
#				-height => ($i+1)*$pixels_per_range,
#				-width  => MAG_ICON_WIDTH,
				-title  => $titleText);
  }

  return join('', @letters);
}


sub settings_table {
  my $settings = shift;

  my @widths = split /\s+/,$CONFIG->setting('image widths');
  @widths = (640,800,1024) unless @widths;

  # set up the dumps line.
  my($ref,$start,$stop) = @{$settings}{qw(ref start stop)};
  my $source   = $CONFIG->source;
  my $self     = url(-relative=>1,-path_info=>1);
  my @dumps    = (['GFF'  ,"$self?dump=GFF;start=$start;stop=$stop;ref=$ref;source=$source"]);
  unshift @dumps,['FastA',"$self?dump=FastA;start=$start;stop=$stop;ref=$ref;source=$source"]
    if $CONFIG->setting('fasta_files');

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
  my @segments;

  my $db = open_database();
  $db->debug(0);

  if (my $name = $settings->{name}) {
    my ($class,$start,$stop);
    if ($name =~ /(\w+):([\d,-]+)(?:-|\.\.)?([\d,-]+)$/) {
      $name = $1;
      $start = $2;
      $stop = $3;
      $start =~ s/,//g; # get rid of commas
      $stop  =~ s/,//g;
    }

    elsif ($name =~ /^(\w+):(.+)$/) {
      $class = $1;
      $name  = $2;
    }

    my @argv = (-name  => $name);
    push @argv,(-class => $class) if defined $class;
    push @argv,(-start => $start) if defined $start;
    push @argv,(-stop  => $stop)  if defined $stop;
    @segments = defined($start) ? $db->segment(@argv) : $db->segments(@argv);

    # Here starts the heuristic part.  Try various abbreviations that
    # people tend to use for chromosomal addressing.
    if (!@segments && $name =~ /^([\dIVXA-F]+)$/) {
      my $id = $1;
      foreach (qw(CHROMOSOME_ Chr chr)) {
	my $n = "${_}${id}";
	my @argv = (-name  => $n);
	push @argv,(-class => $class) if defined $class;
	push @argv,(-start => $start) if defined $start;
	push @argv,(-stop  => $stop)  if defined $stop;
	@segments = defined($start) ? $db->segment(@argv) : $db->segments(@argv) unless @segments;
      }
    }

    # try to remove the chr CHROMOSOME_I
    if (!@segments && $name =~ /^(chromosome_?|chr)/i) {
      (my $chr = $name) =~ s/^(chromosome_?|chr)//i;
      @segments = $db->segment($chr);
    }

    # try any "automatic" classes that have been defined in the config file
    if (!@segments && !$class && 
	(my @automatic = split /\s+/,$CONFIG->setting('automatic classes'))) {
      foreach $class (@automatic) {
	@segments = $db->segments($class => $name);
	last if @segments;
      }
    }
  }

  elsif (my $ref = $settings->{ref}) {
    my @argv = (-name  => $ref);
    push @argv,(-start => $settings->{start}) if defined $settings->{start};
    push @argv,(-stop  => $settings->{stop})  if defined $settings->{stop};
    @segments = $db->segment(@argv);
  }

  return unless @segments;
  return @segments if @segments > 1;

  return unless @segments;
  $segments[0]->absolute(1);

  # set CGI name parameter to match segment.
  # this prevents any confusion over (ref,start,stop) and (name) addressing.
  $settings->{ref}   = $segments[0]->ref;
  $settings->{start} = $segments[0]->start;
  $settings->{stop}  = $segments[0]->stop;

  return $segments[0];
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

  my $signature = md5_hex($segment,@{$settings->{labels}},$settings->{width},$CONFIG->source);
  my $url       = generate_image($image,$signature);
  my $img     = img({-src=>$url,-usemap=>'#hmap',-width => $width,-height => $height,-border=>0});
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
  return center(
		table(TR(
			 td({-class=>'searchbody',-align=>'CENTER'},
			    image_button(-name=>'overview',
					 -src=>$url,
					 -width=>$width,
					 -height=>$height,
					 -border=>0,
					 -align=>'MIDDLE')
			   )
			)
		     ).hidden(-name=>'seg_length',-value=>$length,-override=>1)
		);
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


sub multiple_choices {
  my $segments = shift;
  my $settings = shift;

  my $message = "The landmark named ".param('name')." exists in multiple locations";
  $message   .= @$segments > TOO_MANY_SEGMENTS ?  ", but there are too many to choose from (".@$segments.")."
                                                 ." Please try a different landmark." 
                                               : ". Please choose one.";

  print start_table({-class=>'searchtitle'});
  print TR(th(font({-color=>'red'},$message)));
  if (@$segments <= TOO_MANY_SEGMENTS) {
    print start_TR({-class=>'searchbody'}),start_td();
  
    # aggregate segments by reference and then split on gaps of > 1 M
    my %segs;
    push @{$segs{$_->ref}},$_ foreach @$segments;

    my $url = url(-relative=>1,-path_info=>1);
    my $source = $CONFIG->source;

    print start_dl;
    for my $ref (sort keys %segs) {
      my @spans  = sort {$a->start <=> $b->start} @{$segs{$ref}};
      print dt($ref),"\n";
      foreach (@spans) {
	my ($start,$stop) = ($_->start,$_->stop);
	my $bp = $stop - $start;
	my $s = commas($start);
	my $e = commas($stop);
	print dd(a({-href=>"$url?source=$source;ref=$ref;start=$start;stop=$stop"},"$s..$e ($bp bp)")),"\n";
      }

    }
    print end_dl,end_td,end_TR;
  }
  print end_table;
}

sub merge {
  my $features = shift;

  my (%segs,@merged_segs);
  push @{$segs{$_->ref}},$_ foreach @$features;
  foreach (keys %segs) {
    push @merged_segs,low_merge($segs{$_});
  }
  return @merged_segs;
}

sub low_merge {
  my $features = shift;

  my $max_range = (get_ranges())[-1];
  my $db = open_database();
  my ($previous_start,$previous_stop,$statistical_cutoff,@spans);

  my @features = sort {$a->low<=>$b->low} @$features;

  # run through the segments, and find the mean and stdev gap length
  if (@features >= 3) {
    my ($total,$gap_length,@gaps);
    for (my $i=0; $i<@$features-1; $i++) {
      my $gap = $features[$i+1]->low - $features[$i]->high;
      $total++;
      $gap_length += $gap;
      push @gaps,$gap;
    }
    my $mean = $gap_length/$total;
    my $variance;
    $variance += ($_-$mean)**2 foreach @gaps;
    my $stdev = sqrt($variance/$total);
    $statistical_cutoff = $stdev * 2;
  } else {
    $statistical_cutoff = $max_range;
  }

  my $ref = $features[0]->ref;

  for my $f (@features) {
    my $start = $f->low;
    my $stop  = $f->high;

    if (defined($previous_stop) && 
	( $start-$previous_stop >= $max_range || 
	  $previous_stop-$previous_start >= $max_range ||
	  $start-$previous_stop >= $statistical_cutoff)) {
      push @spans,$db->segment($ref,$previous_start,$previous_stop);
      $previous_start = $start;
      $previous_stop  = $stop;
    } 

    else {
      $previous_start = $start unless defined $previous_start;
      $previous_stop  =   $stop;
    }

  }
  push @spans,$db->segment($ref,$previous_start,$previous_stop);
  return @spans;
}

sub show_examples {
  my @examples = split /\s+/,$CONFIG->setting('examples');
  return unless @examples;
  my $url    = url(-relative=>1,-path_info=>1);
  my $source = $CONFIG->source;
  my @urls = map { a({-href=>"$url?source=$source;name=".escape($_)},$_) } @examples;
  return b('Examples: ').join ', ',@urls;
}

!NO!SUBS!
close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
chdir $origdir;
