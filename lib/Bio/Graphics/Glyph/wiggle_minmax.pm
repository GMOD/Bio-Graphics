package Bio::Graphics::Glyph::wiggle_minmax;
# $Id: wiggle_minmax.pm,v 1.2 2009-04-29 09:58:32 lstein Exp $

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

    if ($self->feature->can('statistical_summary')) {
	my ($min,$max) = $self->bigwig_autoscale($autoscale,$self->feature);
	$min_score = $min if $do_min;
	$max_score = $max if $do_max;
	return $self->sanity_check($min_score,$max_score);
    }

    # wig files don't have genome-wide statistics, so "global" and "chromosome"
    # are pretty much the same thing.
    if (($autoscale eq 'global' or $autoscale eq 'chromosome')
	&& (my $wig = eval{$self->wig})) {
	$min_score = $wig->min if $do_min;
	$max_score = $wig->max if $do_max;
	return $self->sanity_check($min_score,$max_score);
    }

    if ($do_min or $do_max) {
	my $first = $parts->[0];
	for my $part (@$parts) {
	    my $s   = ref $part ? $part->[2] : $part;
	    next unless defined $s;
	    $min_score = $s if $do_min && (!defined $min_score or $s < $min_score);
	    $max_score = $s if $do_max && (!defined $max_score or $s > $max_score);
	}
    }
    return $self->sanity_check($min_score,$max_score);
}

sub bigwig_autoscale {
    my $self = shift;
    my ($autoscale,$feature) = @_;
    my $s;

    if ($autoscale eq 'global') {
	$s = $feature->global_stats;
    } elsif ($autoscale eq 'chromosome') {
	$s = $feature->chr_stats;
    } else {
	$s = $feature->score;
    }

    return ($s->{minVal},$s->{maxVal});
}

1;
