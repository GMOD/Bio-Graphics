package Bio::Graphics::Glyph::wormbase_transcript;

use strict;
use Bio::Graphics::Glyph::transcript2;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::transcript2';

sub bgcolor {
  my $self = shift;
  my $feature = $self->feature;
  if ($feature->strand >= 0) {
    return $self->color('forwardcolor');
  } else {
    return $self->color('reversecolor');
  }
}

sub get_description {
  my $self   = shift;
  my $feature = shift;

  # fetch modularity-breaking acedb sequence object information
  # for backward compatibility with wormbase requirements
  my $acedb_info = eval {
    my $t       = $feature->info;
    my $id      = $t->Brief_identification;
    my $comment = $t->Locus;
    $comment   .= $comment ? " ($id)" : $id if $id;
    $comment;
  };
  return $acedb_info if $acedb_info;

  my @notes = eval { $feature->notes };
  return join '; ',@notes;
}

1;
