package Bio::Graphics::FeatureFile;
# $Id: FeatureFile.pm,v 1.1 2001-10-05 19:49:14 lstein Exp $

# This package parses and renders a simple tab-delimited format for features.
# It is simpler than GFF, but still has a lot of expressive power.

# Documentation is pending, but see __END__ for the file format, and eg/feature_draw.pl for an
# example of usage.

use strict;
use Bio::Graphics::Feature;
use Carp;
use IO::File;
use vars '$VERSION';
$VERSION = '1.00';

sub new {
  my $class = shift;
  my %args  = @_;
  my $self = bless { 
		    config   => {},
		    features => {},
		    groups   => {},
		    seenit   => {},
		    types    => [],
		    max      => undef,
		    min      => undef,
		   },$class;

  # call with
  #   -file
  #   -text
  my $fh;
  if (my $file = $args{-file}) {
    if (defined fileno($file)) {
      $fh = $file;
    } elsif ($file eq '-') {
      $self->parse_argv();
    } else {
      $fh = IO::File->new($file) or croak("Can't open $file: $!\n");
    }
    $self->parse_file($fh);
  } elsif (my $text = $args{-text}) {
    $self->parse_text($text);
  }

  $self;
}

sub error {
  my $self = shift;
  my $d = $self->{error};
  $self->{error} = shift if @_;
  $d;
}


sub parse_argv {
  my $self = shift;

  $self->init_parse;
  while (<>) {
    chomp;
    $self->parse_line($_);
  }
  $self->finish_parse;
}

sub parse_file {
  my $self = shift;
  my $fh = shift;

  $self->{seenit} = {};
  while (<$fh>) {
    chomp;
    $self->parse_line($_);
  }
  $self->consolidate_groups;
}

sub parse_text {
  my $self = shift;
  my $text = shift;

  $self->{seenit} = {};
  foreach (split /\r?\n/,$text) {
    $self->parse_line($_);
  }
  $self->consolidate_groups;
}

sub parse_line {
  my $self = shift;
  local $_ = shift;

  return if /^[\#]/;

  if (/^\s*\[([^\]]+)\]/) {  # beginning of a configuration section
     my $label = $1;
     my $cc = $label =~ /^(general|default)$/i ? 'general' : $label;  # normalize
     push @{$self->{types}},$cc unless $cc eq 'general';
     $self->{current_config} = $cc;
    next;
  }

  if (/^(\w+)\s*[=:]\s*(.+)/) {   # key value pair within a configuration section
    my $cc = $self->{current_config} ||= 'general';       # in case no configuration named
    $self->{config}{$cc}{lc $1} = $2;
    next;
  }

  if (/^$/) { # empty line
    undef $self->{current_config};
    next;
  }

  # parse data lines
  my @tokens = split "\t";

  # close any open group
  undef $self->{grouptype} if length $tokens[0] > 0;

  if (@tokens < 4) {      # short line; assume a group identifier
    $self->{grouptype}     = shift @tokens;
    $self->{groupname}     = shift @tokens;
    next;
  }

  my($type,$name,$strand,$bounds,$description) = @tokens;
  $type ||= $self->{grouptype};

  my @parts = map { [/([\d-]+)(?:-|\.\.)([\d-]+)/]} split /(?:,| )\s*/,$bounds;

  foreach (@parts) { # max and min calculation, sigh...
    $self->{min} = $_->[0] if !defined $self->{min} || $_->[0] < $self->{min};
    $self->{max} = $_->[1] if !defined $self->{max} || $_->[1] > $self->{max};
  }

  # either create a new feature or add a segment to it
  if (my $feature = $self->{seenit}{$type,$name}) {
    $feature->add_segment(@parts);
  } else {
    $feature = $self->{seenit}{$type,$name} = Bio::Graphics::Feature->new(-name     => $name,
									  -type     => $type,
									  -strand   => make_strand($strand),
									  -segments => \@parts,
									  -source => $description
									 );
    if ($self->{grouptype}) {
      push @{$self->{groups}{$self->{grouptype}}{$self->{groupname}}},$feature;
    } else {
      push @{$self->{features}{$type}},$feature;
    }
  }

  
}

