package Bio::Graphics::Glyph::transcript2;

use strict;
use Bio::Graphics::Glyph::generic;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::generic';

sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  my @rect = $self->bounds(@_);

  if ($self->feature->strand < 0 && $self->{partno} == 0) { # first exon, minus strand transcript
    $self->filled_arrow($gd,-1,@rect);
  } elsif ($self->feature->strand >= 0 && $self->{partno} == $self->{total_parts}-1) { # last exon, plus strand
        $self->filled_arrow($gd,+1,@rect);
  } else {
    $self->SUPER::draw_component($gd,@_);
  }
}

# override option() for force the "hat" type of connector
sub connector {
  return 'hat';
}

sub bump {
  my $self = shift;
  return $self->SUPER::bump(@_) if $self->all_callbacks;
  return 0;  # never allow our components to bump
}

1;
