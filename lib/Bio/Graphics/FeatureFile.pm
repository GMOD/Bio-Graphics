package Bio::Graphics::FeatureFile;

# $Id: FeatureFile.pm,v 1.14 2009-05-29 14:48:06 lstein Exp $
# This package parses and renders a simple tab-delimited format for features.
# It is simpler than GFF, but still has a lot of expressive power.
# See __END__ for the file format

=head1 NAME

Bio::Graphics::FeatureFile -- A set of Bio::Graphics features, stored in a file

=head1 SYNOPSIS

 use Bio::Graphics::FeatureFile;
 my $data  = Bio::Graphics::FeatureFile->new(-file => 'features.txt');


 # create a new panel and render contents of the file onto it
 my $panel = $data->new_panel;
 my $tracks_rendered = $data->render($panel);

 # or do it all in one step
 my ($tracks_rendered,$panel) = $data->render;

 # for more control, render tracks individually
 my @feature_types = $data->types;
 for my $type (@feature_types) {
    my $features = $data->features($type);
    my %options  = $data->style($type);
    $panel->add_track($features,%options);  # assuming we have a Bio::Graphics::Panel
 }

 # get individual settings
 my $est_fg_color = $data->setting(EST => 'fgcolor');

 # or create the FeatureFile by hand

 # add a type
 $data->add_type(EST => {fgcolor=>'blue',height=>12});

 # add a feature
 my $feature = Bio::Graphics::Feature->new(
                                             # params
                                          ); # or some other SeqI
 $data->add_feature($feature=>'EST');

=head1 DESCRIPTION

The Bio::Graphics::FeatureFile module reads and parses files that
describe sequence features and their renderings.  It accepts both GFF
format and a more human-friendly file format described below.  Once a
FeatureFile object has been initialized, you can interrogate it for
its consistuent features and their settings, or render the entire file
onto a Bio::Graphics::Panel.

This module is a precursor of Jason Stajich's
Bio::Annotation::Collection class, and fulfills a similar function of
storing a collection of sequence features.  However, it also stores
rendering information about the features, and does not currently
follow the CollectionI interface.

=head1 The File Format

There are two types of entry in the file format: feature entries, and
formatting entries.  They can occur in any order.  See the Appendix
for a full example.

=head2 Formatting Entries

Formatting entries are in the form:

 [Stanza Name]
 option1 = value1
 option2 = value2
 option3 = value3

 [Stanza Name 2]
 option1 = value1
 option2 = value2
 ...

There can be zero or more stanzas, each with a unique name. The names
can contain any character except the [] characters. Each stanza
consists of one or more option = value pairs, where the option and the
value are separated by an "=" sign and optional whitespace. Values can
be continued across multiple lines by indenting the continuation lines
by one or more spaces, as in:

 [Named Genes]
 feature = gene
 glyph   = transcript2
 description = These are genes that have been named
   by the international commission on gene naming
   (The Hague).

Typically configuration stanzas will consist of several Bio::Graphics
formatting options. A -option=>$value pair passed to
Bio::Graphics::Panel->add_track() becomes a "option=value" pair in the
feature file.

=head2 Feature Entries

Feature entries can take several forms.  At their simplest, they look
like this:

 Gene	B0511.1	Chr1:516..11208

This means that a feature of type "Gene" and name "B0511.1" occupies
the range between bases 516 and 11208 on a sequence entry named
Chr1. Columns are separated using whitespace (tabs or spaces).
Embedded whitespace can be escaped using quote marks or backslashes:

 Gene "My Favorite Gene" Chr1:516..11208

=head2 Specifying Positions and Ranges

