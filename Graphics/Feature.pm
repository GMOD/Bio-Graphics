package Bio::Graphics::Feature;

use strict;
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
  my %arg = @_;

  my $self = bless {},$class;

  $arg{-strand} ||= 0;
  $self->{strand} = $arg{-strand} >= 0 ? +1 : -1;
  $self->{name}   = $arg{-name};
  $self->{type}   = $arg{-type}   || 'feature';
  $self->{source} = $arg{-source} || $arg{-source_tag} || '';

  my @segments;
  if (my $s = $arg{-segments}) {

    for my $seg (@$s) {
      if (ref($seg) eq 'ARRAY') {
	push @segments,$class->new(-start=>$seg->[0],
				   -stop=>$seg->[1],
				   -strand=>$self->{strand},
				   -type => $arg{-subtype}||'feature');
      } else {
	push @segments,$seg;
      }
    }
  }

  if (@segments) {
    $self->{segments} = [ sort {$a->start <=> $b->start } @segments ];
    $self->{start} = $self->{segments}[0]->start;
    ($self->{stop}) = sort { $b <=> $a } map { $_->stop} @segments;
  } else {
    $self->{start} = $arg{-start};
    $self->{stop}   = $arg{-end} || $arg{-stop};
  }
  $self;
}

sub segments {
  my $self = shift;
  my $s = $self->{segments} or return wantarray ? () : 0;
  @$s;
}
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
sub introns {
  my $self = shift;
  return;
}
sub source_tag { shift->{source} }

1;

__END__

=head1 NAME

Ace::Graphics::Fk - A dummy feature object used for generating panel key tracks

=head1 SYNOPSIS

None.  Used internally by Ace::Graphics::Panel.

=head1 DESCRIPTION

None.  Used internally by Ace::Graphics::Panel.

=head1 SEE ALSO

L<Ace::Sequence>,L<Ace::Sequence::Feature>,
L<Ace::Graphics::Track>,L<Ace::Graphics::Glyph>,
L<GD>

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
