package Bio::Graphics::Feature;
use strict;

use vars '$VERSION';
$VERSION = 1.1;

*end         = \&stop;
*info        = \&name;
*seqname     = \&name;
*primary_tag = \&type;
*exons       = *sub_SeqFeature = *merged_segments = \&segments;

# usage:
# Ace::Graphics::Feature->new(
#                         -start => 1,
#                         -end   => 100,
#                         -name  => 'fred feature',
#                         -strand => +1);
#
# Alternatively, use -segments => [ [start,stop],[start,stop]...]
# to create a multisegmented feature.
sub new {
  my $class= shift;
  $class = ref($class) if ref $class;
  my %arg = @_;

  my $self = bless {},$class;

  $arg{-strand} ||= 0;
  $self->{strand}  = $arg{-strand} >= 0 ? +1 : -1;
  $self->{name}    = $arg{-name};
  $self->{type}    = $arg{-type}   || 'feature';
  $self->{subtype} = $arg{-subtype} if exists $arg{-subtype};
  $self->{source}  = $arg{-source} || $arg{-source_tag} || '';
  $self->{score}   = $arg{-score}  || 0;
  $self->{start}   = $arg{-start};
  $self->{stop}    = $arg{-end} || $arg{-stop};

  # fix start, stop
  if (defined $self->{stop} && defined $self->{start}
      && $self->{stop} < $self->{start}) {
    @{$self}{'start','stop'} = @{$self}{'stop','start'};
    $self->{strand} *= -1;
  }

  my @segments;
  if (my $s = $arg{-segments}) {
    $self->add_segment(@$s);
  }
  $self;
}

sub add_segment {
  my $self        = shift;
  my $type = $self->{subtype} || $self->{type};
  $self->{segments} ||= [];

  my @segments = @{$self->{segments}};

  for my $seg (@_) {
    if (ref($seg) eq 'ARRAY') {
      push @segments,$self->new(-start=>$seg->[0],
				-stop=>$seg->[1],
				-strand=>$self->{strand},
				-type  => $type);
    } else {
      push @segments,$seg;
    }
  }
  if (@segments) {
    $self->{segments} = [ sort {$a->start <=> $b->start } @segments ];
    $self->{start} = $self->{segments}[0]->start;
    ($self->{stop}) = sort { $b <=> $a } map { $_->stop} @segments;
  }
}

sub segments {
  my $self = shift;
  my $s = $self->{segments} or return wantarray ? () : 0;
  @$s;
}
sub score    { shift->{score}       }
sub type     { shift->{type}        }
sub strand   { shift->{strand}      }
sub name     { shift->{name}        }
sub start    {
  my $self = shift;
  return $self->{start};
}
sub stop    {
  my $self = shift;
  return $self->{stop};
}
sub length {
  my $self = shift;
  return $self->stop - $self->start + 1;
}

sub source_tag { shift->{source} }

# This probably should be deleted.  Not sure why it's here, but might
# have been added for Ace::Sequence::Feature-compliance.
sub introns {
  my $self = shift;
  return;
}

1;

__END__

=head1 NAME

Ace::Graphics::Feature - A simple feature object for use with Ace::Graphics::Panel

=head1 SYNOPSIS

 use Ace::Graphics::Feature;

 # create a simple feature with no internal structure
 $f = Ace::Graphics::Feature->new(-start => 1000,
                                  -stop  => 2000,
                                  -type  => 'transcript',
                                  -name  => 'alpha-1 antitrypsin'
                                 );

 # create a feature composed of multiple segments, all of type "similarity"
 $f = Ace::Graphics::Feature->new(-segments => [[1000,1100],[1500,1550],[1800,2000]],
                                  -name     => 'ABC-3',
                                  -type     => 'gapped_alignment',
                                  -subtype  => 'similarity');

 # build up a gene exon by exon
 $e1 = Ace::Graphics::Feature->new(-start=>1,-stop=>100,-type=>'exon');
 $e2 = Ace::Graphics::Feature->new(-start=>150,-stop=>200,-type=>'exon');
 $e3 = Ace::Graphics::Feature->new(-start=>300,-stop=>500,-type=>'exon');
 $f  = Ace::Graphics::Feature->new(-segments=>[$e1,$e2,$e3],-type=>'gene');

=head1 DESCRIPTION

This is a simple Bio::SeqFeatureI-compliant object that is compatible
with Bio::Graphics::Panel.  With it you can create lightweight feature
objects for drawing.

All methods are as described in L<Bio::SeqFeatureI> with the following additions:

=head2 The new() Constructor

 $feature = Bio::Graphics::Feature->new(@args);

This method creates a new feature object.  You can create a simple
feature that contains no subfeatures, or a hierarchically nested object.

Arguments are as follows:

  -start       the start position of the feature
  -stop        the stop position of the feature
  -end         an alias for stop
  -name        the feature name (returned by seqname())
  -type        the feature type (returned by primary_tag())
  -source      the source tag
  -segments    a list of subfeatures (see below)
  -subtype     the type to use when creating subfeatures

The subfeatures passed in -segments may be an array of
Bio::Graphics::Feature objects, or an array of [$start,$stop]
pairs. Each pair should be a two-element array reference.  In the
latter case, the feature type passed in -subtype will be used when
creating the subfeatures.

If no feature type is passed, then it defaults to "feature".

=head2 Non-SeqFeatureI methods

A number of new methods are provided for compatibility with
Ace::Sequence, which has a slightly different API from SeqFeatureI:

=over 4

=item add_segment(@segments)

Add one or more segments (a subfeature).  Segments can either be
Feature objects, or [start,stop] arrays, as in the -segments argument
to new().  The feature endpoints are automatically adjusted.

=item segments()

An alias for sub_SeqFeatures().

=item merged_segments()

Another alias for sub_SeqFeatures().

=item stop()

An alias for end().

=item name()

An alias for seqname().

=item exons()

An alias for sub_SeqFeatures() (you don't want to know why!)

=back

=head1 SEE ALSO

L<Bio::Graphics::Panel>,L<Bio::Graphics::Glyph>,
L<GD>

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
