package Bio::Graphics::Glyph::topoview;

# Based on the fb_shmiggle glyph by Victor Strelets, FlyBase.org 
# Sheldon McKay 2015

use strict;
use GD;
use base 'Bio::Graphics::Glyph::generic';
use Text::ParseWords 'shellwords';
use Data::Dumper;
use List::Util qw/min max shuffle/;
use constant DEBUG => 0;

use vars qw/$colors_selected $black $red $white $grey @colors %Indices @colcycle
            $black $yellow $red $white $gray $darkgrey $lightgrey $charcoal/;

sub draw {
    my $self = shift;
    my $gd   = shift;
    my ($left,$top,$partno,$total_parts) = @_;
    my $ft   = $self->feature;
    my $ftid = $ft->{id};
    my $pn   = $self->panel;
    my $fgc  = $self->fgcolor;
    my $bgc  = $self->bgcolor;
    my($r,$g,$b);

    unless( $colors_selected ) {
	$black     = $gd->colorClosest(0,0,0);
	$yellow    = $gd->colorClosest(255,255,0);
	$white     = $gd->colorClosest(255,255,255);
	$red       = $gd->colorClosest(255,0,0);
	$lightgrey = $gd->colorClosest(225,225,225);
	$grey      = $gd->colorClosest(200,200,200);
	$darkgrey  = $gd->colorClosest(125,125,125);
	$charcoal  = $gd->colorClosest(75,75,75);
	foreach my $ccc ( @colcycle ) {
	    if( $ccc =~ /^[#]?(\S\S)(\S\S)(\S\S)$/ ) {
		($r,$g,$b)= ($1,$2,$3);
		eval('$r =hex("0x'.$r.'");'); 
		eval('$g =hex("0x'.$g.'");'); 
		eval('$b =hex("0x'.$b.'");');
	    }
	    my $c = $gd->colorClosest($r,$g,$b);
	    push(@colors,$c);
	}
	$colors_selected = 1;
    }
    
    my($pnstart,$pnstop)    = ($pn->start,$pn->end); # in seq coordinates
    my($xf1,$yf1,$xf2,$yf2) = $self->calculate_boundaries($left,$top);
    my $nseqpoints = $pnstop - $pnstart + 1;
    my $leftpad    = $pn->pad_left;
    $ft->{datadir} ||= $self->option('datadir');
    my $datadir    = $ENV{SERVER_PATH} . $ft->{datadir};
    
    my($start,$stop) = $pn->location2pixel(($ft->{start},$ft->{end}));
    my $ftscrstop    = $stop + $leftpad;
    my $ftscrstart   = $start + $leftpad;
    
    my $chromosome = $ft->{ref};
    my $flipped    = $self->{flip} ? 1 : 0;
    my($subsets,$subsetsnames,$signals) = $self->getData($ft,$datadir,$chromosome,$pnstart,$pnstop,$xf1,$xf2,$flipped,$gd);

    my $poly_pkg = $self->polygon_package;
    
    my @orderedsubsets = @{$subsets};
    my $nsets          = $#orderedsubsets+1;

    # x and y steps 
    my $xstep = $self->option('x_step');
    my $ystep = $self->option('y_step');
    unless ($ystep) {
	$ystep = int(100/$nsets);
	$ystep = 7  if $ystep >= 7; # empiricaly found - to read lines of tiny fonts
	$ystep = 12 if $ystep > 12; # empirically found - to preserve topo feel when number of subsets is small
    }
    unless ($xstep) {
	$xstep = 4;
    }
    my($xw,$yw) = ( $nsets*$xstep, ($nsets-1)*$ystep );
    
    my $polybg = $poly_pkg->new();
    $polybg->addPt($xf1,$yf2-$yw);
    $polybg->addPt($xf2,$yf2-$yw);
    $polybg->addPt($xf2-$xw, $yf2); 
    $polybg->addPt($xf1-$xw, $yf2); 
    $gd->polygon($polybg,$lightgrey); # background
    for( my $xx = $xf1+2; $xx<$xf2; $xx+=6 ) { $gd->line($xx,$yf2-$yw,$xx-$xw,$yf2,$grey); } # grid-helper
   
    my $xshift = 0;
    my $yshift = $nsets * $ystep;
    ($r,$g,$b)= (10,150,80);
    my $colcycler = 0; 
    my @screencoords = @{$signals->{screencoords}};
    my $max_signal = 30;
    my $koeff = 4;
    if( my $max = $self->max_score ) {
	$max_signal = $max;
	$koeff = 80.0/$max_signal;
    }
    my $predictor_cutoff = int($max_signal*0.95); # empirically found
    my @prevx = ();
    my @prevy = ();
    my @prevvals = ();
    my $profilen = $self->{no_max} ? 1 : 0;
    my %SPEEDUP = ();
    my $scrx = 0;
    my $no_fill = defined $self->option('fill') && !$self->option('fill');

    foreach my $subset ( @orderedsubsets ) {
	my ($bgcolor,$edgecolor);
	if ( $self->{color} ) {
	    $bgcolor = $self->{color}->{$subset};
	}
	if ( $self->{edge_color} ) {
            $edgecolor = $self->{edge_color}->{$subset};
        }
	my $color = (!$self->{no_max} && $profilen ==0) ? $darkgrey : $bgcolor || $colors[$colcycler];
	$edgecolor = $charcoal;#||= (!$self->{no_max} && $xshift ==0) ? $black : $color;
	$xshift -= $xstep;
	$yshift -= $ystep;
	my @values = @{$signals->{$subset}};
	my($xold,$yold)= ($xf1+$xshift,$yf2-$yshift+1);
	my $xpos = 0;
	my $poly = $poly_pkg->new();
	$poly->addPt($xold,$yold+1);
	my @allx = ($xold);
	my @ally = ($yold);
	my @allvals = (0);
	my $runx = $xf1 + $xshift;
	foreach my $val ( @values ) {
	    $scrx += $leftpad;
	    my $x =  $screencoords[$xpos] + $xshift;
	    my $visval;
	    if( exists $SPEEDUP{$val} ) { $visval = $SPEEDUP{$val}; }
	    else { $visval = int($val*$koeff); $SPEEDUP{$val}= $visval; }
	    my $y = $yf2 - $yshift - $visval;
	    push(@allx,$x);
	    push(@ally,$y);
	    push(@allvals,$visval);
	    if( $xpos>0 ) {
		$poly->addPt($x,$y+1);
	    }
	    ($xold,$yold)= ($x,$y);
	    $xpos++;
	}
	$poly->addPt($xf2+$xshift, $yf2-$yshift+1); 
	unless ($profilen == 0 || $no_fill) {
	    $gd->filledPolygon($poly,$color);
	}
	($xold,$yold)= ($allx[0],$ally[0]);
	for( my $en =1; $en<=$#allx; $en++ ) {
	    my $x = $allx[$en];
	    my $y = $ally[$en];
	    $gd->line($xold,$yold,$x,$y,$edgecolor);
	    ($xold,$yold)= ($x,$y);
	} 

	# add scale bar to left and mid-point
	if ($profilen == 1) {
	    my($xmin,$yyy,$ymax) = ($allx[1]-1,$yf2-$yw,$ally[0]);
	    my $xmid = int(($allx[-1] - $xmin)/2);
	    $self->add_scale_bar([$xmin,$xmid],$yyy,$max_signal,$gd);
	    $self->{_xmid} = $xmid;
	    $self->{_ymin} = $ymax; 
	}

	$self->{_key}->{$subsetsnames->{$subset}} = $color;

	$gd->string(GD::Font->Tiny,$xf2+$xshift+3, $yf2-$yshift-5,$subsetsnames->{$subset},$color);
	$colcycler++;
	$colcycler = 0 if $colcycler>$#colors;
	unless( $profilen ==0 ) { @prevx = @allx; @prevy = @ally; @prevvals = @allvals; }
	$profilen++;
    }

    my $hide_key = defined $self->option('show key') && !$self->option('show key');
    $self->add_subset_key($gd,$subsets) unless $hide_key;
    
    $gd->flipVertical() if $self->option('flip vertical');

    return;
}

sub add_scale_bar {
    my ($self,$xx,$y,$max_signal,$gd) = @_;
    return if $self->option('flip vertical');
    for my $x (@$xx) {
	$gd->string(GD::Font->Tiny,$x-12, $y-3,'0',$black);
	$gd->line($x-2,$y,$x-2,$y-50,$black);
	$gd->line($x-4,$y-47,$x-2,$y-50,$black);
	$gd->line($x,$y-47,$x-2,$y-50,$black);
	$gd->line($x-4,$y-44,$x-2,$y-44,$black);
	$gd->string(GD::Font->Tiny,$x-18, $y-47,int($max_signal+0.5),$black);
    }
}

sub add_subset_key {
    my ($self,$gd,$subsets) = @_;
    my @subsets = grep {!/MAX/} @$subsets;
    return if $self->option('flip vertical');
    my $first_x = $self->{_xmid}-250;
    my $first_y = 12;
    my $key_colors  = $self->{_key};
    my $edge_colors = $self->{edge_color};
    my $font = GD::Font->MediumBold;
    my $width = $self->width;
    my $total_key_width = 18;

    my ($longest_string) = sort {$b <=> $a}
    map  {$self->string_width($_,$font)} @subsets;

    my $count;
    my $x = $first_x;
    my $y = $first_y;

    my $cutoff = 100;
    if (@subsets > 8 && !(@subsets %2)) {
        $cutoff = @subsets/2 + 1;
    }
    elsif (@subsets > 8) {
        $cutoff = int(@subsets/2 + 0.5);
    }

    for my $subset (@subsets) {
        if (++$count == $cutoff) {
            $x = $first_x;
            $y = $first_y + 12;
        }
        my $color = $$key_colors{$subset};
        my $edgecolor = $$edge_colors{$subset};
        my $string_width = $self->string_width($subset,$font);
        $gd->rectangle($x,$y,$x+10,$y+10,$edgecolor);
        $gd->filledRectangle($x,$y,$x+10,$y+10,$color);
        $x += 14;
        $gd->string($font,$x,$y,$subset,$black);
        $x += $longest_string + 8;
    }
}

#--------------------------
sub getData {
    my $self = shift;
    my($ft,$datadir,$chromosome,$start,$stop,$scrstart,$scrstop,$flipped,$gd) = @_;
    my $global_max_signal = $self->option('max_score') || 0;
    my %Signals = ();
    $self->openDataFiles($datadir);

    my $subset_text = $self->option('subset order');
    if ($subset_text) {
	my @words = shellwords($subset_text);

	# subset + color
	if (!(@words %2) && $words[1] =~ /^[0-9A-F]{6}$/ && $words[2] !~ /^[.0-9]+$/) {
	    while (@words) {
		push @{$ft->{subsetsorder}}, [splice(@words,0,2)];
	    }
	}
	# subset + color + alpha
	elsif (!(@words %3) && $words[1] =~ /^[0-9A-F]{6}$/) {
            while (@words) {
                push @{$ft->{subsetsorder}}, [splice(@words,0,3)];
            }
        }
	# no color specified? Random color for you. Good luck!
	else {
	    for my $word (@words) {
		push @{$ft->{subsetsorder}}, [$word,$self->random_color()];
	    }
	}

    }

    my @subsets = (exists $ft->{'subsetsorder'}) ? @{$ft->{'subsetsorder'}} : sort split(/\t+/,$Indices{'subsets'});

    my $user_max = $self->option('max_score');

    # This bit of code reads in user-specified bgcolor, if provided
    if ( ref $subsets[0] eq 'ARRAY' ) {
	my %bgcolor;
	my %edgecolor;
	for (@subsets) {
	    next unless ref $_ eq 'ARRAY';
	    my ($subset,$color,$alpha)  = @$_;

	    my ($r,$g,$b) = $color =~ /^[#]?(\S\S)(\S\S)(\S\S)$/;
	    $r && $g && $b || die "topoview: Color must be in hex form (B87333) $color @$_\n";

	    eval('$r =hex("0x'.$r.'");');
	    eval('$g =hex("0x'.$g.'");');
	    eval('$b =hex("0x'.$b.'");');

	    $alpha ||= $self->option('fill opacity');
	    if ($alpha) {
		unless ($alpha <= 1) {
		    die "Alpha must be between zero and 1";
		}
		$alpha = 1 - $alpha unless $alpha == 1;
		$alpha *= 127;
	    }
	    else {
		$alpha = 20;
	    }
	    
	    $color = $gd->colorAllocateAlpha($r,$g,$b,$alpha);
	    
	    $bgcolor{$subset}   = $color;
	    $edgecolor{$subset} = $gd->colorAllocate($r,$g,$b);
	    
	    $_ = $subset;
	}
	$self->{color} = \%bgcolor;
	$self->{edge_color} = \%edgecolor;
    }

    shift(@subsets) if $subsets[0] eq 'MAX';
    warn("subsets: @subsets\n") if DEBUG;

    my %SubsetsNames = (exists $ft->{'subsetsnames'}) ? %{$ft->{'subsetsnames'}} : map { $_, $_ } @subsets;
    $SubsetsNames{MAX}= 'MAX'; 
    my $screenstep = ($scrstop-$scrstart+1) * 1.0 / ($stop-$start+1);
    my $donecoords = 0;
    my $local_max_signal = 0;

    foreach my $subset ( @subsets ) {
	my $nstrings = 0;
	# scan seq ranges offsets to see where to start reading
	my $key = $subset.':'.$chromosome;
	my $poskey = $key.':offsets';
	my $ranges_pos = (exists $Indices{$poskey}) ? int($Indices{$poskey}) : -1;
	if( $ranges_pos == -1 ) { next; } # no such signal..
	warn("  positioning for $poskey starts at $ranges_pos\n") if DEBUG;
	if( $start>=1000000 ) {  
	    my $bigstep = int($start/1000000.0);
	    if( exists $Indices{$key.':offsets:'.$bigstep} ) {
		my $jumpval = $Indices{$key.':offsets:'.$bigstep}; 
		warn("  jump in offset search to $jumpval\n") if DEBUG;
		$ranges_pos = int($jumpval); }
	}
	seek(DATF,$ranges_pos,0);
	my($offset,$offset1)= (0,0);
	my $lastseqloc = -999999999;
	my $useoffset = 0;
	while( (my $strs =<DATF>) ) {
	    $nstrings++ if DEBUG;
	    if( DEBUG ) {
		chop($strs); warn("  	positioning read for coord $start ($strs)\n"); }
	    last unless $strs =~m/^(-?\d+)[ \t]+(\d+)/;
	    my($seqloc,$fileoffset)= ($1,$2);
	    if( DEBUG ) {
		chop($strs); warn("  positioning read for $poskey => $seqloc, $fileoffset ($strs)\n"); }
	    $offset1 = $offset;
	    $offset = $fileoffset;
	    $lastseqloc = $seqloc;
	    if( $seqloc > $start ) { $useoffset = int($offset1); last; } 
	}
	warn("  will use offset $useoffset\n") if DEBUG;
	warn("  	(scanned $nstrings offset strings)\n") if DEBUG;
	if( $useoffset ==0 ) { # data offset cannot be 0 - means didn't find where to read required data..
	    next;
	    my @emptyvals = ();
	    for( my $ii = $scrstart; $ii++ <= $scrstop; ) { push(@emptyvals,0); }
	    $Signals{$subset}= \@emptyvals;
	}
	$nstrings = 0;
	# read signal profile 
	seek(DATF,$useoffset,0);
	$lastseqloc = -999999999;
	my $lastsignal = 0;
	my($scrx,$scrxold)= ($scrstart,$scrstart-1);
	my $runmax = 0;
	my @values = ();
	my @xscreencoords = ();

	while( (my $str =<DATF>) ) {
	    $nstrings++ if DEBUG;
	    unless( $str =~m/^(-?\d+)[ \t]+(\d+)/ ) {
		warn("  header read: $str") if DEBUG;
		last; # because no headers were indexed at the beginning of data packs
	    }
	    my($seqloc,$signal)= ($1,$2);
	    my $real_signal = $signal;
	    $signal = $user_max if $user_max && $signal > $user_max;
	    $local_max_signal = $signal if $signal > $local_max_signal;

	    warn("  signal read: $seqloc, $signal 		line: $str") if DEBUG;
	    last if $lastseqloc > $seqloc; # just in case, as all sits merged in one file..
	    if( $seqloc>=$start ) { # current is the next one after the one we need to start from..
		unless( $lastseqloc == -999999999 ) { # expand previous
		    $lastseqloc = $start-2 if $lastseqloc<$start; # limit empty steps (they may start from -200000)
		    while( $lastseqloc < $seqloc ) { # until another (one we just retrieved) wiggle reading
			last if $lastseqloc > $stop; # end of subset data 
			next if $lastseqloc++ < $start; 
			# we have actual new seq position in our required range
			my $scrpos = int($scrx);
			$runmax = $lastsignal if $runmax < $lastsignal;
			if( $scrpos != $scrxold ) { # we have actual new seq _and_ screen position
			    push(@values,$runmax);
			    push(@xscreencoords,$scrpos) unless $donecoords;
			    #print STDERR Dumper \@xscreencoords unless $donecoords;
			    $scrxold = $scrpos;
			    $runmax = 0;
			}
			$scrx += $screenstep; # remember - it is not integer
		    }
		}
	    }
	    ($lastseqloc,$lastsignal)= ($seqloc,$signal);
	    last if $seqloc > $stop; # end of subset data
	}
	if( $lastseqloc < $stop ) { # if on the end of signal profile, but still in screen range
	    # just assume that we are getting one more reading with signal == 0
	    my $signal = 0;
	    while( $lastseqloc++ < $stop ) {
		my $scrpos = int($scrx);
		if( $scrpos != $scrxold ) { # we have actual new seq _and_ screen position
		    push(@values,$signal);
		    push(@xscreencoords,$scrpos) unless $donecoords;
		    $scrxold = $scrpos;
		}
		$scrx += $screenstep;
	    }
	}
	warn("  	(scanned $nstrings signal strings)\n") if DEBUG;
	$nstrings = 0;
	if( $flipped ) {
	    my @ch = reverse @values; @values = @ch;
	}
	warn("  ".$subset."=> ".@values." values @values\n") if DEBUG && $#values<1000;
	$Signals{$subset}= \@values;
	$Signals{screencoords}= \@xscreencoords unless $donecoords;
	$donecoords = 1;
    } # foreach my $subset ( @subsets ) {

    # scaling can be local, user-defined max or global max
    my $scale    = $self->option('autoscale') || 'global';
    if ($scale eq 'local' && !$user_max) {
	$self->max_score($local_max_signal);
    }
    else {
	$self->max_score($user_max || $Indices{max_signal});
    }
    
    warn("  max_signal => ".$self->max_score." \n") if DEBUG;

    # prepare MAX profile - will be used as a base for exon/UTR prediction
    $self->{no_max} = defined $self->option('show max') && ! $self->option('show max');
    unless ($self->{no_max}) {
	my @maxprofile = ();
	my @ruler = @{$Signals{screencoords}};
	for( my $npos = 0; $npos<=$#ruler; $npos++ ) {
	    my $maxval = 0;
	    foreach my $subset ( @subsets ) {
		my $p = $Signals{$subset};
		my $val = $p->[$npos];
		$maxval = $val if $maxval < $val;
	    }
	    push(@maxprofile,$maxval);
	}
	$Signals{MAX}= \@maxprofile;
	warn("  MAX => ".@maxprofile." values @maxprofile\n") if DEBUG && $#maxprofile<1000;
	unshift(@subsets,'MAX');
    }
 
    return(\@subsets,\%SubsetsNames, \%Signals);
}

#--------------------------
sub openDataFiles {
    my $self = shift;
    my $datadir = shift;
    $datadir.= '/' unless $datadir =~m|/$|;
    my $datafile = $datadir.'data.cat';
    open(DATF,$datafile) || die("cannot open $datafile\n");
    use BerkeleyDB; # caller should already used proper 'use lib' command with path
    my $bdbfile = $datadir . 'index.bdbhash';
    tie %Indices, "BerkeleyDB::Hash", -Filename => $bdbfile, -Flags => DB_RDONLY || warn("can't read BDBHash $bdbfile\n"); 
    if( DEBUG ) { foreach my $kk ( sort keys %Indices ) { warn("	$kk => ".$Indices{$kk}."\n"); } }
    return;
}

sub min_score {
    # not implemented
}

sub max_score {
    my $self  = shift;
    my $score = shift;
    $self->{max_score} ||= $score;
    return $self->{max_score};
}

sub random_color {
    my $self = shift;
    my @nums = 0..9,'A'..'F';
    my $color;
    for (0..5) {
	my @array = shuffle(@nums);
	my $char  = shift @array;
	$color .= $char;
    }
    return $color;
}


1;

=pod

=head1 TopoView Glyph

=begin html
<h2>topoview</h2>
"topoview.pm" the TopoView glyph was developed for fast
3D-like demonstration of RNA-seq data consisting of multiple
individual subsets. The main purposes were to compact presentation 
as much as possible (in one reasonably sized track) and
to allow easy visual detection of coordinated behavior
of the expression profiles of different subsets.  See the note below
about normalizing the expression profiles across the whole
experiment.

This glyph is derived from the fb_shmiggle Glyph, 
2009-2010 Victor Strelets, FlyBase.org 

<h2>Log transformation</h2>
It was found that log2 conversion dramatically changes
perception of expression profiles and kind of illuminates
coordinated behavior of different subsets.  Using log2-transformed
read counts is recomment (see below for instructions).

<h2>Data format and performance</h2>
Comparing performance (retrieval of several Kbp of data profiles
for several subsets of some RNA-seq experiment) of wiggle binary
method and of several possible alternatives, it was discovered that
one of the approaches remarkably outperforms wiggle bin method
(although it requires several times more space for formatted data 
storage). Optimal storage/retrieval method stores all experiment
data (all subsets of the experiment) in one text file, where
structure of the file in fact is one of the most simple wiggle
(coverage files) formats with the addition of some positioning
data (two-column format, without runlength specification, without
omission of zero values). This is the only format which glyph is able
to handle.

<pre>
# subset =BS107_all_unique chromosome =2LHet
-200000 0
0       0
19955   1
19959   0
19967   2
19972   0
19977   2
20027   0
20031   2
20035   0
20043   1
</pre>

<h2>Accessory scripts</h2>
The Bio::Graphics package has two scripts useful for processing BAM alignment
data from programs such as tophat for use with this glyph.
<p>
bam_coverage_windows.pl accepts a sorted bam file as input and will calculate
the average read coverage for a user-specified window size (default 25). The windows
are non-overlapping.  The output format is WIG/BED4, which is the format used by the
coverage_to_topoview.pl script.
<pre>
Usage: perl bam_coverage_windows.pl -b bamfile -n 10_000_000 -w 25 | gzip -c > bamfile.wig.gz
    -b name of bam file to read REQUIRED
    -w window size (default 25)
    -n normalized read number -- if you will be comparing multiple bam files 
                                 select the read number to normalize against.
                                 All counts will be adjusted by a factor of:
                                 actual readnum/normalized read num
  
</pre>
<b>Note: </b>If you are comparing BAM files with different total read counrts, you need 
to normalize the read counts for each BAM file with the -n option.  The number used in
-n should be near the avarage read count for all BAM files being analyzed in the experiment.
</p>
<p>
coverage_to_topoview.pl converts a list of coverage files (WIG/BED4) to the indexed
format used by this glyph. 
<pre>
Usage: perl coverage_to_topoview.pl [-o output_dir] [-h] [-l] file1.wig.gz file2.wig.gz
    -o output directory (default 'topoview')
    -l use log2 for read counts (recommended)
    -h this help message
</pre>

<b>Note 1:</b> Each WIG file corresponds to a single BAM file and is a subset (subtrack).
The base name of the file will be used a the subset.  For example, the file:<br>
shoots-R1.wig.gz will generate a subset names shoots-R1 in the topoview track.

<b>Note 2:</b> If you do not specify an output directory name, the default name
'topoview' will be used.  Any existing contents will be overwritten.  For example,
if you are making two tracks, one using raw counts and the other using log2 transformed counts:

<pre>perl coverage_to_topoview.pl -o raw file1.wig.gz file2.wig.gz</pre>
<pre>perl coverage_to_topoview.pl -o log2 -l  file1.wig.gz file2.wig.gz</pre>
</p>

<h2>Configuration</h2>
<h3>Example config stanza</h3>
<pre>
[TOPOVIEWLOG2]
databas       = scaffolds
feature       = region
glyph         = topoview
autoscale     = local
height        = 200
datadir       = /home/ubuntu/data/bam/log2
subset order  = SRR1810778.25  FF9966
                SRR1810779.25  FF6633
                SRR1810780.25  FF0000
                SRR1810781.25  00CC66
                SRR1810782.25  009933
                SRR1810783.25  006600
key           = TopHat: Normalized Read Coverage (log2)
show max      = 0
x_step        = 2
y_step        = 8
fill opacity  = 0.8
</pre>
<h3>Options</h3>
Glyph-specific options
<ul>
<li><b>feature</b> The full-length feature for the track.  This would usuallu be the feature type you configured for your chromosomes or scaffolds</li>
<li><b>database</b> The same database as you used for the chromosomes</li> 
<li><b>autoscale</b> are local and global local scales to the on-screen max value, global scales to the global max</li> 
<li><b>datadir</b> location of the indexed coverage data (absolute path)</li> 
<li><b>show max</b> show an extra subset corresponding to the maximum coverage across all subsets</li> 
<li><b>x_step</b> the horizontal offset (pixels) of each plotted subset (can not be zero)</li>
<li><b>y_step</b> the vertical offset (pixels) of each plotted subset (can not be zero)</li> 
<li><b>fill opacity</b> the degree of transparency of each plotted subset.  Translucency aids in the comparison.</li>
<li><b>subset order</b> the order and color of each subset (subplot) in the graph (see below)</li>
</ul>

<h4>Subsets</h4>
Setting 'subset order' is mandatory.  It specified the subsets and the order in which
they will be displayed.

There are three ways to represent the subsets:<br>

Ordered subsets with no color specified.  Random colors will be assigned.  Hope you are feeling lucky.
<pre>
subset order  = SRR1810778.25
                ...
</pre>

Ordered subsets with color specified (only use hex colors with the '#' ommitted)
<pre>
subset order  = SRR1810778.25  FF9966
                SRR1810779.25  FF6633
                ...
</pre>

Ordered subsets with color and opacity set.  Not that the global 'fill opacity' option affects all subsets.  Specifying individual opacity is optional.
<pre>                                                                                                                                                                                                                                     
subset order  = SRR1810778.25  FF9966 0.8
                SRR1810779.25  FF6633 0.7
                ...
</pre>   

<h2>More information</h2>


Questions about TopoView glyph should be directed to Sheldon McKay (Sheldon McKay).

=end html
