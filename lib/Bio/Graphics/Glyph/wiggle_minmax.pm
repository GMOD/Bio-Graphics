package Bio::Graphics::Glyph::wiggle_minmax;
# $Id: wiggle_minmax.pm,v 1.1 2009-03-17 13:24:17 lstein Exp $

use strict;
use base qw(Bio::Graphics::Glyph::minmax);

sub minmax {
    my $self   = shift;
    my $parts  = shift;

    my $autoscale  = $self->option('autoscale') || '';
    my $min_score  = $self->option('min_score');
    my $max_score  = $self->option('max_score');

    my $do_min     = !defined $min_score;
    my $do_max     = !defined $max_score;

    if ($autoscale eq 'global') {
	if (my $wig = $self->wig) {	
	    $min_score = $wig->min if $do_min;
	    $max_score = $wig->max if $do_max;
	}
    }

    if (($do_min or $do_max) and ($autoscale ne 'global')) {
	my $first = $parts->[0];
	for my $part (@$parts) {
	    my $s   = ref $part ? $part->[2] : $part;
	    next unless defined $s;
	    $min_score = $s if $do_min && (!defined $min_score or $s < $min_score);
	    $max_score = $s if $do_max && (!defined $max_score or $s > $max_score);
	}
    }

    return ($min_score,$max_score);
}

1;
