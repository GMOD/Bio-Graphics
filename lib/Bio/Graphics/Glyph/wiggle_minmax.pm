package Bio::Graphics::Glyph::wiggle_minmax;
# $Id: wiggle_minmax.pm,v 1.2 2009-04-29 09:58:32 lstein Exp $

use strict;
use base qw(Bio::Graphics::Glyph::minmax);

sub minmax {
    my $self   = shift;
    my $parts  = shift;

    my $autoscale  = $self->option('autoscale') || 'local';

    my $min_score  = $self->min_score;
    my $max_score  = $self->max_score;

    my $do_min     = !defined $min_score;
    my $do_max     = !defined $max_score;

    if ($self->feature->can('statistical_summary')) {
	my ($min,$max,$mean,$stdev) = $self->bigwig_stats($autoscale,$self->feature);
	$min_score = $min if $do_min;
	$max_score = $max if $do_max;
	return ($min_score,$max_score,$mean,$stdev);
    }

    elsif (eval {$self->wig}) {
	if (my ($min,$max,$mean,$stdev) = $self->wig_stats($autoscale,$self->wig)) {
	    $min_score = $min if $do_min;
	    $max_score = $max if $do_max;
	    return ($min_score,$max_score,$mean,$stdev);
	}
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

sub bigwig_stats {
    my $self = shift;
    my ($autoscale,$feature) = @_;
    my $s;

    if ($autoscale =~ /global/ or $autoscale eq 'z_score') {
	$s = $feature->global_stats;
    } elsif ($autoscale eq 'chromosome') {
	$s = $feature->chr_stats;
    } else {
	$s = $feature->score;
    }
    return $self->clip($autoscale,
		       $s->{minVal},$s->{maxVal},Bio::DB::BigWig::binMean($s),Bio::DB::BigWig::binStdev($s));
}

sub wig_stats {
    my $self = shift;
    my ($autoscale,$wig) = @_;

    if ($autoscale =~ /global|chromosome|z_score/) {
	my $min_score = $wig->min;
	my $max_score = $wig->max;
	my $mean  = $wig->mean;
	my $stdev = $wig->stdev;
	return $self->clip($autoscale,$min_score,$max_score,$mean,$stdev);
    }  else {
	return;
    }
}

sub clip {
    my $self = shift;
    my ($autoscale,$min,$max,$mean,$stdev) = @_;
    return ($min,$max,$mean,$stdev) unless $autoscale =~ /clipped/;
    my $fold = $self->z_score_bound;
    my $clip_max = $mean + $stdev*$fold;
    my $clip_min = $mean - $stdev*$fold;
    $min = $clip_min if $min < $clip_min;
    $max = $clip_max if $max > $clip_max;
    return ($min,$max,$mean,$stdev);
}


sub z_score_bound {
    my $self = shift;
    return $self->option('z_score_bound') || 4;
}

# change the scaling of the data points if z-score autoscaling requested
sub rescale {
    my $self   = shift;
    my $points = shift;
    return $points unless $self->option('autoscale') eq 'z_score';

    my ($min,$max,$mean,$stdev)  = $self->minmax($points);
    foreach (@$points) {
	$_ = ($_ - $mean) / $stdev;
    }
    return $points;
}

sub global_mean_and_variance {
    my $self = shift;
    if (my $wig = $self->wig) {
	return ($wig->mean,$wig->stdev);
    } elsif ($self->feature->can('global_mean')) {
	my $f = $self->feature;
	return ($f->global_mean,$f->global_stdev);
    }
    return;
}

sub global_min_max {
    my $self = shift;
    if (my $wig = $self->wig) {
	return ($wig->min,$wig->max);
    } elsif (my $stats = eval {$self->feature->global_stats}) {
	return ($stats->{minVal},$stats->{maxVal});
    }
    return;
}
sub series_stdev {
    my $self = shift;
    my ($mean,$stdev) = $self->global_mean_and_variance;
    return $stdev;
}

sub series_mean {
    my $self = shift;
    my ($mean) = $self->global_mean_and_variance;
    return $mean;
}

sub series_min {
    my $self = shift;
    return ($self->global_min_max)[0];
}

sub series_max {
    my $self = shift;
    return ($self->global_min_max)[1];
}

sub wig {
  my $self = shift;
  my $d = $self->{wig};
  $self->{wig} = shift if @_;
  $d;
}


1;
