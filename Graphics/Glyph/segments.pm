package Bio::Graphics::Glyph::segments;

use strict;
use Bio::Graphics::Glyph::generic;
use Bio::Graphics::Glyph::segmented_keyglyph;
use vars '@ISA';
@ISA = qw(Bio::Graphics::Glyph::segmented_keyglyph
	  Bio::Graphics::Glyph::generic);

# group sets connector to 'solid'
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'solid';
}
# group sets connector to 'solid'
sub bump {
  my $self = shift;
  return $self->SUPER::bump(@_) if $self->all_callbacks;
  return 0;
}
# turn off labels
sub label {
  my $self = shift;
  return unless (my @a = $self->feature->sub_SeqFeature) > 0;
  $self->SUPER::label(@_);
}
# turn off and descriptions
sub description {
  my $self = shift;
  return unless (my @a = $self->feature->sub_SeqFeature) > 0;
  $self->SUPER::description(@_);
}

1;
