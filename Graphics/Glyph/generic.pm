package Bio::Graphics::Glyph::generic;

use strict;
use base 'Bio::Graphics::Glyph';

# new options are 'label'       -- short label to print over glyph
#                 'long_label'  -- long label to print under glyph
# label and long_label can be flags or coderefs.
# If a flag, label will be taken from seqname, if it exists or primary_tag().
#            long_label will be taken from source_tag().

sub font {
  my $self = shift;
  $self->factory->font($self);
}
sub pad_top {
  my $self = shift;
  my $pad = $self->SUPER::pad_top;
  $pad   += $self->labelheight if defined $self->label ;
  $pad;
}
sub pad_bottom {
  my $self = shift;
  my $pad = $self->SUPER::pad_bottom;
  $pad   += $self->labelheight if defined $self->long_label;
  $pad;
}

sub labelheight {
  my $self = shift;
  return $self->{labelheight} ||= $self->font->height;
}
sub label {
  my $self = shift;
  return exists $self->{label} ? $self->{label}
                               : $self->{label} = $self->_label;
}
sub long_label {
  my $self = shift;
  return exists $self->{long_label} ? $self->{long_label}
                                    : $self->{long_label} = $self->_long_label;
}
sub _label {
  my $self = shift;

  # allow caller to specify the label
  my $label = $self->option('label');
  return unless defined $label;
  return $label unless $label eq '1';

  # figure it out ourselves
  my $f = $self->feature;
  my $info = eval {$f->info};
  return $info if $info;
  return $f->seqname if $f->can('seqname');
  return $f->primary_tag;
}
sub _long_label {
  my $self = shift;

  # allow caller to specify the long label
  my $label = $self->option('long_label');
  return unless defined $label;
  return $label unless $label eq '1';

  # fetch deeply-imbedded acedb sequence object information
  # for backward compatibility with wormbase implementation
  my $f = $self->feature;
  my $acedb_info = eval {
    my $t       = $f->info;
    my $id      = $f->Brief_identification;
    my $comment = $t->Locus;
    $comment   .= $comment ? " ($id)" : $id if $id;
    $comment;
  };
  return $acedb_info if $acedb_info;
  return $f->source_tag;
}

sub draw {
  my $self = shift;
  $self->SUPER::draw(@_);
  $self->draw_label(@_) if $self->option('label');
}

sub draw_label {
  my $self = shift;
  my ($gd,$left,$top,$partno,$total_parts) = @_;
  my $label = $self->label or return;
  $gd->string($self->font,
	      $self->left + $left,
	      $self->top + $top,
	      $label,
	      $self->fontcolor);
}


1;
