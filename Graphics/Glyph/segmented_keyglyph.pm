package Bio::Graphics::Glyph::segmented_keyglyph;

# $Id: segmented_keyglyph.pm,v 1.1 2001-11-29 20:40:56 lstein Exp $
# Don't use this package.  It's just for inheriting the segmented glyph in the panel key.

use strict;
use Bio::Graphics::Glyph::generic;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::generic';

# synthesize a key glyph
sub keyglyph {
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
				-strand => '+1');
  my $factory = $self->factory->clone;
  $factory->set_option(label => 1);
  $factory->set_option(bump  => 0);
  $factory->set_option(connector  => 'solid');
  return $factory->make_glyph($feature);
}

1;
