package Bio::Graphics::Glyph::group;

use strict;
use base 'Bio::Graphics::Glyph';

# group sets connector to 'dashed'
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'dashed';
}

1;
