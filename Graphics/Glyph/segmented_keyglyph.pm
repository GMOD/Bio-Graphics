package Bio::Graphics::Glyph::segmented_keyglyph;

# $Id: segmented_keyglyph.pm,v 1.2 2001-12-09 04:32:03 lstein Exp $
# Don't use this package.  It's just for inheriting the segmented glyph in the panel key.

use strict;
use Bio::Graphics::Glyph::generic;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::generic';

sub make_key_feature {
  my $self = shift;
  my $scale = 1/$self->scale;  # base pairs/pixel
  # two segments, at pixels 0->50, 60->80
  my $offset = $self->panel->offset;
  my $feature =
    Bio::Graphics::Feature->new(
				-segments=>[ [ 0*$scale +$offset,50*$scale+$offset],
					     [60*$scale+$offset, 80*$scale+$offset]
					   ],
				-name => $self->option('key'),
				-strand => '+1',
			       );
}

1;
