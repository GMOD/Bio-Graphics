package Bio::Graphics::Glyph::transcript;

use strict;
use Bio::Graphics::Glyph::generic;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::generic';

sub pad_left  {
  my $self = shift;
  my $pad  = $self->SUPER::pad_left;
  return $pad unless $self->feature->strand < 0;
  return $self->arrow_length > $pad ? $self->arrow_length : $pad;
}

sub pad_right {
  my $self = shift;
  my $pad  = $self->SUPER::pad_right;
  return $pad unless $self->feature->strand > 0;
  return $self->arrow_length > $pad ? $self->arrow_length : $pad;
}

sub draw_connectors {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  $self->SUPER::draw_connectors($gd,$left,$top);
  my @parts = $self->parts;

  if ($self->feature->strand >= 0) {
    my($x1,$y1,$x2,$y2) = $parts[-1]->bounds(@_);
    my $center = ($y2+$y1)/2;
    $self->arrow($gd,$x2,$x2+$self->arrow_length,$center);
  } else {
    my($x1,$y1,$x2,$y2) = $parts[0]->bounds(@_);
    my $center = ($y2+$y1)/2;
    $self->arrow($gd,$x1,$x1 - $self->arrow_length,$center);
  }
}

sub arrow_length {
  my $self = shift;
  return $self->option('arrow_length') || 8;
}

# override option() for force the "hat" type of connector
sub connector {
  my $self = shift;
  return $self->SUPER::connector(@_) if $self->all_callbacks;
  return 'hat';
}

sub bump {
  my $self = shift;
  return $self->SUPER::bump(@_) if $self->all_callbacks;
  return 0;  # never allow our components to bump
}

sub label {
  my $self = shift;
  return $self->SUPER::label(@_) if $self->all_callbacks;
  return 0 unless $self->feature->sub_SeqFeature;
  return $self->SUPER::label(@_);
}


sub description {
  my $self = shift;
  return $self->SUPER::description(@_) if $self->all_callbacks;
  return 0 unless $self->feature->sub_SeqFeature;
  return $self->SUPER::description(@_);
}



1;
