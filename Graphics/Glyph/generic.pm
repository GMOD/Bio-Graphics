package Bio::Graphics::Glyph::generic;

use strict;
use Bio::Graphics::Glyph;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph';

# new options are 'label'       -- short label to print over glyph
#                 'description'  -- long label to print under glyph
# label and description can be flags or coderefs.
# If a flag, label will be taken from seqname, if it exists or primary_tag().
#            description will be taken from source_tag().

sub font {
  my $self = shift;
  $self->factory->font($self);
}
sub pad_top {
  my $self = shift;
  my $pad = $self->SUPER::pad_top;
  $pad   += $self->labelheight if $self->label;
  $pad;
}
sub pad_bottom {
  my $self = shift;
  my $pad = $self->SUPER::pad_bottom;
  $pad   += $self->labelheight if $self->description;
  $pad;
}
sub pad_right {
  my $self = shift;
  my $pad = $self->SUPER::pad_right;
  my $label_width = length($self->label||'') * $self->font->width;
  my $description_width = length($self->description||'') * $self->font->width;
  my $max = $label_width > $description_width ? $label_width : $description_width;
  $pad = $max - ($self->width+$pad) if $max > ($self->width+$pad);
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
sub description {
  my $self = shift;
  return exists $self->{description} ? $self->{description}
                                     : $self->{description} = $self->_description;
}
sub _label {
  my $self = shift;

  # allow caller to specify the label
  my $label = $self->option('label');
  return unless defined $label;
  return $label unless $label eq '1';
  return "1"    if $label eq '1 ';

  # figure it out ourselves
  my $f = $self->feature;
  my $info = eval {$f->info};
  return $info if $info;
  return $f->seqname if $f->can('seqname');
  return $f->primary_tag;
}
sub _description {
  my $self = shift;

  # allow caller to specify the long label
  my $label = $self->option('description');
  return unless defined $label;
  return $label unless $label eq '1';
  return "1"   if $label eq '1 ';

  return $self->{_description} if exists $self->{_description};
  return $self->{_description} = $self->get_description($self->feature);
}

sub get_description {
  my $self = shift;
  my $feature = shift;
  if (my @notes = eval { $feature->notes }) {
    return join '; ',@notes;
  }
  my $tag = $feature->source_tag;
  return undef if $tag eq '';
  $tag;
}

sub draw {
  my $self = shift;
  $self->SUPER::draw(@_);
  $self->draw_label(@_)       if $self->option('label');
  $self->draw_description(@_) if $self->option('description');
}

sub draw_label {
  my $self = shift;
  my ($gd,$left,$top,$partno,$total_parts) = @_;
  my $label = $self->label or return;
  my $x = $self->left + $left;
  $x = $self->panel->left + 1 if $x <= $self->panel->left;
  my $font = $self->option('labelfont') || $self->font;
  $gd->string($font,
	      $x,
	      $self->top + $top,
	      $label,
	      $self->fontcolor);
}
sub draw_description {
  my $self = shift;
  my ($gd,$left,$top,$partno,$total_parts) = @_;
  my $label = $self->description or return;
  my $x = $self->left + $left;
  $x = $self->panel->left + 1 if $x <= $self->panel->left;
  $gd->string($self->font,
	      $x,
	      $self->bottom - $self->pad_bottom + $top,
	      $label,
	      $self->font2color);
}

sub arrowhead {
  my $self = shift;
  my $gd   = shift;
  my ($x,$y,$height,$orientation) = @_;
  my $fg = $self->set_pen;
  my $style = $self->option('arrowstyle') || 'regular';

  if ($style eq 'filled') {
    my $poly = new GD::Polygon;
    if ($orientation >= 0) {
      $poly->addPt($x-$height,$y-$height);
      $poly->addPt($x,$y);
      $poly->addPt($x-$height,$y+$height,$y);
    } else {
      $poly->addPt($x+$height,$y-$height);
      $poly->addPt($x,$y);
      $poly->addPt($x+$height,$y+$height,$y);
    }
    $gd->filledPolygon($poly,$fg);
  } else {
    if ($orientation >= 0) {
      $gd->line($x-$height,$y-$height,$x,$y,$fg);
      $gd->line($x,$y,$x-$height,$y+$height,$fg);
    } else {
      $gd->line($x+$height,$y-$height,$x,$y,$fg);
      $gd->line($x,$y,$x+$height,$y+$height,$fg);
    }
  }
}

sub arrow {
  my $self = shift;
  my $gd   = shift;
  my ($x1,$x2,$y) = @_;
  my $fg     = $self->set_pen;
  my $height = $self->height/2;

  $gd->line($x1,$y,$x2,$y,$fg);
  $self->arrowhead($gd,$x2,$y,$height,+1) if $x1 < $x2;
  $self->arrowhead($gd,$x2,$y,$height,-1) if $x2 < $x1;
}

1;
