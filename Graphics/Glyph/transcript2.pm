package Bio::Graphics::Glyph::transcript2;

use strict;
use Bio::Graphics::Glyph::transcript;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::transcript';

use constant MIN_WIDTH_FOR_ARROW => 8;

sub pad_left  {
  my $self = shift;
  my $pad = $self->Bio::Graphics::Glyph::generic::pad_left;
  return $pad unless $self->feature->strand < 0;
  my $first = ($self->parts)[0] or return $pad;
  my @rect  = $first->bounds();
  my $width = abs($rect[2] - $rect[0]);
  return $self->SUPER::pad_left if $width < MIN_WIDTH_FOR_ARROW;
  return 0;
}

sub pad_right  {
  my $self = shift;
  my $pad = $self->Bio::Graphics::Glyph::generic::pad_right;
  my $last = ($self->parts)[-1] or return $pad;
  my @rect  = $last->bounds();
  my $width = abs($rect[2] - $rect[0]);
  return $self->SUPER::pad_right if $width < MIN_WIDTH_FOR_ARROW;
  return $pad;
}

sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  my @rect = $self->bounds(@_);

  my $width = abs($rect[2] - $rect[0]);
  my $filled = defined($self->{partno}) && $width >= MIN_WIDTH_FOR_ARROW;

  if ($filled) {

    if ($self->feature->strand < 0 && $self->{partno} == 0) { # first exon, minus strand transcript
      $self->filled_arrow($gd,-1,@rect);
      $self->{filled}++;
    } elsif ($self->feature->strand >= 0 && $self->{partno} == $self->{total_parts}-1) { # last exon, plus strand
      $self->filled_arrow($gd,+1,@rect);
      $self->{filled}++;
    } else {
      $self->SUPER::draw_component($gd,@_);
    }
  }

  else {
    $self->SUPER::draw_component($gd,@_);
  }

}

# override option() for force the "hat" type of connector
sub connector {
  return 'hat';
}

sub draw_connectors {
  my $self = shift;
  my @parts = $self->parts;
  if ($parts[0]->{filled} || $parts[-1]->{filled}) {
    $self->Bio::Graphics::Glyph::generic::draw_connectors(@_);
  } else {
    $self->SUPER::draw_connectors(@_);
  }
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

sub bump {
  my $self = shift;
  return $self->SUPER::bump(@_) if $self->all_callbacks;
  return 0;  # never allow our components to bump
}

1;
