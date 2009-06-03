package Bio::Graphics::Glyph::hat;
# $Id: hat.pm,v 1.1 2009-06-03 20:22:17 lstein Exp $
# a simple inverted V (used by DAS)

use strict;
use base qw(Bio::Graphics::Glyph::generic);

sub my_description {
    return <<END;
This glyph draws an inverted V spanning the feature.
END
}

sub draw_component {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = $self->calculate_boundaries(@_);

  my $fg = $self->fgcolor;
  my $center = ($y1+$y2)/2;
  my $middle = ($x1+$x2)/2;

  my $linewidth = $self->linewidth;
  $fg = $self->set_pen($linewidth) if $linewidth > 1;

  $gd->line($x1,$center,$middle,$y1,$fg);
  $gd->line($middle,$y1,$x2,$center,$fg);
  # add a label if requested
  $self->draw_label($gd,@_) if $self->option('label');

}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::line - The "line" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph draws a line parallel to the sequence segment.

=head2 OPTIONS

This glyph takes only the standard options. See
L<Bio::Graphics::Glyph> for a full explanation.

  Option      Description                      Default
  ------      -----------                      -------

  -fgcolor      Foreground color	       black

  -outlinecolor	Synonym for -fgcolor

  -bgcolor      Background color               turquoise

  -fillcolor    Synonym for -bgcolor

  -linewidth    Line width                     1

  -height       Height of glyph		       10

  -font         Glyph font		       gdSmallFont

  -connector    Connector type                 0 (false)

  -connector_color
                Connector color                black

  -label        Whether to draw a label	       0 (false)

  -description  Whether to draw a description  0 (false)

  -strand_arrow Whether to indicate            0 (false)
                 strandedness

  -hilite       Highlight color                undef (no color)

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Glyph>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::cds>,
L<Bio::Graphics::Glyph::crossbox>,
L<Bio::Graphics::Glyph::diamond>,
L<Bio::Graphics::Glyph::dna>,
L<Bio::Graphics::Glyph::dot>,
L<Bio::Graphics::Glyph::ellipse>,
L<Bio::Graphics::Glyph::extending_arrow>,
L<Bio::Graphics::Glyph::generic>,
L<Bio::Graphics::Glyph::graded_segments>,
L<Bio::Graphics::Glyph::heterogeneous_segments>,
L<Bio::Graphics::Glyph::line>,
L<Bio::Graphics::Glyph::pinsertion>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::rndrect>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::ruler_arrow>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,
L<Bio::Graphics::Glyph::transcript2>,
L<Bio::Graphics::Glyph::translation>,
L<Bio::Graphics::Glyph::triangle>,
L<Bio::DB::GFF>,
L<Bio::SeqI>,
L<Bio::SeqFeatureI>,
L<Bio::Das>,
L<GD>

=head1 AUTHOR

Allen Day E<lt>day@cshl.orgE<gt>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
