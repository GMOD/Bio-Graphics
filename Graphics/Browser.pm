package Bio::Graphics::Browser;
# $Id: Browser.pm,v 1.11 2001-12-21 15:52:25 lstein Exp $

use strict;
use File::Basename 'basename';
use Carp 'carp';
use GD 'gdMediumBoldFont';

use constant DEFAULT_WIDTH => 800;
use vars '$VERSION';
$VERSION = '1.00';

sub new {
  my $class    = shift;
  my $conf_dir = shift;
  my $self = bless { },$class;
  $self->{conf}  = $self->read_configuration($conf_dir);
  $self->{width} = DEFAULT_WIDTH;
  $self;
}

sub sources {
  my $self = shift;
  my $conf = $self->{conf} or return;
  return keys %$conf;
}

# get/set current source (not sure if this is wanted)
sub source {
  my $self = shift;
  my $d = $self->{source};
  if (@_) {
    my $source = shift;
    unless ($self->{conf}{$source}) {
      carp("invalid source: $source");
      return $d;
    }
    $self->{source} = $source;
  }
  $d;
}

sub setting {
  my $self = shift;
  $self->config->setting('general',@_);
}

sub description {
  my $self = shift;
  my $source = shift;
  my $c = $self->{conf}{$source} or return;
  return $c->setting('general','description');
}

sub config {
  my $self = shift;
  my $source = $self->source;
  $self->{conf}{$source};
}

sub default_labels {
  my $self = shift;
  $self->config->default_labels;
}

sub default_label_indexes {
  my $self = shift;
  $self->config->default_label_indexes;
}

sub feature2label {
  my $self = shift;
  my $feature = shift;
  return $self->config->feature2label($feature);
}

sub make_link {
  my $self = shift;
  my $feature = shift;
  return $self->config->make_link($feature);
}

sub labels {
  my $self = shift;
  my $order = shift;
  my @labels = $self->config->labels;
  if ($order) { # custom order
    return @labels[@$order];
  } else {
    return @labels;
  }
}

sub width {
  my $self = shift;
  my $d = $self->{width};
  $self->{width} = shift if @_;
  $d;
}

# Generate the image and the box list, and return as a two-element list.
# arguments:
# $segment       A feature iterator that responds to next_feature() methods
# $feature_files A list of Bio::Graphics::FeatureFile objects containing 3d party features
# $show          An array of booleans indicating which labels should be shown
# $options       An array of options, where 0=auto, 1=force bump, 2=force label
# $order         An array of label indexes indicating order of tracks
sub image_and_map {
  my $self = shift;
  my ($segment,$feature_files,$show,$order,$options) = @_;

  my @labels = $self->labels;

  my $width = $self->width;
  my $conf  = $self->config;
  my $max_labels = $conf->setting(general=>'label density') || 10;
  my $max_bump   = $conf->setting(general=>'bump density')  || 50;

  my @feature_types = map {$conf->label2type($labels[$_])} grep {$show->[$_]} (0..@labels-1);

  # Create the tracks that we will need
  my $panel = Bio::Graphics::Panel->new(-segment => $segment,
					-width   => $width,
					-keycolor => 'moccasin',
					-grid => 1,
				       );
  $panel->add_track($segment   => 'arrow',
		    -double => 1,
		    -tick=>2,
		   );

  my (%tracks,%options,@blank_tracks);
  $order ||= [0..$self->labels-1];

  for (my $i = 0; $i < @$order; $i++) {
    my $l        = $order->[$i];
    my $label    = $labels[$l];

    # skip this if it isn't in the @$show array
    next unless $show->[$l];
    # if we don't have a configured label, then it is a third party annotation
    unless ($label) {
      push @blank_tracks,$i;
      next;
    }

    my $track = $panel->add_track(-glyph => 'generic',
				  -key   => $label,
				  $conf->style($label),
				 );
    $tracks{$label}  = $track;
    $options{$label} = $options->[$l];
  }

  if (@feature_types) {  # don't do anything unless we have features to fetch!
    my $iterator = $segment->features(-type=>\@feature_types,-iterator=>1);
    my (%similarity,%feature_count);

    while (my $feature = $iterator->next_feature) {

      my $label = $self->feature2label($feature);
      my $track = $tracks{$label} or next;

      $feature_count{$label}++;

      # special case to handle paired EST reads
      if ($feature->method =~ /^(similarity|alignment)$/) {
	push @{$similarity{$label}},$feature;
	next;
      }
      $track->add_feature($feature);
    }

    # handle the similarities as a special case
    for my $label (keys %similarity) {
      my $set = $similarity{$label};
      my %pairs;
      for my $a (@$set) {
	(my $base = $a->name) =~ s/\.[fr35]$//i;
	push @{$pairs{$base}},$a;
      }
      my $track = $tracks{$label};
      foreach (values %pairs) {
	$track->add_group($_);
      }
    }

    # configure the tracks based on their counts
    for my $label (keys %tracks) {
      next unless $feature_count{$label};
      $options{$label} ||= 0;
      my $do_bump  = $options{$label} >= 1 || $feature_count{$label} <= $max_bump;
      my $do_label = $options{$label} >= 2 || $feature_count{$label} <= $max_labels;
      $tracks{$label}->configure(-bump  => $do_bump,
				 -label => $do_label,
				 -description => $do_label && $tracks{$label}->option('description'),
				);
    }
  }

  # add additional features, if any
  $feature_files ||= [];
  my $offset = 0;
  for my $track (@blank_tracks) {
    my $feature = $order->[$track];

    # Implicitly, the third party features begin at the end of our internal
    # feature label list.
    my $file    = $feature_files->[$feature - @labels] or next;
    $track += $offset + 1;
    my $inserted = $file->render($panel,$track,$options->[$feature]);
    $offset += $inserted;
  }

  my $boxes    = $panel->boxes;
  my $gd       = $panel->gd;
  return ($gd,$boxes);
}

