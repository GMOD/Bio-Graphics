package Bio::Graphics::Glyph::group;

use strict;
use base 'Bio::Graphics::Glyph';

# group sets connector to 'dashed'
sub connector {
  return 'dashed';
}

1;
