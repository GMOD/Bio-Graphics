package Bio::Graphics::Glyph::track;

use strict;
use Bio::Graphics::Glyph;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph';

# track sets connector to empty
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'none';
}

#sub draw {
#  my $self = shift;
#  my ($gd,$left,$top,$partno,$total_parts) = @_;
#  $self->SUPER::draw(@_);
#}

# do nothing for components
# sub draw_component { }

1;
