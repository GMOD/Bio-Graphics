package Bio::Graphics::Glyph::track;

use strict;
use base 'Bio::Graphics::Glyph';

# track sets connector to empty
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'none';
}

1;
