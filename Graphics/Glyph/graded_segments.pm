package Bio::Graphics::Glyph::graded_segments;

use strict;
use Bio::Graphics::Glyph::generic;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::generic';

# override draw method to calculate the min and max values for the components
sub draw {
  my $self = shift;

  # bail out if this isn't the right kind of feature
  # handle both das-style and Bio::SeqFeatureI style,
  # which use different names for subparts.
  my @parts = $self->parts;
  return $self->SUPER::draw(@_) unless @parts;

  # figure out the colors
  my $max_score = $self->option('max_score');
  unless ($max_score) {
    $max_score = 0;
    for my $part (@parts) {
      my $s = eval { $part->feature->score };
      $max_score = $s if $s > $max_score;
    }
  }

  return $self->SUPER::draw(@_) if $max_score <= 0;

  # allocate colors
  my $fill   = $self->bgcolor;
  my ($red,$green,$blue) = $self->panel->rgb($fill);

  foreach my $part (@parts) {
    my $s = eval { $part->feature->score };
    unless (defined $s) {
      $part->{partcolor} = $fill;
      next;
    }
    my($r,$g,$b) = map {(255 - (255-$_) * ($s/$max_score))} ($red,$green,$blue);
    my $idx      = $self->panel->translate_color($r,$g,$b);
    $part->{partcolor} = $idx;
  }

  $self->SUPER::draw(@_);
}

# component draws a shaded box
sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($left,$top) = @_;
  my $color = $self->{partcolor};
  my @rect = $self->bounds(@_);
  $self->filled_box($gd,@rect,$color,$color);
}

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