# generate the overview, if requested, and return it as a GD
sub overview {
  my $self = shift;
  my ($partial_segment) = @_;

  my $segment = $partial_segment->factory->segment($partial_segment->ref);

  my $conf  = $self->config;
  my $width = $self->width;
  my $panel = Bio::Graphics::Panel->new(-segment => $segment,
					-width   => $width,
					-bgcolor => $self->setting('overview bgcolor') || 'wheat',
				       );
  $panel->add_track($segment   => 'arrow',
		    -double    => 1,
		    -label     => sub {"Overview of ".$segment->ref},
		    -labelfont => gdMediumBoldFont,
		    -units     => $self->setting('overview units') || 'M',
		    -tick      => 2,
		   );
  if (my $landmarks  = $self->setting('overview landmarks') || ($conf->label2type('overview'))[0]) {
    my $max_bump   = $conf->setting(general=>'bump density') || 50;

    my @types = split /\s+/,$landmarks;
    my $track = $panel->add_track(-glyph  => 'generic',
				  -height  => 3,
				  -fgcolor => 'black',
				  -bgcolor => 'black',
				  $conf->style('overview'),
				 );
    my $iterator = $segment->features(-type=>\@types,-iterator=>1,-rare=>1);
    my $count;
    while (my $feature = $iterator->next_feature) {
      $track->add_feature($feature);
      $count++;
    }
    $track->configure(-bump  => $count <= $max_bump,
		      -label => $count <= $max_bump
		     );
  }

  my $gd = $panel->gd;
  my $red = $gd->colorClosest(255,0,0);
  my ($x1,$x2) = $panel->map_pt($partial_segment->start,$partial_segment->end);
  my ($y1,$y2) = (0,$panel->height-1);
  $x1 = $x2 if $x2-$x1 <= 1;
  $x2 = $panel->right-1 if $x2 >= $panel->right;
  $gd->rectangle($x1,$y1,$x2,$y2,$red);

  return ($gd,$segment->length);
}

sub read_configuration {
  my $self = shift;
  my $conf_dir = shift;
  die "$conf_dir: not a directory" unless -d $conf_dir;

  opendir(D,$conf_dir) or die "Couldn't open $conf_dir: $!";
  my @conf_files = map { "$conf_dir/$_" }readdir(D);
  close D;

  # try to work around a bug in Apache/mod_perl which appears when
  # running under linux/glibc 2.2.1
  unless (@conf_files) {
    @conf_files = glob("$conf_dir/*.conf");
  }

  my %config;
  foreach (sort {$b cmp $a} @conf_files) {
    next unless /\.conf$/;
    my $basename = basename($_,'.conf');
    my $config = Bio::Graphics::BrowserConfig->new(-file => $_) or next;
    $config{$basename} = $config;
    $self->{source} = $basename;
  }
  return \%config;
}

package Bio::Graphics::BrowserConfig;
use strict;
use Bio::Graphics::FeatureFile;
use Text::Shellwords;
use Carp 'croak';

use vars '@ISA';
@ISA = 'Bio::Graphics::FeatureFile';

sub labels {
  grep { $_ ne 'overview' } shift->configured_types;
}

sub label2type {
  my $self = shift;
  my $label = shift or return;
  return shellwords($self->setting($label,'feature'));
}

sub label2index {
  my $self = shift;
  my $label = shift;
  unless ($self->{label2index}) {
    my $index = 0;
    $self->{label2index} = { map {$_=>$index++} $self->labels };
  }
  return $self->{label2index}{$label};
}

sub invert_types {
  my $self = shift;
  my $config  = $self->{config} or return;
  my %inverted;
  for my $label (keys %{$config}) {
    next if $label eq 'overview';   # special case
    my $feature = $config->{$label}{feature} or next;
    foreach (shellwords($feature)) {
      $inverted{$_} = $label;
    }
  }
  \%inverted;
}

sub default_labels {
  my $self = shift;
  my $defaults = $self->setting('general'=>'default features');
  return shellwords($defaults);
}

sub default_label_indexes {
  my $self = shift;
  my @labels = $self->default_labels;
  return map {$self->label2index($_)} @labels;
}

# return a hashref in which keys are the thresholds, and values are the list of
# labels that should be displayed
sub summary_mode {
  my $self = shift;
  my $summary = $self->settings(general=>'summary mode') or return {};
  my %pairs = $summary =~ /(\d+)\s+{([^\}]+?)}/g;
  foreach (keys %pairs) {
    my @l = shellwords($pairs{$_});
    $pairs{$_} = \@l
  }
  \%pairs;
}

# override get_linkrule to allow for code references
sub get_linkrule {
  my $self = shift;
  my $label = shift;

  unless (exists $self->{_link}{$label}) {
    my $link = $self->{_link}{$label} = $self->label2link($label);
    if ($link =~ /^sub\s+\{/) { # a subroutine
      my $coderef = eval $link;
      warn $@ if $@;
      $self->{_link}{$label} = $coderef;
    }
  }

  return $self->{_link}{$label};
}

# override _link() method to allow code references
sub _link {
  my $self     = shift;
  my ($feature,$link) = @_;
  if (ref $link eq 'CODE') {
    return $link->($feature);
  }

  else {
    $link =~ s/\$(\w+)/
      $1 eq 'name'   ? $feature->name
      : $1 eq 'class'  ? $feature->class
      : $1 eq 'method' ? $feature->method
      : $1 eq 'source' ? $feature->source
      : $1
       /exg;
    return $link;
  }
}

1;

__END__

THIS IS AN OLDER VERSION OF image_and_map() WHICH IS LESS PIPELINED
NOT SURE WHETHER IT IS ACTUALLY SLOWER THOUGH

# Generate the image and the box list, and return as a two-element list.
sub image_and_map {
  my $self = shift;
  my ($segment,$labels,$order) = @_;
  my %labels = map {$_=>1} @$labels;

  my $width = $self->width;
  my $conf  = $self->config;
  my $max_labels = $conf->setting(general=>'label density') || 10;
  my $max_bump   = $conf->setting(general=>'bump density')  || 50;
  my @feature_types = map {$conf->label2type($_)} @$labels;

  my $iterator = $segment->features(-type=>\@feature_types,
				    -iterator=>1);
  my ($similarity,$other) = $self->sort_features($iterator);

  my $panel = Bio::Graphics::Panel->new(-segment => $segment,
					-width   => $width,
					-keycolor => $self->setting('detailed bgcolor') || 'moccasin',
					-grid => 1,
				       );
  $panel->add_track($segment   => 'arrow',
		    -double => 1,
		    -bump =>1,
		    -tick=>2,
		   );

  # all the rest comes from configuration
  for my $label ($self->labels($order)) {  # use labels() method in order to preserve order in .conf file

    next unless $labels{$label};

    # handle similarities a bit differently
    if (my $set = $similarity->{$label}) {
      my %pairs;
      for my $a (@$set) {
	(my $base = $a->name) =~ s/\.[fr35]$//i;
	push @{$pairs{$base}},$a;
      }
      my $track = $panel->add_track(-glyph =>'segments',
				    -label => @$set <= $max_labels,
				    -bump  => @$set <= $max_bump,
				    -key   => $label,
				    $conf->style($label)
				   );
      foreach (values %pairs) {
	$track->add_group($_);
      }
      next;
    }

    if (my $set = $other->{$label}) {
      $panel->add_track($set,
			-glyph => 'generic',
			-label => @$set <= $max_labels,
			-bump  => @$set <= $max_bump,
			-key   => $label,
			$conf->style($label),

		       );
      next;
    }
  }

  my $boxes    = $panel->boxes;
  my $gd       = $panel->gd;
  return ($gd,$boxes);
}

sub sort_features {
  my $self     = shift;
  my $iterator = shift;

  my (%similarity,%other);
  while (my $feature = $iterator->next_feature) {

    my $label = $self->feature2label($feature);

    # special case to handle paired EST reads
    if ($feature->method =~ /^(similarity|alignment)$/) {
      push @{$similarity{$label}},$feature;
    }

    else {  #otherwise, just sort by label
      push @{$other{$label}},$feature;
    }
  }

  return (\%similarity,\%other);
}