# return configuration information
sub setting {
  my $self = shift;
  my $config = $self->{config} or return; 
  return keys %{$config} unless @_;
  return keys %{$config->{$_[0]}} if @_ == 1;
  return $config->{$_[0]}{$_[1]}  if @_ > 1;
}

# turn configuration into a set of -name=>value pairs suitable for add_track()
sub style {
  my $self = shift;
  my $type = shift;

  my $config  = $self->{config} or return; 
  my $hashref = $config->{$type} or return;

  return map {("-$_" => $hashref->{$_})} keys %$hashref;
}

# return list of configured types, in proper order
sub configured_types {
  my $self = shift;
  my $types = $self->{types} or return;
  return @{$types};
}

# return features
sub features {
  my $self = shift;
  return $self->{features}{shift()} if @_;
  return $self->{features};
}

sub types {
  my $self = shift;
  my $features = $self->{features} or return;
  return keys %{$features};
}


sub make_strand {
  return +1 if $_[0] =~ /^\+/ || $_[0] > 0;
  return -1 if $_[0] =~ /^\-/ || $_[0] < 0;
  return 0;
}

sub min { shift->{min} }
sub max { shift->{max} }

sub init_parse {
  my $s = shift;

  $s->{seenit} = {}; 
  $s->{max}      = $s->{min} = undef;
  $s->{types}    = [];
  $s->{groups}   = {};
  $s->{features} = {};
  $s->{config}   = {}
}

sub finish_parse {
  my $s = shift;
  $s->consolidate_groups;
  $s->{seenit} = {};
  $s->{groups} = {};
}

sub consolidate_groups {
  my $self = shift;
  my $groups = $self->{groups} or return;

  for my $type (keys %$groups) {
    my @groups = values %{$groups->{$type}};
    push @{$self->{features}{$type}},@groups;
  }
}

1;

__END__

=head1 NAME

Bio::Graphics::FeatureFile - Parse a simple feature file format into a form suitable for rendering

=head1 SYNOPSIS

This package parses and renders a simple tab-delimited format for features.
It is simpler than GFF, but still has a lot of expressive power.

Documentation is pending, but see the file format here, and eg/feature_draw.pl for an
example of usage.
 
 # file begins
 [general]
 pixels = 1024
 bases = 1-20000
 height = 12
 
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
 
 Cosmid	B0511	+	516-619
 Cosmid	B0511	+	3185-3294
 Cosmid	B0511	+	10946-11208
 Cosmid	B0511	+	13126-13511
 Cosmid	B0511	+	11394-11539
 Cosmid	B0511	+	14383-14490
 Cosmid	B0511	+	15569-15755
 Cosmid	B0511	+	18879-19178
 Cosmid	B0511	+	15850-16110
 Cosmid	B0511	+	66-208
 Cosmid	B0511	+	6354-6499
 Cosmid	B0511	+	13955-14115
 Cosmid	B0511	+	7985-8042
 Cosmid	B0511	+	11916-12046
 EST	yk260e10.5	+	15569-15724
 EST	yk672a12.5	+	537-618,3187-3294
 EST	yk595e6.5	+	552-618
 EST	yk595e6.5	+	3187-3294
 EST	yk846e07.3	+	11015-11208
 EST	yk53c10
 	yk53c10.3	+	15000-15500,15700-15800
 	yk53c10.5	+	18892-19154
 EST	yk53c10.5	+	16032-16105
 SwissProt	PECANEX	+	13153-13656	Swedish fish
 FGENESH	Predicted gene 1	-	1-205,518-616,661-735,3187-3365,3436-3846	Pfam domain
 FGENESH	Predicted gene 2	+	5513-6497,7968-8136,8278-8383,8651-8839,9462-9515,10032-10705,10949-11340,11387-11524,11765-12067,12876-13577,13882-14121,14169-14535,15006-15209,15259-15462,15513-15753,15853-16219	Mysterious
 FGENESH	Predicted gene 3	-	16626-17396,17451-17597
 FGENESH	Predicted gene 4	+	18459-18722,18882-19176,19221-19513,19572-19835	Transmembrane protein
 # file ends

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Glyph>,
L<Bio::Graphics::Feature>,
L<Bio::Graphics::FeatureFile>

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut



