package Bio::Graphics::Glyph::bdgp_ests;

use strict;
use Bio::Location::Simple;
use Bio::Graphics::Glyph::generic;
use Bio::Graphics::Glyph::segments;
use vars '@ISA';
@ISA = qw( Bio::Graphics::Glyph::segments
	   Bio::Graphics::Glyph::generic
	 );

sub draw_connectors {
  my $self = shift;
  my $gd = shift;
  my ($dx,$dy) = @_;
  my @parts = sort { $a->left <=> $b->left } $self->parts;
  my $connector = $self->connector;
  for (my $i = 0; $i < @parts-1; $i++) {
    #intercept and set connector type before draw connector
    $self->_set_connector($parts[$i], $parts[$i+1]);
    $self->_connector($gd,$dx,$dy,$parts[$i]->bounds,$parts[$i+1]->bounds);
  }
  $self->factory->set_option(connector=>$connector);

  # extra connectors going off ends
  if (@parts) {
    my($x1,$y1,$x2,$y2) = $self->bounds(0,0);
    my($xl,$xt,$xr,$xb) = $parts[0]->bounds;
    #intercept and set connector type before draw connector
    $self->_set_connector($parts[0], $parts[1]) if (@parts > 1);
    $self->_connector($gd,$dx,$dy,$x1,$xt,$x1,$xb,$xl,$xt,$xr,$xb);
    ($xl,$xt,$xr,$xb) = $parts[-1]->bounds;
    #intercept and set connector type before draw connector
    $self->_set_connector($parts[-1], $parts[-2]) if (@parts > 1);
    $self->_connector($gd,$dx,$dy,$parts[-1]->bounds,$x2,$xt,$x2,$xb) if ($xl > $x2);
    # to avoid having a protruding line when all parts in the view
    # skinny box on the far right even though it is an intron (gap)--bug?
  }
}
sub _set_connector {
  my $self = shift;
  my ($part1, $part2) = @_;

  #dynamically set connector type
  if ($part1->feature->can('homol_sf') && $part2->feature->can('homol_sf')) {
    if ($part1->feature->homol_sf->src_seq->name
	eq $part2->feature->homol_sf->src_seq->name) {
      $self->factory->set_option(connector=>'solid');
    }
    else {
      $self->factory->set_option(connector=>'dashed');
    }
  }
}

1;

__END__

=head1 NAME

Bio::Graphics::Glyph::bdgp_ests - The "bdgp_ests" glyph

=head1 SYNOPSIS

  See L<Bio::Graphics::Panel> and L<Bio::Graphics::Glyph>.

=head1 DESCRIPTION

This glyph is used for drawing features that consist of discontinuous
segments.  Unlike "graded_segments" or "alignment", the segments are a
uniform color and not dependent on the score of the segment. Further,
connector is solid when 2 connected spans have same subject seq while it
is dashed when they have diff subject seqs, e.g. BOP merging 5' and 3'
ESTs of the same cDNA clone into one feature (resultset).
This way, dashed connector represents gap rather than intron.
For this to work, feature obj in this glyph MUST support homol_sf API
(seq feature obj with name property).

=head2 OPTIONS

The following options are standard among all Glyphs.  See
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

  -connector    Connector type                 N/A (overwritten)

  -connector_color
                Connector color                black

  -label        Whether to draw a label	       0 (false)

  -description  Whether to draw a description  0 (false)

  -strand_arrow Whether to indicate            0 (false)
                 strandedness

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::Graphics::Panel>,
L<Bio::Graphics::Track>,
L<Bio::Graphics::Glyph::anchored_arrow>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::box>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::graded_segments>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::transcript>,
L<Bio::Graphics::Glyph::transcript2>,

=head1 AUTHOR

Shengqiang Shu E<lt>sshu@bdgp.lbl.govE<gt>

Copyright (c) 2002 BDGP

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
