package Bio::Graphics::Glyph::crossbox;

use strict;
use vars '@ISA';
@ISA = 'Bio::Graphics::Glyph::generic';

# override draw_component to draw a crossed box rather than empty
sub draw_component {
  my $self = shift;
  my $gd = shift;
  my $fg = $self->fgcolor;
  my ($left,$top) = @_;
  my($x1,$y1,$x2,$y2) = $self->bounds(@_);
  $self->box($gd,
		     $x1, $y1,
		     $x2, $y2);

  if ($self->option('bgcolor')){
    my $c = $self->color('bgcolor');
    $gd->fill($xmid,$ymid,$c);
  }

  $gd->line($x1,$y1,$x2,$y2,$fg);
  $gd->line($x1,$y2,$x2,$y1,$fg);

  $self->draw_label($gd,$x1,$y1-$self->height) if $self->option('label');
}


1;

__END__

=head1 NAME

Bio::Graphics::Glyph::crossbox - The "crossbox" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This is a box with an 'X' inside glyph.

=head2 OPTIONS

The following options are standard among all Glyphs.  See individual
glyph pages for more options.

  Option      Description               Default
  ------      -----------               -------

  -fgcolor    Foreground color		black

  -outlinecolor				black
	      Synonym for -fgcolor

  -bgcolor    Background color          white

  -fillcolor  Interior color of filled  turquoise
	      images

  -linewidth  Width of lines drawn by	1
		    glyph

  -height     Height of glyph		10

  -font       Glyph font		gdSmallFont

  -label      Whether to draw a label	false

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Ace::Sequence>, L<Ace::Sequence::Feature>, L<Bio::Graphics::Panel>,
L<Bio::Graphics::Track>, L<Bio::Graphics::Glyph::anchored_arrow>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::box>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,

=head1 AUTHOR

Allen Day <day@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