A feature position is specified using a sequence ID (a genbank
accession number, a chromosome name, a contig, or any other meaningful
reference system, followed by a colon and a position range. Ranges are
two integers separated by double dots or the hyphen. Examples:
"Chr1:516..11208", "ctgA:1-5000". Negative coordinates are allowed, as
in "Chr1:-187..1000".

A discontinuous range ("split location") uses commas to separate the
ranges.  For example:

 Gene B0511.1  Chr1:516..619,3185..3294,10946..11208

In the case of a split location, the sequence id only has to appear in
front of the first range.

Alternatively, a split location can be indicated by repeating the
features type and name on multiple adjacent lines:

 Gene	B0511.1	Chr1:516..619
 Gene	B0511.1	Chr1:3185..3294
 Gene	B0511.1	Chr1:10946..11208

If all the locations are on the same reference sequence, you can
specify a default chromosome using a "reference=<seqid>":

 reference=Chr1
 Gene	B0511.1	516..619
 Gene	B0511.1	3185..3294
 Gene	B0511.1	10946..11208

The default seqid is in effect until the next "reference" line
appears.

=head2 Feature Tags

Tags can be added to features by adding a fourth column consisting of
"tag=value" pairs:

 Gene  B0511.1  Chr1:516..619,3185..3294 Note="Putative primase"

Tags and their values take any form you want, and multiple tags can be
separated by semicolons. You can also repeat tags multiple times:

 Gene  B0511.1  Chr1:516..619,3185..3294 GO_Term=GO:100;GO_Term=GO:2087

Several tags have special meanings:

 Tag     Meaning
 ---     -------

 Type    The primary tag for a subfeature.
 Score   The score of a feature or subfeature.
 Phase   The phase of a feature or subfeature.
 URL     A URL to link to (via the Bio::Graphics library).
 Note    A note to attach to the feature for display by the Bio::Graphics library.

For example, in the common case of an mRNA, you can use the "Type" tag
to distinguish the parts of the mRNA into UTR and CDS:

 mRNA B0511.1 Chr1:1..100 Type=UTR
 mRNA B0511.1 Chr1:101..200,300..400,500..800 Type=CDS
 mRNA B0511.1 Chr1:801..1000 Type=UTR

The top level feature's primary tag will be "mRNA", and its subparts
will have types UTR and CDS as indicated. Additional tags that are
placed in the first line of the feature will be applied to the top
level. In this example, the note "Putative primase" will be applied to
the mRNA at the top level of the feature:

 mRNA B0511.1 Chr1:1..100 Type=UTR;Note="Putative primase"
 mRNA B0511.1 Chr1:101..200,300..400,500..800 Type=CDS
 mRNA B0511.1 Chr1:801..1000 Type=UTR

=head2 Feature Groups

Features can be grouped so that they are rendered by the "group"
glyph.  To start a group, create a two-column feature entry showing
the group type and a name for the group.  Follow this with a list of
feature entries with a blank type.  For example:

 EST	yk53c10
 	yk53c10.3	15000-15500,15700-15800
 	yk53c10.5	18892-19154

This example is declaring that the ESTs named yk53c10.3 and yk53c10.5
belong to the same group named yk53c10.

=head2 Comments

Lines that begin with the # sign are treated as comments and
ignored. When a # sign appears within a line, everything to the right
of the symbol is also ignored, unless it looks like an HTML fragment or
an HTML color, e.g.:

 # this is ignored
 [Example]
 glyph   = generic   # this comment is ignored
 bgcolor = #FF0000
 link    = http://www.google.com/search?q=$name#results

Be careful, because the processing of # signs uses a regexp heuristic. To be safe, 
always put a space after the # sign to make sure it is treated as a comment.

=head2 The #include and #exec Directives

The special comment "#include 'filename'" acts like the C preprocessor
directive and will insert the comments of a named file into the
position at which it occurs. Relative paths will be treated relative
to the file in which the #include occurs. Nested #include directives
(a #include located in a file that is itself an include file) are
#allowed. You may also use one of the shell wildcard characters * and
#? to include all matching files in a directory.

The following are examples of valid #include directives:

 #include "/usr/local/share/my_directives.txt"
 #include 'my_directives.txt'
 #include chromosome3_features.gff3
 #include gff.d/*.conf
 
You can enclose the file path in single or double quotes as shown
above. If there are no spaces in the filename the quotes are optional.
The #include directive is case insensitive, allowing you to use
#INCLUDE or #Include if you prefer.

Include file processing is not very smart and will not catch all
circular #include references. You have been warned!

The special comment "#exec 'command'" will spawn a shell and
incorporate the output of the command into the configuration
file. This command will be executed quite frequently, so it is
suggested that any time-consuming processing that does not need to be
performed on the fly each time should be cached in a local file.

=cut

use strict;
use Bio::Graphics::Feature;
use Bio::DB::GFF::Util::Rearrange;
use Carp 'cluck','carp','croak';
use IO::File;
use File::Glob ':glob';
use Text::ParseWords 'shellwords';
use Bio::DB::SeqFeature::Store;
use File::Basename 'dirname';
use File::Spec;
use Cwd 'getcwd';

# default colors for unconfigured features
my @COLORS = qw(cyan blue red yellow green wheat turquoise orange);

# package variable which holds the limited set of libraries accessible
# from within the Safe::World container (please see the description of
# the -safe_world option).
# my $SAFE_LIB;

use constant WIDTH => 600;
use constant MAX_REMAP => 100;

=head2 METHODS

=over 4

=item $version = Bio::Graphics::FeatureFile-E<gt>version

Return the version number -- needed for API checking by GBrowse

=cut

sub version { return 2 }

=item $features = Bio::Graphics::FeatureFile-E<gt>new(@args)

Create a new Bio::Graphics::FeatureFile using @args to initialize the
object.  Arguments are -name=E<gt>value pairs:

  Argument         Value
  --------         -----

   -file           Read data from a file path or filehandle.  Use
                   "-" to read from standard input.

   -text           Read data from a text scalar.

   -allow_whitespace If true, relax GFF2 and GFF3 parsing rules to allow
                   columns to be delimited by whitespace rather than
                   tabs.

   -map_coords     Coderef containing a subroutine to use for remapping
                   all coordinates.

   -smart_features Flag indicating that the features created by this
                   module should be made aware of the FeatureFile
		   object by calling their configurator() method.

   -safe           Indicates that the contents of this file is trusted.
                   Any option value that begins with the string "sub {"
                   or \&subname will be evaluated as a code reference.

   -safe_world     If the -safe option is not set, and -safe_world
                   is set to a true value, then Bio::Graphics::FeatureFile
                   will evalute "sub {}" options in a L<Safe::World>
                   environment with minimum permissions. Subroutines
                   will be able to access and interrogate 
                   Bio::DB::SeqFeature objects and perform basic Perl
                   operations, but will have no ability to load or
                   access other modules, to access the file system,
                   or to make system calls. This feature depends on
                   availability of the CPAN-installable L<Safe::World>
                   module.

The -file and -text arguments are mutually exclusive, and -file will
supersede the other if both are present.

-map_coords points to a coderef with the following signature:

  ($newref,[$start1,$end1],[$start2,$end2]....)
            = coderef($ref,[$start1,$end1],[$start2,$end2]...)

See the Bio::Graphics::Browser (part of the generic genome browser
package) for an illustration of how to use this to do wonderful stuff.

The -smart_features flag is used by the generic genome browser to
provide features with a way to access the link-generation code.  See
gbrowse for how this works.

If the file is trusted, and there is an option named "init_code" in
the [GENERAL] section of the file, it will be evaluated as perl code
immediately after parsing.  You can use this to declare global
variables and subroutines for use in option values.

=cut

# args array:
# -file => parse from a file (- allowed for ARGV)
# -text => parse from a text scalar
# -map_coords => code ref to do coordinate mapping
#                called with ($ref,[$start1,$stop1],[$start2,$stop2]...)
#                returns     ($newref,$new_coord1,$new_coord2...)

sub new {
    shift->_new(@_);
}

sub _new {
  my $class = shift;
  my %args  = @_;
  my $self = bless {
		    config   => {},
		    features => {},
		    seenit   => {},
		    types    => [],
		    max      => undef,
		    min      => undef,
		    stat     => [],
		    refs     => {},
                    safe     => undef,
		    safe_world => undef,
		   },$class;
  $self->{coordinate_mapper} = $args{-map_coords} 
    if exists $args{-map_coords} && ref($args{-map_coords}) eq 'CODE';

  $self->smart_features($args{-smart_features})   if exists $args{-smart_features};
  $self->{safe}              = $args{-safe}       if exists $args{-safe};
  $self->safe_world(1)                            if $args{-safe_world};
  $self->allow_whitespace(1)                      if $args{-allow_whitespace};

  $self->init_parse();

  # call with
  #   -file
  #   -text
  if (my $file = $args{-file}) {
    no strict 'refs';
    if (defined fileno($file)) { # a filehandle
	$self->parse_fh($file);
    } elsif ($file eq '-') {
	$self->parse_argv();
    } else {
	$self->parse_file($file);
    }
  } elsif (my $text = $args{-text}) {
      $self->parse_text($text);
  }

  $self->finish_parse();
  return $self;
}

=item $features = Bio::Graphics::FeatureFile-E<gt>new_from_cache(@args)

Like new() but caches the parsed file in /tmp/bio_graphics_ff_cache_*
(where * is the UID of the current user). This can speed up parsing
tremendously for files that have many includes.

Note that the presence of an #exec statement always invalidates the
cache and causes a full parse.

=cut

sub new_from_cache {
    my $self = shift;
    my %args = @_;
    my $has_libs;

    unless ($has_libs = defined &nfreeze) {
	$has_libs = eval <<END;
use Storable 'lock_store','lock_retrieve';
use File::Path 'mkpath';
1;
END
    warn "You need Storable to use new_from_cache(); returning uncached data" unless $has_libs;
    }

    $Storable::Deparse = 1;
    $Storable::Eval    = 1;

    my $file      = $has_libs && $args{-file} or return $self->_new(@_);
    (my $name     = $args{-file}) =~ s!/!_!g;
    my $cachefile = $self->cachefile($name);
    if (-e $cachefile && (stat(_))[9] >= $self->file_mtime($args{-file})) { # cache is valid
	my $parsed_file = lock_retrieve($cachefile);
	$parsed_file->initialize_code if $parsed_file->safe;
	return $parsed_file;
    } else {
	mkpath(dirname($cachefile));
	my $parsed = $self->_new(@_);
	lock_store($parsed,$cachefile);
	return $parsed;
    }
    
}

sub cachedir {
    my $self = shift;
    my $uid       = $<;
    return File::Spec->catfile(File::Spec->tmpdir,"bio_graphics_ff_cache_${uid}");
}

sub cachefile {
    my $self = shift;
    my $name = shift;
    return File::Spec->catfile($self->cachedir,$name);
}

=item $mtime = Bio::Graphics::FeatureFile->file_mtime($path)

Return the modification time of the indicated feature file without performing a full parse. This
takes into account the various #include and #exec directives and returns the maximum mtime of
any of the included files. Any #exec directive will return the current time. This is
useful for caching the parsed data structure.

=back

=cut

sub file_mtime {
    my $self = shift;

    my $file  = shift;
    my $mtime = 0;

    for my $f (glob($file)) {
	my $m  = (stat($f))[9] or next;
	$mtime = $m if $mtime < $m;
	open my $fh,'<',$file or next;
	my $cwd = getcwd();
	chdir(dirname($file));

        local $_;
	while (<$fh>) {
	    if (/^\#exec/) {
		return time();  # now!
	    }
	    if (/^\#include\s+(.+)/i) {  # #include directive
		my ($include_file) = shellwords($1);
		my $m  = $self->file_mtime($include_file);
		$mtime = $m if $mtime < $m;
	    }
	}
	chdir($cwd);
    }

    return $mtime;
}

sub file_list {
    my $self = shift;
    my @list = ();
    my $file  = shift;

    for my $f (glob($file)) {
        open my $fh,'<',$file or next;
        my $cwd = getcwd();
        chdir(dirname($file));


        while (<$fh>) {
            if (/^\#include\s+(.+)/i) {  # #include directive
                my ($include_file) = shellwords($1);
                my @files = glob($include_file);
                @files ? @list = (@list,@files) : push(@list,$include_file);
            }
        }
        chdir($cwd);
    }

    return \@list;
}

# render our features onto a panel using configuration data
# return the number of tracks inserted

=over 4

=item ($rendered,$panel,$tracks) = $features-E<gt>render([$panel, $position_to_insert, $options, $max_bump, $max_label, $selector])

Render features in the data set onto the indicated
Bio::Graphics::Panel.  If no panel is specified, creates one.

All arguments are optional.

$panel is a Bio::Graphics::Panel that has previously been created and
configured.

$position_to_insert indicates the position at which to start inserting
new tracks. The last current track on the panel is assumed.

$options is a scalar used to control automatic expansion of the
tracks. 0=auto, 1=compact, 2=expanded, 3=expand and label,
4=hyperexpand, 5=hyperexpand and label.

$max_bump and $max_label indicate the maximum number of features
before bumping and labeling are turned off.

$selector is a code ref that can be used to filter which features to
render. It receives a feature and should return true to include the
feature and false to exclude it.

In a scalar context returns the number of tracks rendered.  In a list
context, returns a three-element list containing the number of
features rendered, the created panel, and an array ref of all the
track objects created.

Instead of a Bio::Graphics::Panel object, you can provide a hash
reference containing the arguments that you would pass to
Bio::Graphics::Panel->new(). For example, to render an SVG image, you
could do this:

  my ($tracks_rendered,$panel) = $data->render({-image_class=>'GD::SVG'});
  print $panel->svg;

=back

=cut

#"

sub render {
  my $self  = shift;
  my $panel = shift;         # 8 arguments
  my ($position_to_insert,
      $options,
      $max_bump,
      $max_label,
      $selector,
      $range,
      $override_options
      ) = @_;
  my %seenit;

  unless ($panel && UNIVERSAL::isa($panel,'Bio::Graphics::Panel')) {
      $panel = $self->new_panel($panel);
  }

  # count up number of tracks inserted
  my @tracks;
  my $color;
  my @labels             = $self->labels;

  # we need to add a dummy section for each type that isn't
  # specifically configured

  my %types   = map {$_=>1
  } map {
      shellwords ($self->setting($_=>'feature')||$_) } @labels;
  my %lc_types = map {lc($_)}%types;

  my @unconfigured_types = sort grep {!exists $lc_types{lc $_} &&
					  !exists $lc_types{lc $_->method}
  }         $self->types;

  my @configured_types   = keys %types;

  my @labels_to_render = (@labels,@unconfigured_types);

  my @base_config = $self->style('general');

  my @pack_options = ();
  if ($options && ref $options eq 'HASH') {
    @pack_options = %$options;
  } else {
    $options ||= 0;
    if ($options == 1) {  # compact
      push @pack_options,(-bump => 0,-label=>0);
    } elsif ($options == 2) { #expanded
      push @pack_options,(-bump=>1);
    } elsif ($options == 3) { #expand and label
      push @pack_options,(-bump=>1,-label=>1);
    } elsif ($options == 4) { #hyperexpand
      push @pack_options,(-bump => 2);
    } elsif ($options == 5) { #hyperexpand and label
      push @pack_options,(-bump => 2,-label=>1);
    }
  }

  for my $label (@labels_to_render) {


      my @types = shellwords($self->setting($label=>'feature')||'');
      @types    = $label unless @types;

      next if defined $selector and !$selector->($self,$label);

      my @features = !$range ? grep {$self->_visible($_)} $self->features(\@types)
                             : $self->features(-types   => \@types,
					       -seq_id  => $range->seq_id,
					       -start   => $range->start,
					       -end     => $range->end
					      );
      next unless @features;  # suppress tracks for features that don't appear

      # fix up funky group hack
      foreach (@features) {$_->primary_tag('group') if $_->has_tag('_ff_group')};
      my $features = \@features;

      my @auto_bump;
      push @auto_bump,(-bump  => @$features < $max_bump)  if defined $max_bump;
      push @auto_bump,(-label => @$features < $max_label) if defined $max_label;

      my @more_arguments = $override_options ? @$override_options : ();

      my @config = ( -glyph   => 'segments',         # really generic
		     -bgcolor => $COLORS[$color++ % @COLORS],
		     -label   => 1,
		     -description => 1,
		     -key     => $features[0]->type || $label,
		     @auto_bump,
		     @base_config,         # global
		     $self->style($label),  # feature-specific
		     @pack_options,
		     @more_arguments,
	  );

      if (defined($position_to_insert)) {
	  push @tracks,$panel->insert_track($position_to_insert++,$features,@config);
      } else {
	  push @tracks,$panel->add_track($features,@config);
      }
  }
  return wantarray ? (scalar(@tracks),$panel,\@tracks) : scalar @tracks;
}

sub _stat {
  my $self = shift;
  my $file = shift;
  defined fileno($file)  or return;
  my @stat = stat($file) or return;
  if ($self->{stat} && @{$self->{stat}}) { # merge #includes so that mtime etc are max age
      for (8,9,10) {
	  $self->{stat}[$_] = $stat[$_] if $stat[$_] > $self->{stat}[$_];
      }
      $self->{stat}[7] += $stat[7];
  } else {
      $self->{stat} = \@stat;
  }
}

sub _visible {
    my $self = shift;
    my $feat = shift;
    my $min  = $self->min;
    my $max  = $self->max;
    return $feat->start<=$max && $feat->end>=$min;
}

=over 4

=item $error = $features-E<gt>error([$error])

Get/set the current error message.

=back

=cut

sub error {
  my $self = shift;
  my $d = $self->{error};
  $self->{error} = shift if @_;
  $d;
}

=over 4

=item $smart_features = $features-E<gt>smart_features([$flag]

Get/set the "smart_features" flag.  If this is set, then any features
added to the featurefile object will have their configurator() method
called using the featurefile object as the argument.

=back

=cut

sub smart_features {
  my $self = shift;
  my $d = $self->{smart_features};
  $self->{smart_features} = shift if @_;
  $d;
}

sub parse_argv {
  my $self = shift;
  local $/ = "\n";
  local $_;
  while (<>) {
    chomp;
    $self->parse_line($_);
  }
}

sub parse_file {
    my $self = shift;
    my $file = shift;

    $file =~ s/(\s)/\\$1/g; # escape whitespace from glob expansion

    for my $f (glob($file)) {
	my $fh   = IO::File->new($f) or return;
	my $cwd  = getcwd();
	chdir(dirname($f));
	$self->parse_fh($fh);
	chdir($cwd);
    }
}

sub parse_fh {
    my $self = shift;
    my $fh   = shift;
    $self->_stat($fh);
    local $/ = "\n";
    local $_;
    while (<$fh>) {
	chomp;
	$self->parse_line($_) || last;
    }
}

sub parse_text {
  my $self = shift;
  my $text = shift;

  foreach (split m/\015?\012|\015\012?/,$text) {
    $self->parse_line($_);
  }
}

sub parse_line {
  my $self = shift;
  my $line = shift;

  $line =~ s/\015//g;  # get rid of carriage returns left over by MS-DOS/Windows systems
  $line =~ s/\s+$//;   # get rid of trailing whitespace

  if (/^#include\s+(.+)/i) {  # #include directive
      my ($include_file) = shellwords($1);
      # detect some loops
      croak "#include loop detected at $include_file"
	  if $self->{includes}{$include_file}++;
      $self->parse_file($include_file);
      return 1;
  }

  if (/^#exec\s+(.+)/i) {  # #exec directive
      my ($command,@args) = shellwords($1);
      open (my $fh,'-|') || exec $command,@args;
      $self->parse_fh($fh);
      return 1;
  }

  return 1 if $line =~ /^\s*\#[^\#]?$/;   # comment line

  # Are we in a configuration section or a data section?
  # We start out in 'config' state, and are triggered to
  # reenter config state whenever we see a /^\[ pattern (config section)
  my $old_state = $self->{state};
  my $new_state = $self->_state_transition($line);

  if ($new_state ne $old_state) {
      delete $self->{current_config};
      delete $self->{current_tag};
  }

  if ($new_state eq 'config') {
      $self->parse_config_line($line);
  } elsif ($new_state eq 'data') {
      $self->parse_data_line($line);
  }
  $self->{state} = $new_state;
  1;
}

sub _state_transition {
    my $self = shift;
    my $line = shift;
    my $current_state = $self->{state};

    if ($current_state eq 'data') {
	return 'config' if $line =~ m/^\s*\[([^\]]+)\]/;  # start of a configuration section
    }

    elsif ($current_state eq 'config') {
	return 'data'   if $line =~ /^\#\#(\w+)/;     # GFF3 meta instruction
	return 'data'   if $line =~ /^reference\s*=/; # feature-file reference sequence directive
	
	return 'config' if $line =~ /^\s*$/;                             #empty line
	return 'config' if $line =~ m/^\[([^\]]+)\]/;                    # section beginning
	return 'config' if $line =~ m/^[\w\s]+=/ 
	    && $self->{current_config};                                  # configuration line
	return 'config' if $line =~ m/^\s+(.+)/
	    && $self->{current_tag};                                     # continuation section
	return 'config' if $line =~ /^\#/;                               # comment -not a meta
	return 'data';
    }
    return $current_state;
}

sub parse_config_line {
    my $self = shift;
    local $_ = shift;

    # strip right-column comments unless they look like colors or html fragments
    s/\s*\#.*$// unless /\#[0-9a-f]{6,8}\s*$/i || /\w+\#\w+/ || /\w+\"*\s*\#\d+$/;   

    if (/^\s+(.+)/ && $self->{current_tag}) { # configuration continuation line
	my $value = $1;
	my $cc = $self->{current_config} ||= 'general';       # in case no configuration named
	$self->{config}{$cc}{$self->{current_tag}} .= ' ' . $value;
	# respect newlines in code subs
	$self->{config}{$cc}{$self->{current_tag}} .= "\n"
	    if $self->{config}{$cc}{$self->{current_tag}}=~ /^sub\s*\{/;
	return 1;
    }

    elsif (/^\[([^\]]+)\]/) {  # beginning of a configuration section
	my $label = $1;
	my $cc = $label =~ /^(general|default)$/i ? 'general' : $label;  # normalize
	push @{$self->{types}},$cc unless $cc eq 'general';
	$self->{current_config} = $cc;
	return 1;
    }

    elsif (/^([\w: -]+?)\s*=\s*(.*)/) {   # key value pair within a configuration section
	my $tag = lc $1;
	my $cc = $self->{current_config} ||= 'general';       # in case no configuration named
	my $value = defined $2 ? $2 : '';
	$self->{config}{$cc}{$tag} = $value;
	$self->{current_tag} = $tag;
	return 1;
    }


    elsif (/^$/) { # empty line
     # no longer required -- new sections are indicated by the start of a [stanza]
     # line and not by termination with a blank line
     #	undef $self->{current_tag}; 
	return 1;
    }

}

sub parse_data_line {
    my $self = shift;
    my $line = shift;
    $self->{loader} ||= $self->_make_loader($line) or return;
    $self->{loader}->load_line($line);
}

sub _make_loader {
    my $self = shift;
    local $_ = shift;
    my $db   = $self->db;

    my $type;

    # we support gff2, gff3 and featurefile formats
    if (/^\#\#gff-version\s+([23])/) {
	$type = "Bio::DB::SeqFeature::Store::GFF$1Loader";
    }
    elsif (/^reference\s*=.+/) {
	$type = "Bio::DB::SeqFeature::Store::FeatureFileLoader";
    }
    else {
	my @tokens = shellwords($_);
	unshift @tokens,'' if /^\s+/ and length $tokens[0];
	
	if (@tokens >=8 && $tokens[3]=~ /^-?\d+$/ && $tokens[4]=~ /^-?\d+$/) {
	    $type = 'Bio::DB::SeqFeature::Store::GFF3Loader';
	} 
	else {
	    $type = 'Bio::DB::SeqFeature::Store::FeatureFileLoader';
	}
    }
    eval "require $type"
	    unless $type->can('new');
    my $loader = $type->new(-store             => $db,
			    -map_coords        => $self->{coordinate_mapper},
			    -index_subfeatures => 0,
	);
    eval {$loader->allow_whitespace(1)} 
        if $self->allow_whitespace;  # gff2 and gff3 loaders allow this

    $loader->start_load() if $loader;
    return $loader;
}

sub db {
    my $self = shift;
    return $self->{db} ||= Bio::DB::SeqFeature::Store->new(-adaptor=>'memory',
							   -write  => 1);
}

=over 4

=item $flat = $features-E<gt>allow_whitespace([$new_flag])

If true, then GFF3 and GFF2 parsing is relaxed to allow whitespace to
delimit the columns. Default is false.

=back

=cut

sub allow_whitespace {
    my $self = shift;
    my $d    = $self->{allow_whitespace};
    $self->{allow_whitespace} = shift if @_;
    $d;
}

=over 4

=item $features-E<gt>add_feature($feature [=E<gt>$type])

Add a new Bio::FeatureI object to the set.  If $type is specified, the
object's primary_tag() will be set to that type. Otherwise, the method
will use the feature's existing primary_tag() to index and store the
feature.

=back

=cut

# add a feature of given type to our list
# we use the primary_tag() method
sub add_feature {
  my $self = shift;
  my ($feature,$type) = @_;
  $feature->configurator($self) if $self->smart_features;
  $feature->primary_tag($type) if defined $type;
  $self->db->store($feature);
}


=over 4

=item $features-E<gt>add_type($type=E<gt>$hashref)

Add a new feature type to the set.  The type is a string, such as
"EST".  The hashref is a set of key=E<gt>value pairs indicating options to
set on the type.  Example:

  $features->add_type(EST => { glyph => 'generic', fgcolor => 'blue'})

When a feature of type "EST" is rendered, it will use the generic
glyph and have a foreground color of blue.

=back

=cut

# Add a type to the list.  Hash values are used for key/value pairs
# in the configuration.  Call as add_type($type,$configuration) where
# $configuration is a hashref.
sub add_type {
  my $self = shift;
  my ($type,$type_configuration) = @_;
  my $cc = $type =~ /^(general|default)$/i ? 'general' : $type;  # normalize
  push @{$self->{types}},$cc unless $cc eq 'general' or $self->{config}{$cc};
  if (defined $type_configuration) {
    for my $tag (keys %$type_configuration) {
      $self->{config}{$cc}{lc $tag} = $type_configuration->{$tag};
    }
  }
}



=over 4

=item $features-E<gt>set($type,$tag,$value)

Change an individual option for a particular type.  For example, this
will change the foreground color of EST features to my favorite color:

  $features->set('EST',fgcolor=>'chartreuse')

=back

=cut

# change configuration of a type.  Call as set($type,$tag,$value)
# $type will be added if not already there.
sub set {
  my $self = shift;
  croak("Usage: \$featurefile->set(\$type,\$tag,\$value\n")
    unless @_ == 3;
  my ($type,$tag,$value) = @_;
  unless ($self->{config}{$type}) {
    return $self->add_type($type,{$tag=>$value});
  } else {
    $self->{config}{$type}{lc $tag} = $value;
  }
}

# break circular references
sub finished {
  my $self = shift;
  delete $self->{features};
}

sub DESTROY { 
    my $self = shift;
    $self->finished(@_);
#    $self->{safe_context}->unlink_all_worlds
#	if $self->{safe_context};
}

=over 4

=item $value = $features-E<gt>setting($stanza =E<gt> $option)

In the two-element form, the setting() method returns the value of an
option in the configuration stanza indicated by $stanza.  For example:

  $value = $features->setting(general => 'height')

will return the value of the "height" option in the [general] stanza.

Call with one element to retrieve all the option names in a stanza:

  @options = $features->setting('general');

Call with no elements to retrieve all stanza names:

  @stanzas = $features->setting;

=back

=cut

sub setting {
  my $self = shift;
  if (@_ > 2) {
    $self->{config}->{$_[0]}{$_[1]} = $_[2];
  }

  elsif (@_ <= 1) {
      return $self->_setting(@_);
  }

  elsif ($self->safe) {
      return $self->code_setting(@_);
  }

  elsif ($self->safe_world) {
      return $self->safe_setting(@_);
  }

  else {
      $self->{code_check}++ && $self->clean_code(); # not safe; clean coderefs
      return $self->_setting(@_);
  }
}

=head2 fallback_setting()

  $value = $browser->setting(gene => 'fgcolor');

Tries to find the setting for designated label (e.g. "gene") first. If
this fails, looks in [TRACK DEFAULTS]. If this fails, looks in [GENERAL].

=cut

sub fallback_setting {
  my $self = shift;
  my ($label,$option) = @_;
  for my $key ($label,'TRACK DEFAULTS','GENERAL') {
    my $value = $self->setting($key,$option);
    return $value if defined $value;
  }
  return;
}


# return configuration information
# arguments are ($type) => returns tags for type
#               ($type=>$tag) => returns values of tag on type
#               ($type=>$tag,$value) => sets value of tag
sub _setting {
  my $self = shift;
  my $config = $self->{config} or return;
  return keys %{$config} unless @_;
  return keys %{$config->{$_[0]}}        if @_ == 1;
  return $config->{$_[0]}{$_[1]}         if @_ == 2 && defined $_[0] && exists $config->{$_[0]};
  return $config->{$_[0]}{$_[1]} = $_[2] if @_ > 2;
  return;
}


=over 4

=item $value = $features-E<gt>code_setting($stanza=E<gt>$option);

This works like setting() except that it is also able to evaluate code
references.  These are options whose values begin with the characters
"sub {".  In this case the value will be passed to an eval() and the
resulting codereference returned.  Use this with care!

=back

=cut

sub code_setting {
  my $self = shift;
  my $section = shift;
  my $option  = shift;
  croak 'Cannot call code_setting unless feature file is marked as safe'
      unless $self->safe;

  my $setting = $self->_setting($section=>$option);
  return unless defined $setting;
  return $setting if ref($setting) eq 'CODE';
  if ($setting =~ /^\\&(\w+)/) {  # coderef in string form
    my $subroutine_name = $1;
    my $package         = $self->base2package;
    my $codestring      = "\\&${package}\:\:${subroutine_name}";
    my $coderef         = eval $codestring;
    $self->_callback_complain($section,$option) if $@;
    $self->set($section,$option,$coderef);
    $self->set_callback_source($section,$option,$setting);
    return $coderef;
  }
  elsif ($setting =~ /^sub\s*(\(\$\$\))*\s*\{/) {
    my $package         = $self->base2package;
    my $coderef         = eval "package $package; $setting";
    $self->_callback_complain($section,$option) if $@;
    $self->set($section,$option,$coderef);
    $self->set_callback_source($section,$option,$setting);
    return $coderef;
  } else {
    return $setting;
  }
}

sub _callback_complain {
  my $self    = shift;
  my ($section,$option) = @_;
  carp "An error occurred while evaluating the callback at section='$section', option='$option':\n   => $@";
}

=over 4

=item $value = $features-E<gt>safe_setting($stanza=E<gt>$option);

This works like code_setting() except that it evaluates anonymous code
references in a "Safe::World" compartment. This depends on the
L<Safe::World> module being installed and the -safe_world option being
set to true during object construction.

=back

=cut

sub safe_setting {
    my $self    = shift;

    my $section = shift;
    my $option  = shift;

    my $setting = $self->_setting($section=>$option);
    return unless defined $setting;
    return $setting if ref($setting) eq 'CODE';

    if ($setting =~ /^sub\s*(\(\$\$\))*\s*\{/ 
	&& (my $context = $self->{safe_context})) {


	# turn setting from an anonymous sub into a named
	# sub in the context namespace

	# create proper symbol name
	my $subname = "${section}_${option}";
	$subname    =~ tr/a-zA-Z0-9_//cd;
	$subname    =~ s/^\d+//;

	my ($prototype) 
	    = $setting =~ /^sub\s*\(\$\$\)/;

	$setting    =~ s/^sub?.*?\{/sub $subname {/;

	my $success = $context->eval("$setting; 1");
	$self->_callback_complain($section,$option) if $@;
	unless ($success) {
	    $self->set($section,$option,1);  # if call fails, it becomes a generic "true" value
	    return 1;
	}

	my $coderef = $prototype 
	    ?  sub ($$) { return $context->call($subname,$_[0],$_[1]) }
	    :  sub {
		if ($_[-1]->isa('Bio::Graphics::Glyph')) {
		    my %newglyph = %{$_[-1]};
		    $_[-1]       = bless \%newglyph,'Bio::Graphics::Glyph'; # make generic
		}
		$context->call($subname,@_);
	    };
	$self->set($section,$option,$coderef);
	$self->set_callback_source($section,$option,$setting);
	return $coderef;
    }
    else {
	return $setting;
    }
}

=over 4

=item $flag = $features-E<gt>safe([$flag]);

This gets or sets and "safe" flag.  If the safe flag is set, then
calls to setting() will invoke code_setting(), allowing values that
begin with the string "sub {" to be interpreted as anonymous
subroutines.  This is a potential security risk when used with
untrusted files of features, so use it with care.

=back

=cut

sub safe {
   my $self = shift;
   my $d = $self->{safe};
   $self->{safe} = shift if @_;
   $self->evaluate_coderefs if $self->{safe} && !$d;
   $d;
}

=over 4

=item $flag = $features-E<gt>safe_world([$flag]);

This gets or sets and "safe_world" flag.  If the safe_world flag is
set, then values that begin with the string "sub {" will be evaluated
in a "safe" compartment that gives minimal access to the system. This
is not a panacea for security risks, so use with care.

=back

=cut

sub safe_world {
    my $self            = shift;
    my $safe            = shift;

    if ($safe && !$self->{safe_content}) {  # initialise the thing

	eval "require Safe::World; 1";
	unless (Safe::World->can('new')) {
	    warn "The Safe::World module is not installed on this system. Can't use it to evaluate codesubs in a safe context";
	    return;
	}
	
	unless ($self->{safe_lib}) {
	    $self->{safe_lib} = Safe::World->new(sharepack => ['Bio::DB::SeqFeature',
							       'Bio::Graphics::Feature',
							       'Bio::SeqFeature::Lite',
							       'Bio::Graphics::Glyph',
						 ])  or return;

	    $self->{safe_lib}->eval(<<END)           or return;
use Bio::DB::SeqFeature;
use Bio::Graphics::Feature;
use Bio::SeqFeature::Lite;
use Bio::Graphics::Glyph; 
1;
END
	}

	$self->{safe_context} = Safe::World->new(root => $self->base2package)        or return;
	$self->{safe_context}->op_permit_only(':default');
	$self->{safe_context}->link_world($self->{safe_lib});
	$self->{safe_world} = $safe;
    }
    return $self->{safe_world};
}

=over 4

=item $features-E<gt>set_callback_source($type,$tag,$value)

=item $features-E<gt>get_callback_source($type,$tag)

These routines are used internally to get and set the source of a sub
{} callback.

=back

=cut

sub set_callback_source {
    my $self = shift;
    my ($type,$tag,$value) = @_;
    $self->{source}{$type}{lc $tag} = $value;
}

sub get_callback_source {
    my $self = shift;
    my ($type,$tag) = @_;
    $self->{source}{$type}{lc $tag};
}

=over 4

=item @args = $features-E<gt>style($type)

Given a feature type, returns a list of track configuration arguments
suitable for suitable for passing to the
Bio::Graphics::Panel-E<gt>add_track() method.

=back

=cut

# turn configuration into a set of -name=>value pairs suitable for add_track()
sub style {
  my $self = shift;
  my $type = shift;

  my $config  = $self->{config}  or return;
  my $hashref = $config->{$type};
  unless ($hashref) {
    $type =~ s/:.+$//;
    $hashref = $config->{$type} or return;
  }

  return map {("-$_" => $hashref->{$_})} keys %$hashref;
}


=over 4

=item $glyph = $features-E<gt>glyph($type);

Return the name of the glyph corresponding to the given type (same as
$features-E<gt>setting($type=E<gt>'glyph')).

=back

=cut

# retrieve just the glyph part of the configuration
sub glyph {
  my $self = shift;
  my $type = shift;
  my $config  = $self->{config}  or return;
  my $hashref = $config->{$type} or return;
  return $hashref->{glyph};
}


=over 4

=item @types = $features-E<gt>configured_types()

Return a list of all the feature types currently known to the feature
file set.  Roughly equivalent to:

  @types = grep {$_ ne 'general'} $features->setting;

=back

=cut

# return list of configured types, in proper order
sub configured_types {
  my $self = shift;
  my $types = $self->{types} or return;
  return @$types;
}

sub labels {
    return shift->configured_types;
}

=over 4

=item  @types = $features-E<gt>types()

This is similar to the previous method, but will return *all* feature
types, including those that are not configured with a stanza.

=back

=cut

sub types {
  my $self = shift;
  return $self->db->types;
}

=over 4

=item $features = $features-E<gt>features($type)

Return a list of all the feature types of type "$type".  If the
featurefile object was created by parsing a file or text scalar, then
the features will be of type Bio::Graphics::Feature (which follow the
Bio::FeatureI interface).  Otherwise the list will contain objects of
whatever type you added with calls to add_feature().

Two APIs:

  1) original API:

      # Reference to an array of all features of type "$type"
      $features = $features-E<gt>features($type)

      # Reference to an array of all features of all types
      $features = $features-E<gt>features()

      # A list when called in a list context
      @features = $features-E<gt>features()

   2) Bio::Das::SegmentI API:

       @features = $features-E<gt>features(-type=>['list','of','types']);

       # variants
       $features = $features-E<gt>features(-type=>['list','of','types']);
       $features = $features-E<gt>features(-type=>'a type');
       $iterator = $features-E<gt>features(-type=>'a type',-iterator=>1);

       $iterator = $features-E<gt>features(-type=>'a type',-seq_id=>$id,-start=>$start,-end=>$end);

=back

=cut

# return features
sub features {
  my $self = shift;
  my ($types,$iterator,$seq_id,$start,$end,@rest) = defined($_[0] && $_[0]=~/^-/)
    ? rearrange([['TYPE','TYPES'],'ITERATOR','SEQ_ID','START','END'],@_) : (\@_);

  $types = [$types] if $types && !ref($types);
  my @args     = $types && @$types ? (-type=>$types) : ();

  push @args,(-seq_id => $seq_id) if $seq_id;
  push @args,(-start  => $start)  if defined $start;
  push @args,(-end    => $end)    if defined $end;

  my $db = $self->db;

  if ($iterator) {
      return $db->get_seq_stream(@args);
  } else {
      my @f = $db->features(@args);
      return wantarray ?  @f : \@f;
  }
}



=over 4

=item @features = $features-E<gt>features($type)

Return a list of all the feature types of type "$type".  If the
featurefile object was created by parsing a file or text scalar, then
the features will be of type Bio::Graphics::Feature (which follow the
Bio::FeatureI interface).  Otherwise the list will contain objects of
whatever type you added with calls to add_feature().

=back

=cut

sub make_strand {
  local $^W = 0;
  return +1 if $_[0] =~ /^\+/ || $_[0] > 0;
  return -1 if $_[0] =~ /^\-/ || $_[0] < 0;
  return 0;
}

=head2 get_seq_stream

 Title   : get_seq_stream
 Usage   : $stream = $s->get_seq_stream(@args)
 Function: get a stream of features that overlap this segment
 Returns : a Bio::SeqIO::Stream-compliant stream
 Args    : see below
 Status  : Public

This is the same as feature_stream(), and is provided for Bioperl
compatibility.  Use like this:

 $stream = $s->get_seq_stream('exon');
 while (my $exon = $stream->next_seq) {
    print $exon->start,"\n";
 }

=cut

sub get_seq_stream {
  my $self = shift;
  local $^W = 0;
  my @args = $_[0] =~ /^-/ ? (@_,-iterator=>1) : (-types=>\@_,-iterator=>1);
  $self->features(@args);
}

=head2 get_feature_by_name

 Usage   : $db->get_feature_by_name(-name => $name)
 Function: fetch features by their name
 Returns : a list of Bio::DB::GFF::Feature objects
 Args    : the name of the desired feature
 Status  : public

This method can be used to fetch a named feature from the file.

The full syntax is as follows.  Features can be filtered by
their reference, start and end positions

  @f = $db->get_feature_by_name(-name  => $name,
                                -ref   => $sequence_name,
                                -start => $start,
                                -end   => $end);

This method may return zero, one, or several Bio::Graphics::Feature
objects.

=cut

sub get_feature_by_name {
   my $self = shift;
   my ($name,$ref,$start,$end) = rearrange(['NAME','REF','START','END'],@_);
   my @args;
   push @args,(-name   => $name) if defined $name;
   push @args,(-seq_id => $ref)  if defined $ref;
   push @args,(-start  => $start)if defined $start;
   push @args,(-end    => $end)  if defined $end;
   return $self->db->features(@args);
}

sub get_features_by_name { shift->get_feature_by_name(@_) }

=head2 search_notes

 Title   : search_notes
 Usage   : @search_results = $db->search_notes("full text search string",$limit)
 Function: Search the notes for a text string
 Returns : array of results
 Args    : full text search string, and an optional row limit
 Status  : public

Each row of the returned array is a arrayref containing the following fields:

  column 1     Display name of the feature
  column 2     The text of the note
  column 3     A relevance score.

=cut

sub search_notes {
  my $self = shift;
  return $self->db->search_notes(@_);
}


=head2 get_feature_stream(), top_SeqFeatures(), all_SeqFeatures()

Provided for compatibility with older BioPerl and/or Bio::DB::GFF
APIs.

=cut

*get_feature_stream = \&get_seq_stream;
*top_SeqFeatures    = *all_SeqFeatures = \&features;


=over 4

=item @refs = $features-E<gt>refs

Return the list of reference sequences referred to by this data file.

=back

=cut

sub refs {
  my $self = shift;
  my $refs = $self->{refs} or return;
  keys %$refs;
}

=over 4

=item  $min = $features-E<gt>min

Return the minimum coordinate of the leftmost feature in the data set.

=back

=cut

sub min { 
    my $self = shift;
    $self->_min_max();
    $self->{min};
}

=over 4

=item $max = $features-E<gt>max

Return the maximum coordinate of the rightmost feature in the data set.

=back

=cut

sub max {
    my $self = shift;
    $self->_min_max();
    $self->{max};
}

sub _min_max {
    my $self = shift;
    return if defined $self->{min} and defined $self->{max};

    my ($min,$max);
    if (my $bases = $self->setting(general=>'bases')) {
	($min,$max)        = $bases =~ /^(-?\d+)(?:\.\.|-)(-?\d+)/;
    }

    if (!defined $min) {
	# otherwise sort through the features
	my $fs = $self->get_seq_stream;
	while (my $f = $fs->next_seq) {
	    $min = $f->start if !defined $min or $min > $f->start;
	    $max = $f->end   if !defined $max or $max < $f->start;
	}
    }

    @{$self}{'min','max'} = ($min,$max);
}

sub init_parse {
  my $s = shift;

  $s->{max}          = $s->{min} = undef;
  $s->{types}        = [];
  $s->{features}     = {};
  $s->{config}       = {};
  $s->{loader}       = undef;
  $s->{state}        = 'config';
  $s->{feature_count}= 0; 
}

sub finish_parse {
  my $s = shift;
  if ($s->safe) {
      $s->initialize_code;
      $s->evaluate_coderefs;
  } 
  elsif ($s->safe_world) {
      $s->evaluate_safecoderefs;
  }
  $s->{loader}->finish_load() if $s->{loader};
  $s->{loader}       = undef;
  $s->{state}        = 'config';
}

sub evaluate_coderefs {
  my $self = shift;
  for my $s ($self->_setting) {
    for my $o ($self->_setting($s)) {
      $self->code_setting($s,$o);
    }
  }
}
sub evaluate_safecoderefs {
  my $self = shift;
  for my $s ($self->_setting) {
    for my $o ($self->_setting($s)) {
      $self->safe_setting($s,$o);
    }
  }
}

sub clean_code {
  my $self = shift;
  for my $s ($self->_setting) {
    for my $o ($self->_setting($s)) {
	$self->_setting($s,$o,1) if
	    $self->_setting($s,$o) =~ /\Asub\s*{/;
    }
  }
}

sub initialize_code {
  my $self       = shift;
  my $package    = $self->base2package;
  my $init_code  = $self->_setting(general => 'init_code') or return;
  my $code       = "package $package; $init_code; 1;";
  eval $code;
  $self->_callback_complain(general=>'init_code') if $@;
}

sub base2package {
  my $self = shift;
  return $self->{base2package} if exists $self->{base2package};
  my $rand     = int rand(1000000);
  return $self->{base2package} = "Bio::Graphics::FeatureFile::CallBack::P$rand";
}

sub split_group {
  my $self = shift;
  my $gff = $self->{gff} ||= Bio::DB::GFF->new(-adaptor=>'memory');
  return $gff->split_group(shift, $self->{gff_version} > 2);
}

# create a panel if needed
sub new_panel {
  my $self    = shift;
  my $options = shift;

  eval "require Bio::Graphics::Panel" unless Bio::Graphics::Panel->can('new');

  # general configuration of the image here
  my $width         = $self->setting(general => 'pixels')
                      || $self->setting(general => 'width')
			|| WIDTH;

  my ($start,$stop);
  my $range_expr = '(-?\d+)(?:-|\.\.)(-?\d+)';

  if (my $bases = $self->setting(general => 'bases')) {
    ($start,$stop) =  $bases =~ /([\d-]+)(?:-|\.\.)([\d-]+)/;
  }

  if (!defined $start || !defined $stop) {
    $start = $self->min unless defined $start;
    $stop  = $self->max unless defined $stop;
  }

  my $new_segment   = Bio::Graphics::Feature->new(-start=>$start,-stop=>$stop);
  my @panel_options = %$options if $options && ref $options eq 'HASH';
  my $panel = Bio::Graphics::Panel->new(-segment   => $new_segment,
					-width     => $width,
					-key_style => 'between',
					$self->style('general'),
					@panel_options
      );
  $panel;
}

=over 4

=item $mtime = $features-E<gt>mtime

=item $atime = $features-E<gt>atime

=item $ctime = $features-E<gt>ctime

=item $size = $features-E<gt>size

Returns stat() information about the data file, for featurefile
objects created using the -file option.  Size is in bytes.  mtime,
atime, and ctime are in seconds since the epoch.

=back

=cut

sub mtime {
  my $self = shift;
  my $d = $self->{m_time} || $self->{stat}->[9];
  $self->{m_time} = shift if @_;
  $d;
}
sub atime { shift->{stat}->[8];  }
sub ctime { shift->{stat}->[10]; }
sub size  { shift->{stat}->[7];  }

=over 4

=item $label = $features-E<gt>feature2label($feature)

Given a feature, determines the configuration stanza that bests
describes it.  Uses the feature's type() method if it has it (DasI
interface) or its primary_tag() method otherwise.

=back

=cut

sub feature2label {
  my $self    = shift;
  my $feature = shift;
  my $type      = $feature->can('type') ? $feature->type 
                                        : $feature->primary_tag;
  $type or return;
  (my $basetype = $type) =~ s/:.+$//;
  my @labels    = $self->type2label($type);
  @labels       = $self->type2label($basetype) unless @labels;
  @labels       = ($type) unless @labels;
  wantarray ? @labels : $labels[0];
}

=over 4

=item $link = $features-E<gt>link_pattern($linkrule,$feature,$panel)

Given a feature, tries to generate a URL to link out from it.  This
uses the 'link' option, if one is present.  This method is a
convenience for the generic genome browser.

=back

=cut

sub link_pattern {
  my $self     = shift;
  my ($linkrule,$feature,$panel,$dont_escape) = @_;

  $panel ||= 'Bio::Graphics::Panel';

  if (ref($linkrule) && ref($linkrule) eq 'CODE') {
    my $val = eval {$linkrule->($feature,$panel)};
    $self->_callback_complain(none=>"linkrule for $feature") if $@;
    return $val;
  }

  require CGI unless defined &CGI::escape;
  my $escape_method = $dont_escape ? sub {shift} : \&CGI::escape;

  my $n;
  $linkrule ||= ''; # prevent uninit warning
  my $seq_id  = $feature->can('seq_id') ? $feature->seq_id() : $feature->location->seq_id();
  $seq_id   ||= $feature->seq_id; #fallback
  $linkrule =~ s!\$(\w+)!
    $escape_method->(
    $1 eq 'ref'              ? (($n = $seq_id) && "$n") || ''
      : $1 eq 'name'         ? (($n = $feature->display_name) && "$n")     || ''
      : $1 eq 'class'        ? eval {$feature->class}  || ''
      : $1 eq 'type'         ? eval {$feature->method} || $feature->primary_tag || ''
      : $1 eq 'method'       ? eval {$feature->method} || $feature->primary_tag || ''
      : $1 eq 'source'       ? eval {$feature->source} || $feature->source_tag  || ''
      : $1 =~ 'seq_?id'      ? eval{$feature->seq_id} || eval{$feature->location->seq_id} || ''
      : $1 eq 'start'        ? $feature->start || ''
      : $1 eq 'end'          ? $feature->end   || ''
      : $1 eq 'stop'         ? $feature->end   || ''
      : $1 eq 'segstart'     ? $panel->start   || ''
      : $1 eq 'segend'       ? $panel->end     || ''
      : $1 eq 'length'       ? $feature->length || 0
      : $1 eq 'description'  ? eval {join '',$feature->notes} || ''
      : $1 eq 'id'           ? eval {$feature->feature_id} || eval {$feature->primary_id} || ''
      : '$'.$1
       )
	!exg;
  return $linkrule;
}

sub make_link {
  my $self             = shift;
  my ($feature,$panel) = @_;

  my ($linkrule) = $feature->each_tag_value('link');

  unless ($linkrule) {
      for my $label ($self->feature2label($feature)) {
	  $linkrule     ||= $self->setting($label,'link');
	  $linkrule     ||= $self->setting(general=>'link');
      }
  }
  return $self->link_pattern($linkrule,$feature,$panel);
}

sub make_title {
  my $self    = shift;
  my $feature = shift;

  for my $label ($self->feature2label($feature)) {
    my $linkrule     = $self->setting($label,'title');
    $linkrule      ||= $self->setting(general=>'title');
    next unless $linkrule;
    return $self->link_pattern($linkrule,$feature,undef,1);
  }

  my $method  = eval {$feature->method} || $feature->primary_tag;
  my $seqid   = $feature->can('seq_id')  ? $feature->seq_id : $feature->location->seq_id;
  my $title = eval {
    if ($feature->can('target') && (my $target = $feature->target)) {
      join (' ',
	    $method,
	    (defined $seqid ? "$seqid:" : '').
	    $feature->start."..".$feature->end,
	    $feature->target.':'.
	    $feature->target->start."..".$feature->target->end);
    } else {
      join(' ',
	   $method,
	   $feature->can('display_name') ? $feature->display_name : $feature->info,
	   (defined $seqid ? "$seqid:" : '').
	   ($feature->start||'?')."..".($feature->end||'?')
	  );
    }
  };
  warn $@ if $@;
  $title;
}

# given a feature type, return its label(s)
sub type2label {
  my $self = shift;
  my $type = shift;
  $self->{_type2label} ||= $self->invert_types;
  my @labels = keys %{$self->{_type2label}{lc $type}};
  wantarray ? @labels : $labels[0]
}

sub invert_types {
  my $self = shift;
  my $config  = $self->{config} or return;
  my %inverted;
  for my $label (keys %{$config}) {
      my $feature = $config->{$label}{feature} || $label;
      foreach (shellwords($feature||'')) {
	  $inverted{lc $_}{$label}++;
      }
  }
  \%inverted;
}

=over 4

=item $citation = $features-E<gt>citation($feature)

Given a feature, tries to generate a citation for it, using the
"citation" option if one is present.  This method is a convenience for
the generic genome browser.

=back

=cut

# This routine returns the "citation" field.  It is here in order to simplify the logic
# a bit in the generic browser
sub citation {
  my $self = shift;
  my $feature = shift || 'general';
  return $self->setting($feature=>'citation');
}

=over 4

=item $name = $features-E<gt>name([$feature])

Get/set the name of this feature set.  This is a convenience method
useful for keeping track of multiple feature sets.

=back

=cut

# give this feature file a nickname
sub name {
  my $self = shift;
  my $d = $self->{name};
  $self->{name} = shift if @_;
  $d;
}

1;

__END__

=head1 Appendix -- Sample Feature File

 # file begins
 [general]
 pixels = 1024
 bases = 1-20000
 reference = Contig41
 height = 12

 [mRNA]
 glyph = gene
 key   = Spliced genes

 [Cosmid]
 glyph = segments
 fgcolor = blue
 key = C. elegans conserved regions

 [EST]
 glyph = segments
 bgcolor= yellow
 connector = dashed
 height = 5;

 [FGENESH]
 glyph = transcript2
 bgcolor = green
 description = 1

 mRNA B0511.1 Chr1:1..100 Type=UTR;Note="putative primase"
 mRNA B0511.1 Chr1:101..200,300..400,500..800 Type=CDS
 mRNA B0511.1 Chr1:801..1000 Type=UTR

 reference = Chr3
 Cosmid	B0511	516..619
 Cosmid	B0511	3185..3294
 Cosmid	B0511	10946..11208
 Cosmid	B0511	13126..13511
 Cosmid	B0511	11394..11539
 EST	yk260e10.5	15569..15724
 EST	yk672a12.5	537..618,3187..3294
 EST	yk595e6.5	552..618
 EST	yk595e6.5	3187..3294
 EST	yk846e07.3	11015..11208
 EST	yk53c10
 	yk53c10.3	15000..15500,15700..15800
 	yk53c10.5	18892..19154
 EST	yk53c10.5	16032..16105
 SwissProt	PECANEX	13153-13656	Note="Swedish fish"
 FGENESH	"Predicted gene 1"	1-205,518-616,661-735,3187-3365,3436-3846	"Pfam domain"
 # file ends

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Glyph>,
L<Bio::DB::SeqFeature::Store::FeatureFileLoader>,
L<Bio::Graphics::Feature>,
L<Bio::Graphics::FeatureFile>

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut



