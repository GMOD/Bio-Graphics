#!/usr/bin/perl

use strict;
use lib '..';
use Bio::Graphics::Panel;
use Bio::Graphics::Feature;

use constant WIDTH  => 600;  # default width
my @COLORS = qw(cyan blue red yellow green wheat turquoise orange);  # default colors
my $color = 0;      # position in color cycle

my %CONFIG;  # indexed by feature type
my @ORDER;   # order of features top to bottom

my $current_config;
my ($MAX,$MIN);
my (%features,%groups,%seenit,$grouptype,$groupname);

while (<>) {
  chomp;
  next if /^[\#]/;

  if (/^\s*\[([^\]]+)\]/) {  # beginning of a configuration section
    my $label = $1;
    $current_config = $label =~ /^(general|default)$/i ? 'general' : $label;  # normalize
    push @ORDER,$current_config unless $current_config eq 'general';
    next;
  }

  if (/^(\w+)\s*[=:]\s*(.+)/) {   # key value pair within a configuration section
    $current_config ||= 'general';       # in case no configuration named
    $CONFIG{$current_config}{lc $1} = $2;
    next;
  }

  if (/^$/) { # empty line
    undef $current_config;
    next;
  }

  # parse data lines
  my @tokens = split "\t";

  # close any open group
  undef $grouptype if length $tokens[0] > 0;

  if (@tokens < 4) {      # short line; assume a group identifier
    $grouptype     = shift @tokens;
    $groupname     = shift @tokens;
    next;
  }

  my($type,$name,$strand,$bounds,$description) = @tokens;
  $type ||= $grouptype;

  my @parts = map { [/([\d-]+)(?:-|\.\.)([\d-]+)/]} split /(?:,| )\s*/,$bounds;

  foreach (@parts) { # max and min calculation, sigh...
    $MIN = $_->[0] if !defined $MIN || $_->[0] < $MIN;
    $MAX = $_->[1] if !defined $MAX || $_->[1] > $MAX;
  }

  # either create a new feature or add a segment to it
  if (my $feature = $seenit{$type,$name}) {
    $feature->add_segment(@parts);
  } else {
    $feature = $seenit{$type,$name} = Bio::Graphics::Feature->new(-name     => $name,
								  -type     => $type,
								  -strand   => make_strand($strand),
								  -segments => \@parts,
								  -source => $description
								 );
    if ($grouptype) {
      push @{$groups{$grouptype}{$groupname}},$feature;
    } else {
      push @{$features{$type}},$feature;
    }
  }

}

1;

# consolidate groups onto features
for my $type (keys %groups) {
  my @groups = values %{$groups{$type}};
  push @{$features{$type}},@groups;
}
undef %groups;

# general configuration of the image here
my $width = $CONFIG{general}{pixels} || $CONFIG{general}{width} || WIDTH;
my ($start,$stop) = $CONFIG{general}{bases} =~ /([\d-]+)(?:-|\.\.)([\d-]+)/;
$start = $MIN unless defined $start;
$stop  = $MAX unless defined $stop;

# Use the order of the stylesheet to determine features.  Whatever is left
# over is presented in alphabetic order
my %types = map {$_=>1} @ORDER;
my @configured_types   = grep {exists $features{$_}} @ORDER;
my @unconfigured_types = sort grep {!exists $types{$_}} keys %features,keys %groups;

# create the segment,the panel and the arrow with tickmarks
my $segment = Bio::Graphics::Feature->new(-start=>$start,-stop=>$stop);
my $panel = Bio::Graphics::Panel->new(-segment   => $segment,
				      -width     => $width,
				      -key_style => 'between');
$panel->add_track($segment,-glyph=>'arrow',-tick=>2);

my @base_config = flatten($CONFIG{general});

for my $type (@configured_types,@unconfigured_types) {
  my @config = ( -glyph   => 'segments',         # really generic
		 -bgcolor => $COLORS[$color++ % @COLORS],
		 -label   => 1,
		 -key     => $type,
		 @base_config,             # global
		 flatten($CONFIG{$type}),  # feature-specificp
	       );
  my $features = $features{$type};
  $panel->add_track($features,@config);
}

print $panel->png;


sub make_strand {
  return +1 if $_[0] =~ /^\+/ || $_[0] > 0;
  return -1 if $_[0] =~ /^\-/ || $_[0] < 0;
  return 0;
}

sub flatten {
  my $hashref = shift;
  return unless $hashref;
  return map {("-$_" => $hashref->{$_})} keys %$hashref;
}
