package Bio::Graphics::Glyph::group;

use strict;
use vars '@ISA';
use Bio::Graphics::Glyph::generic;
@ISA = 'Bio::Graphics::Glyph::generic';

# group sets connector to 'dashed'
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'dashed';
}

sub layout_width {
  my $self = shift;
  my @parts = $self->parts or return $self->SUPER::layout_width;
  return $self->{layout_width} if exists $self->{layout_width};
  my $max = $self->SUPER::layout_width;
  foreach (@parts) {
    my $part_width = $_->layout_width;
    $max = $part_width if $part_width > $max;
  }
  return $self->{layout_width} = $max;
}

1;
