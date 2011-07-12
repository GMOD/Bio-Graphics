package Bio::Graphics::Glyph;

use strict;
use Carp 'croak','cluck';
use constant BUMP_SPACING => 2; # vertical distance between bumped glyphs
use Bio::Root::Version;
use Bio::Graphics::Layout;

use Memoize 'memoize';
memoize('options') unless $^O =~ /mswin/i;
# memoize('option'); # helps ??

use base qw(Bio::Root::Root);

my %LAYOUT_COUNT;
my @FEATURE_STACK;

# the CM1 and CM2 constants control the size of the hash used to
# detect collisions.
use constant CM1 => 20; # big bin, x axis
use constant CM2 => 20; # big bin, y axis
use constant CM3 => 50;  # small bin, x axis
use constant CM4 => 50;  # small bin, y axis
use constant INF  => 1<<16;
use constant NINF => -INF();
use constant DEBUG => 0;

use constant QUILL_INTERVAL => 8;  # number of pixels between Jim Kent style intron "quills"


##########################################################
# glyph-specific options
#
# the data structure returned by my_options will be merged
# with values returned by this method in subclasses to
# create a merged hash of all options that can be invoked
#
# retrieve this merged hash with 
# Bio::Graphics::Glyph::the_subclass->options
#
##########################################################
sub my_description {
    return <<END;
This is the base class for all glyphs. It knows how to draw simple
filled and empty boxes. You will want to use the "generic" or
"box" glyphs instead of this one.
END
}

sub my_options {
    return
    {
	height => [
	    'integer',
	    10,
	    'Height of the glyph.'],
	box_subparts=> [
	    'integer',
	    0,
	    'If this option is greater than zero, then imagemaps constructed from this glyph will contain',
	    'bounding boxes around each subpart of a feature (e.g. each exon in a gene). The value of the',
	    'option indicates the depth of recursion.'
	],
	fgcolor => [
	    ['color','featureScore','featureRGB'],
	    'black',
	    'The foreground color of the glyph, used for drawing outlines.',
	    'A value of "featureScore" will produce a greyscale gradient from the',
	    "feature's score value based on a range from 0 (lightest) to 1000 (darkest).",
	    'A value of "featureRGB" will look for a feature tag named "RGB" and use that',
	    'for the color value.',
	    'See the next section for color choices.'],
	bgcolor => [
	    ['color','featureScore','featureRGB'],
	    'turquoise',
	    'The background color of the glyph, used for filling its contents.',
	    'A value of "featureScore" will produce a greyscale gradient from the',
	    "feature's score value based on a range from 0 (lightest) to 1000 (darkest).",
	    'A value of "featureRGB" will look for a feature tag named "RGB" and use that',
	    'for the color value.',
	    'See the next section for color choices.'],
	fillcolor => [
	    'color',
	    'turquoise',
	    'A synonym for -bgcolor.'],
	tkcolor   => [
	    'color',
	    undef,
	    'Rarely-used option to flood-fill entire glyph with a single color',
	    'prior to rendering it.'],
	linewidth    => [
	    'integer',
	    1,
	    'Thickness of line used to draw the glyph\'s outline.'],
	strand_arrow => [
	    'boolean',
	    undef,
	    "Whether to indicate the feature's strandedness. If equal to 'ends'",
	    "then only the right and left ends of multi-part features will show",
	    "strandedness."
	],
	stranded => [
	    'boolean',
	    undef,
	    'Synonym for -strand_arrow.',
	    "Indicates whether to indicate the feature's strandedness. If equal to 'ends'",
	    "then only the right and left ends of multi-part features will show",
	    "strandedness."

	],
	key => [
	    'string',
	    undef,
	    'The printed label to use to describe this track.'],
	category => [
	    'string',
	    undef,
	    'A descriptive category that will be added to the track key.'],
	no_subparts => [
	    'boolean',
	    undef,
	    'Set this option to a true value to suppress drawing of all its subparts.'],
	ignore_sub_part => [
	    'string',
	    undef,
	    'Pass a space-delimited list of primary_tag() names in order to selectively',
	    'suppress the drawing of subparts that match those primary tags.'],
	maxdepth => [
	    'integer',
	    undef,
	    'Specifies how many levels deep the glyph should traverse features looking',
	    'for subfeatures. A value of undef allows unlimited traversal. A value of',
	    '0 suppresses traversal entirely for the same effect as -no_subparts.'],
	sort_order => [
	    ['left','right','low_score','high_score','longest','shortest','strand','name'],
	    'left',
	    'Control how features are layed out so that more "important" features sort',
	    'towards the top. See the Bio::Graphics::Glyph documentation for a description of how this' ,
	    'works.'],
	always_sort => [
	    'boolean',
	    undef,
	    'Sort even when bumping is off.'],
	bump => [
	    'integer',
	    1,
	    'This option dictates the behavior of the glyph when two features collide horizontally.',
	    'A value of +1 will bump the colliding feature downward using an algorithm that uses spaces efficiently.',
	    'A value of -1 will bump the colliding feature upward using the same algorithm.',
	    'Values of +2 and -2 will bump using a simple algorithm that is faster but does not use space as efficiently.',
	    'A value of 3 or "fast" will turn on a faster collision detection algorithm which',
	    'is only compatible with the default "left" sorting order.',
	    'A value of 0 suppresses collision control entirely.'],
	bump_limit => [
	    'integer',
	    -1,
	    'This option will cause bumping to stop after the indicated number of features',
	    'pile up. Subsequent collisions will not be bumped.'],
	feature_limit => [
	    'integer',
	    0,
	    'This option will set an upper bound on the number of features to be displayed.',
	    'For this to work properly, features must be added one at a time using add_feature().'],
	hbumppad => [
	    'integer',
	    2,
	    'Ordinarily collison control prevents two features from overlapping if they come within',
	    '2 pixels of each other. This option allows you to change this value to give glyphs',
	    'more or less breathing space on the left and right.'
	    ],
	hilite => [
	    'color',
	    undef,
	    'Highlight the glyph in the indicated color. Usually used as a callback to',
	    'selectively highlight glyphs that meet certain criteria.'],
	link => [
	    'string',
	    undef,
	    'When generating an imagemap, specify the pattern or callback for formatting',
	    'the link URL associated with the glyph.'],
	title => [
	    'string',
	    undef,
	    'When generating an imagemap, specify the pattern or callback for formatting',
	    'the link title associated with the glyph.'],
	target => [
	    'string',
	    undef,
	    'When generating an imagemap, specify the pattern or callback for formatting',
	    'the link target associated with the glyph.'],
    };
}

# return a demo feature for the user to play with
# The feature must not be longer than 500 bp for this to work.
# Default is to return nothing.
sub demo_feature {
    return;
}


# a bumpable graphical object that has bumpable graphical subparts

# args:  -feature => $feature_object (may contain subsequences)
#        -factory => $factory_object (called to create glyphs for subsequences)
# In this scheme, the factory decides based on stylesheet information what glyph to
# draw and what configurations options to us. This allows for heterogeneous tracks.
sub new {
  my $class = shift;
  my %arg = @_;

  my $feature = $arg{-feature} or $class->throw("No feature $class");
  my $factory = $arg{-factory} || $class->default_factory;
  my $level   = $arg{-level} || 0;
  my $flip    = $arg{-flip};

  my $self = bless {},$class;
  $self->{feature} = $feature;
  $self->{factory} = $factory;
  $self->{level}   = $level;
  $self->{flip}++  if $flip;
  $self->{top} = 0;

  my $panel   = $factory->panel;
  my $p_start = $panel->start;
  my $p_end   = $panel->end;

  my @subfeatures;
  my @subglyphs;

  warn $self    if DEBUG;
  warn $feature if DEBUG;

  @subfeatures         = $self->subfeat($feature);

  if ($self->option('ignore_sub_part')) {
    my @tmparray;
    foreach (@subfeatures) {
      my $type = $_->method;

      my @ignore_list = split /\s+/, $self->option('ignore_sub_part');
      my $ignore_str  = join('|', @ignore_list);

      unless ($type =~ /$ignore_str/) {
        push @tmparray, $_;
      }
    }
    @subfeatures = @tmparray;
  }

  my @visible_subfeatures = grep {$p_start <= $_->end && $p_end >= $_->start} @subfeatures;

  $self->feature_has_subparts(@subfeatures>0);

  if (@visible_subfeatures) {
    # dynamic glyph resolution
    @subglyphs = map { $_->[0] }
          sort { $a->[1] <=> $b->[1] }
	    map { [$_, $_->left ] }
	      $self->make_subglyph($level+1,@visible_subfeatures);
    $self->{feature_count} = scalar @subglyphs;
    $self->{parts}         = \@subglyphs;
  }

#  warn "type=",$feature->type,", glyph=$self, subglyphs=@subglyphs";

  my ($start,$stop) = ($self->start, $self->stop);
  if (defined $start && defined $stop && $start ne '') {  # more paranoia
    ($start,$stop) = ($stop,$start) if $start > $stop;  # sheer paranoia
    # the +1 here is critical for allowing features to meet nicely at nucleotide resolution
    my ($left,$right) = $factory->map_pt($start,$stop+1);
    $self->{left}    = $left;
    $self->{width}   = $right - $left + 1;
  }

  if (@subglyphs) {
      my $l            = $subglyphs[0]->left;
      # this clashes with the pad_left calculation and is unecessary
      # $self->{left}    = $l if !defined($self->{left}) || $l < $self->{left};
      my $right        = (
			  sort { $b<=>$a } 
			  map {$_->right} @subglyphs)[0];
      my $w            = $right - $self->{left} + 1;
      # this clashes with the pad_right calculation and is unecessary
      # $self->{width}   = $w if !defined($self->{width}) || $w > $self->{width};
  }

  $self->{point} = $arg{-point} ? $self->height : undef;

  return $self;
}

# override this if you want to make a particular type of glyph rather than have the
# factory decide.
sub make_subglyph {
  my $self    = shift;
  my $level   = shift;
  my $factory = $self->{factory};
  $factory->make_glyph($level,@_);
}

sub parts      {
  my $self = shift;
  return unless $self->{parts};
  return wantarray ? @{$self->{parts}} : $self->{parts};
}

sub feature_count {
    my $self = shift;
    return $self->{feature_count} || 0;
}

sub features_clipped {
    my $self = shift;
    my $d = $self->{features_clipped};
    $self->{features_clipped} = shift if @_;
    return $d;
}

sub _bump_feature_count {
    my $self  = shift;
    my $count = shift || 1;
    return $self->{feature_count} += $count;
}

# this is different than parts(). parts() will return subglyphs
# that are contained within the current viewing range. feature_has_subparts()
# will return true if the feature has any subparts, even if they are off the
# screen.
sub feature_has_subparts {
  my $self = shift;

  return $self->{feature_has_subparts} = shift if @_;
  return 0 if $self->maxdepth == 0;
  my $feature = $self->feature;
  return 1 if $feature->can('compound') && $feature->compound;
  return $self->{feature_has_subparts};
}

sub feature { shift->{feature} }
sub factory { shift->{factory} }
sub panel   { shift->factory->panel }
sub point   { shift->{point}   }
sub scale   { shift->factory->scale }
sub flip    {
  my $self      = shift;
  my $d         = $self->{flip};
  $self->{flip} = shift if @_;
  $d;
}
sub start   {
  my $self = shift;
  return $self->{start} if exists $self->{start};
  if ($self->{flip}) {
    $self->{start} = defined $self->{feature}->end
                     ? $self->panel->end + 1 - $self->{feature}->end
                     : 0;
  } else {
    $self->{start} = defined $self->{feature}->start
                     ? $self->{feature}->start
		     : $self->panel->offset - 1
  }

  return $self->{start};
}

sub stop    {
  my $self = shift;
  return $self->{stop} if exists $self->{stop};
  if ($self->{flip}) {
    $self->{stop} = defined $self->{feature}->start 
      ? $self->panel->end + 1 - $self->{feature}->start
      : $self->panel->offset - 1;
  } else {
    $self->{stop} = defined $self->{feature}->end
      ? $self->{feature}->end
      : $self->panel->offset+$self->panel->length+1;
  }

  return $self->{stop}
}
sub end     { shift->stop }
sub length { my $self = shift; $self->stop - $self->start };
sub score {
    my $self = shift;
    return $self->{score} if exists $self->{score};
    return $self->{score} = ($self->{feature}->score || 0);
}
sub strand {
    my $self = shift;
    return $self->{strand} if exists $self->{strand};
    return $self->{strand} = ($self->{feature}->strand || 0);
}
sub map_pt  { shift->{factory}->map_pt(@_) }
sub map_no_trunc { shift->{factory}->map_no_trunc(@_) }

# add a feature (or array ref of features) to the list
sub add_feature {
  my $self       = shift;
  my $factory    = $self->factory;

  for my $feature (@_) {
    if (ref $feature eq 'ARRAY') {
	$self->add_group(@$feature);
	$self->_bump_feature_count(scalar @$feature);
    } else {
      warn $factory if DEBUG;
      my $parts   = $self->{parts} ||= [];
      my $limit   = $self->feature_limit;
      my $count   = $self->_bump_feature_count;

      if (!$limit || $count <= $limit) {
	  push @$parts,$factory->make_glyph(0,$feature);
      } elsif (rand() < $limit/$count) {
	  $self->features_clipped(1);
	  $parts->[rand @$parts] = $factory->make_glyph(0,$feature); # subsample
      }

    }
  }
}

# link a set of features together so that they bump as a group
sub add_group {
  my $self = shift;
  my @features = ref($_[0]) eq 'ARRAY' ? @{$_[0]} : @_;
  my $f    = Bio::Graphics::Feature->new(
					 -segments=>\@features,
					 -type => 'group',
					);
  $self->add_feature($f);
  $f;
}

sub top {
  my $self = shift;
  my $g = $self->{top};
  $self->{top} = shift if @_;
  $g;
}
sub left {
  my $self = shift;
  return $self->{left} - $self->pad_left;
}
sub right {
  my $self = shift;
  return $self->left + $self->layout_width - 1;
}
sub bottom {
  my $self = shift;
  $self->top + $self->layout_height - 1;
}
sub height {
  my $self = shift;
  return $self->{height} if exists $self->{height};
  my $baseheight = $self->option('height');  # what the factory says
  return $self->{height} = $baseheight;
}
sub width {
  my $self = shift;
  my $g = $self->{width};
  $self->{width} = shift if @_;
  return $g;
}
sub layout_height {
  my $self = shift;
  return $self->layout;
}
sub layout_width {
  my $self = shift;
  return $self->width + $self->pad_left + $self->pad_right;
}

# returns the rectangle that surrounds the physical part of the
# glyph, excluding labels and other "extra" stuff
sub calculate_boundaries {return shift->bounds(@_);}

sub bounds {
  my $self = shift;
  my ($dx,$dy) = @_;
  $dx += 0; $dy += 0;
  ($dx + $self->{left},
   $dy + $self->top    + $self->pad_top,
   $dx + $self->{left} + $self->{width} - 1,
   $dy + $self->bottom - $self->pad_bottom);
}

sub box {
  my $self = shift;
  my @result = ($self->left,$self->top,$self->right,$self->bottom);
  return @result;
}

sub unfilled_box {
  my $self = shift;
  my $gd   = shift;
  my ($x1,$y1,$x2,$y2,$fg,$bg,$lw) = @_;
  $lw = $self->linewidth;

  unless ($fg) {
      $fg ||= $self->fgcolor;
  $fg = $self->set_pen($lw,$fg) if $lw > 1;
  }

  unless ($bg) {
      $bg ||= $self->bgcolor;
      $bg = $self->set_pen($lw,$bg) if $lw > 1;
  }

  # draw a box
  $gd->rectangle($x1,$y1,$x2,$y2,$fg);

  # if the left end is off the end, then cover over
  # the leftmost line
  my ($width) = $gd->getBounds;

  $gd->line($x1,$y1+$lw,$x1,$y2-$lw,$bg)
    if $x1 < $self->panel->pad_left;

  $gd->line($x2,$y1+$lw,$x2,$y2-$lw,$bg)
    if $x2 > $width - $self->panel->pad_right;
}

# return boxes surrounding each part
sub boxes {
  my $self = shift;

  my ($left,$top,$parent) = @_;
  $top  += 0; $left += 0;
  my @result;

  $self->layout;
  $parent         ||= $self;
  my $subparts = $self->box_subparts || 0;

  for my $part ($self->parts) {
    my $type   = $part->feature->primary_tag || '';
    if ($type eq 'group' or $subparts > $part->level) {
      push @result,$part->boxes($left,$top+$self->top+$self->pad_top,$parent);
      next if $type eq 'group';
    }
    my ($x1,$y1,$x2,$y2) = $part->box;
    $x2++ if $x1==$x2;
    push @result,[$part->feature,
		  $left + $x1,$top+$self->top+$self->pad_top+$y1,
		  $left + $x2,$top+$self->top+$self->pad_top+$y2,
		  $parent];
  }

  return wantarray ? @result : \@result;
}

sub box_subparts {
  my $self = shift;
  return $self->{box_subparts} if exists $self->{box_subparts};
  return $self->{box_subparts} = $self->_box_subparts;
}

sub _box_subparts { shift->option('box_subparts') }

# this should be overridden for labels, etc.
# allows glyph to make itself thicker or thinner depending on
# domain-specific knowledge
sub pad_top {
  my $self = shift;
  return 0;
}
sub pad_bottom {
  my $self = shift;
  return 0;
}
sub pad_left {
  my $self = shift;
  my @parts = $self->parts or return 0;
  my $max = 0;
  foreach (@parts) {
    my $pl = $_->pad_left;
    $max = $pl if $max < $pl;
  }
  $max;
}
sub pad_right {
  my $self = shift;
  my @parts = $self->parts or return 0;
  my $max = 0;
  foreach (@parts) {
    my $pr = $_->pad_right;
    $max = $pr if $max < $pr;
  }
  $max;
}

# move relative to parent
sub move {
  my $self = shift;
  my ($dx,$dy) = @_;
  $self->{left} += $dx;
  $self->{top}  += $dy;

  # because the feature parts use *absolute* not relative addressing
  # we need to move each of the parts horizontally, but not vertically
  $_->move($dx,0) foreach $self->parts;
}

# get an option
sub option {
  my $self = shift;
  my $option_name = shift;
  my @args = ($option_name,@{$self}{qw(partno total_parts)});
  my $factory = $self->{factory} or return;
  return $factory->option($self,@args)
}

# get an option that might be a code reference
sub code_option {
  my $self = shift;
  my $option_name = shift;
  my $factory = $self->factory or return;
  $factory->get_option($option_name);
}

# set an option globally
sub configure {
  my $self = shift;
  my $factory = $self->factory;
  my $option_map = $factory->option_map;
  while (@_) {
    my $option_name  = shift;
    my $option_value = shift;
    ($option_name = lc $option_name) =~ s/^-//;
    $option_map->{$option_name} = $option_value;
  }
}

# some common options
sub color {
  my $self = shift;
  my $color = shift;
  my $index = $self->option($color);
  # turn into a color index
  return $self->translate_color($index) if defined $index;
  return 0;
}

sub translate_color {
  my $self = shift;
  my $color = shift;
  # turn into a color index
  return $self->factory->translate_color($color);
}

# return value:
#              0    no bumping
#              +1   bump down
#              -1   bump up
#              +2   simple bump down
#              -2   simple bump up
#              +3   optimized (fast) bumping
sub bump {
  my $self = shift;
  my $bump = $self->option('bump');
  return $bump;
}

# control horizontal and vertical collision control
sub hbumppad {
  my $self = shift;
  return $self->{_hbumppad} if exists $self->{_hbumppad};
  my $hbumppad = $self->option('hbumppad');
  $hbumppad    = 2 unless defined $hbumppad;
  return $self->{_hbumppad}= $hbumppad;
}

# we also look for the "color" option for Ace::Graphics compatibility
sub fgcolor {
  my $self  = shift;
  my $fgcolor = $self->option('color') || $self->option('fgcolor');

  my $index   = $fgcolor;
  $index = 'black' unless defined $index;

  if ($index eq 'featureRGB') {
      ($index) = $self->feature->get_tag_values('RGB');
      $index ||= $fgcolor;
  } elsif ($index eq 'featureScore') {
      $index = $self->score_to_color;
  }

  $self->factory->translate_color($index);
}

#add for compatibility
sub fillcolor {
    my $self = shift;
    return $self->bgcolor;
}

# we also look for the "fillcolor" option for Ace::Graphics compatibility
sub bgcolor {
  my $self = shift;
  my $bgcolor;
  ($bgcolor) = $self->feature->get_tag_values('bgcolor') if $self->feature->has_tag('bgcolor'); 
  $bgcolor    ||= $self->option('bgcolor'); # Let feature attribute override color
  my $index     = defined $bgcolor ? $bgcolor : $self->option('fillcolor');
  $index        = 'white' unless defined $index;

  if ($index eq 'featureRGB') {
      ($index) = $self->feature->get_tag_values('RGB');
      $index ||= $bgcolor;
  } elsif ($index eq 'featureScore') {
      $index = $self->score_to_color;
  }

  $self->factory->translate_color($index);
}

# for compatibility with UCSC genome browser useScore option
sub score_to_color {
    my $self = shift;
    my $feature   = $self->feature;

    my ($score)   = $feature->can('score') 
                  ? $feature->score
                  : $feature->get_tag_values('score');

    my $max_score = 945;  # defined by UCSC docs
    my $min_score = 166;
    my $min_gray = 0;
    my $max_gray = 255;
    my $rgb_per_score = ($max_gray-$min_gray)/($max_score-$min_score);

    $score = $max_score if $score > $max_score;
    $score = $min_score if $score < $min_score;

    my $gray = int($max_gray - ($min_gray + ($score-$min_score) * $rgb_per_score));
    return "rgb($gray,$gray,$gray)";
}

sub getfont {
  my $self    = shift;
  my $option  = shift || 'font';
  my $default = shift;

  my $font = $self->option($option) || $default;
  return unless $font;

  my $img_class = $self->image_class;

  unless (UNIVERSAL::isa($font,$img_class . '::Font')) {
    my $ref    = {
		  gdTinyFont       => $img_class->gdTinyFont(),
		  gdSmallFont      => $img_class->gdSmallFont(),
		  gdMediumBoldFont => $img_class->gdMediumBoldFont(),
		  gdLargeFont      => $img_class->gdLargeFont(),
		  gdGiantFont      => $img_class->gdGiantFont(),
		  sanserif         => $img_class->gdSmallFont(),
    		 };

    my $gdfont = $ref->{$font} || $ref->{gdSmallFont};
    $self->configure($option => $gdfont);
    return $gdfont;
  }
  return $font;
}

sub tkcolor { # "track color"
  my $self = shift;
  $self->option('tkcolor') or return;
  return $self->color('tkcolor')
}
sub image_class { shift->{factory}->{panel}->{image_class}; }
sub polygon_package { shift->{factory}->{panel}->{polygon_package}; }

sub layout_sort {
    my $self = shift;
    my $sortfunc;

    my $opt = $self->code_option("sort_order");

    if (!$opt) {
       $sortfunc = sub { $a->start <=> $b->start };
    } elsif (ref $opt eq 'CODE') {
      $self->throw('sort_order subroutines must use the $$ prototype') 
	  unless prototype($opt) eq '$$';
      $sortfunc = $opt;
    } elsif ($opt =~ /^sub\s+\{/o) {
       $sortfunc = eval $opt;
    } else {
       # build $sortfunc for ourselves:
       my @sortbys = split(/\s*\|\s*/o, $opt);
       $sortfunc = 'sub { ';
       my $sawleft = 0;

       # not sure I can make this schwartzian transformed
       for my $sortby (@sortbys) {
	 if ($sortby eq "left" || $sortby eq "default") {
	   $sortfunc .= '($a->start <=> $b->start) || ';
	   $sawleft++;
	 } elsif ($sortby eq "right") {
	   $sortfunc .= '($a->end <=> $b->end) || ';
	 } elsif ($sortby eq "low_score") {
	   $sortfunc .= '($a->score <=> $b->score) || ';
	 } elsif ($sortby eq "high_score") {
	   $sortfunc .= '($b->score <=> $a->score) || ';
	 } elsif ($sortby eq "longest") {
	   $sortfunc .= '(($b->length) <=> ($a->length)) || ';
	 } elsif ($sortby eq "shortest") {
	   $sortfunc .= '(($a->length) <=> ($b->length)) || ';
	 } elsif ($sortby eq "strand") {
	   $sortfunc .= '($b->strand <=> $a->strand) || ';
	 } elsif ($sortby eq "name") {
	   $sortfunc .= '($a->feature->display_name cmp $b->feature->display_name) || ';
	 }
       }
       unless ($sawleft) {
           $sortfunc .= ' ($a->left <=> $b->left) ';
       } else {
           $sortfunc .= ' 0';
       }
       $sortfunc .= '}';
       $sortfunc = eval $sortfunc;
    }

    # cache this
    # $self->factory->set_option(sort_order => $sortfunc);
    my @things = sort $sortfunc @_;
    return @things;
}

# handle collision detection
sub layout {
  my $self = shift;
  return $self->{layout_height} if exists $self->{layout_height};

  my @parts = $self->parts;
  return $self->{layout_height} = 
      $self->height + $self->pad_top + $self->pad_bottom unless @parts;

  my $bump_direction = $self->bump;
  my $bump_limit     = $self->bump_limit || -1;

  $bump_direction = 'fast' if 
      $bump_direction && 
      $bump_direction == 1 && 
      !$self->code_option('sort_order');

  $_->layout foreach @parts;  # recursively lay out

  # no bumping requested, or only one part here
  if (@parts == 1 || !$bump_direction) {
    my $highest = 0;
    foreach (@parts) {
      my $height = $_->layout_height;
      $highest   = $height > $highest ? $height : $highest;
    }
    return $self->{layout_height} = $highest + $self->pad_top + $self->pad_bottom;
  }

  if ($bump_direction eq 'fast' or $bump_direction == 3) {
      return $self->{layout_height} = $self->optimized_layout(\@parts)
	  + $self->pad_bottom + $self->pad_top -1;# - $self->top  + 1;
  }

  my (%bin1,%bin2);
  my $limit          = 0;
  my $recent_pos     = 0;
  my $max_pos        = 0;

  for my $g ($self->layout_sort(@parts)) {

    my $height = $g->{layout_height};

    # Simple +/- 2 bumping.  Every feature gets its very own line
    if (abs($bump_direction) >= 2) {
      $g->move(0,$limit);
      $limit += $height + BUMP_SPACING if $bump_direction > 0;
      $limit -= $height + BUMP_SPACING if $bump_direction < 0;
      next;
    }

    # we get here for +/- 1 bumping
    my $pos       = 0;
    my $bumplevel = 0;
    my $left   = $g->left;
    my $right  = $g->right;

    my $search_mode = 'down';

    while (1) {

	# stop bumping if we've gone too far down
	if ($bump_limit > 0 && $bumplevel++ >= $bump_limit) {
	    $g->{overbumped}++;  # this flag can be used to suppress label and description
	    foreach ($g->parts) {
		$_->{overbumped}++;
	    }
	    last;
	}

	# look for collisions
	my $bottom      = $pos + $height;
	my $collision   = $self->collides(\%bin1,CM1,CM2,$left,$pos,$right,$bottom) or last;
	# my $collision = $self->collides(\%bin2,CM3,CM4,$left,$pos,$right,$bottom) or last;
	
	if ($bump_direction > 0) {
	    $pos = $collision->[3] + BUMP_SPACING;    # collision, so bump
	} else {
	    $pos -= BUMP_SPACING;
	}
	
	$pos++ if $pos % 2; # correct for GD rounding errors
    }
    
    $g->move(0,$pos);
    $self->add_collision(\%bin1,CM1,CM2,$left,$g->top,$right,$g->bottom);
    
    $recent_pos = $pos;
    $max_pos    = $pos if $pos > $max_pos;
  }

  # If -1 bumping was allowed, then normalize so that the top glyph is at zero
  if ($bump_direction < 0) {
    my $topmost;
    foreach (@parts) {
      my $top  = $_->top;
      $topmost = $top if !defined($topmost) or $top < $topmost;
    }
    my $offset = - $topmost;
    $_->move(0,$offset) foreach @parts;
  }

  # find new height
  my $bottom = 0;
  foreach (@parts) {
    $bottom = $_->bottom if $_->bottom > $bottom;
  }
  return $self->{layout_height} = 
      $self->pad_bottom + $self->pad_top + $bottom - $self->top  + 1;
}

# the $%occupied structure is a hash of {left,top} = [left,top,right,bottom]
sub collides {
  my $self = shift;
  my ($occupied,$cm1,$cm2,$left,$top,$right,$bottom) = @_;
  my @keys = $self->_collision_keys($cm1,$cm2,$left,$top,$right,$bottom);
  my $hspacing = $self->hbumppad;
  my $collides = 0;
  for my $k (@keys) {
    next unless exists $occupied->{$k};
    for my $bounds (@{$occupied->{$k}}) {
      my ($l,$t,$r,$b) = @$bounds;
      next unless $right+$hspacing > $l and $left-$hspacing < $r 
	and $bottom >= $t and $top <= $b;
      $collides = $bounds;
      last;
    }
  }
  $collides;
}

sub add_collision {
  my $self = shift;
  my ($occupied,$cm1,$cm2,$left,$top,$right,$bottom) = @_;
  my $value = [$left,$top,$right,$bottom];
  my @keys = $self->_collision_keys($cm1,$cm2,@$value);
  push @{$occupied->{$_}},$value foreach @keys;
}

sub _collision_keys {
  my $self = shift;
  my ($binx,$biny,$left,$top,$right,$bottom) = @_;
  my @keys;
  my $bin_left   = int($left/$binx);
  my $bin_right  = int($right/$binx);
  my $bin_top    = int($top/$biny);
  my $bin_bottom = int($bottom/$biny);
  for (my $x=$bin_left;$x<=$bin_right; $x++) {
    for (my $y=$bin_top;$y<=$bin_bottom; $y++) {
      push @keys,join(',',$x,$y);
    }
  }
  @keys;
}

# jbrowse layout that acts by keeping track of contours of the free space
sub optimized_layout {
    my $self = shift;
    my $parts = shift;

    my $hspacing   = $self->hbumppad;
    my $bump_limit = $self->bump_limit;

    my @rects = map {
	$_ => [
	    $_->left,
	    $_->right + $hspacing,
	    $_->{layout_height}+BUMP_SPACING
	    ]
    } $self->layout_sort(@$parts);
    
    my $layout = Bio::Graphics::Layout->new(0,$self->panel->right);
    my $overbumped;
    while (@rects) {
	my ($part,$rect) = splice(@rects,0,2);
	my $offset = $layout->addRect("$part",@$rect);
	if ($overbumped && $offset > $overbumped) {
	    $part->move(0,$overbumped);
	    next;
	}
	$part->move(0,$offset);
	$overbumped = $offset if $bump_limit > 0 && $offset >= $bump_limit * $rect->[2];
    }

    return $overbumped && $overbumped < $layout->totalHeight ? $overbumped : $layout->totalHeight;
}

sub draw {
  my $self = shift;
  my $gd   = shift;
  my ($left,$top,$partno,$total_parts) = @_;

  push @FEATURE_STACK,$self->feature;

  $self->panel->startGroup($gd);

  my $connector = $self->connector;
  if (my @parts = $self->parts) {

    # invoke sorter if user wants to sort always and we haven't already sorted
    # during bumping.
    @parts = $self->layout_sort(@parts) if !$self->bump && $self->option('always_sort');

    my $x = $left;
    my $y = $top  + $self->top + $self->pad_top;

    $self->draw_connectors($gd,$x,$y) if $connector && $connector ne 'none';

    my $last_x;
    for (my $i=0; $i<@parts; $i++) {
      # lie just a little bit to avoid lines overlapping and make the picture prettier
      my $fake_x = $x;
      $fake_x-- if defined $last_x && $parts[$i]->left - $last_x == 1;
      $parts[$i]->draw($gd,$fake_x,$y,$i,scalar(@parts));
      $last_x = $parts[$i]->right;
    }
  }

  else {  # no part
    $self->draw_connectors($gd,$left,$top)
      if $connector && $connector ne 'none'; # && $self->{level} == 0;
    $self->draw_component($gd,$left,$top,$partno,$total_parts) unless $self->feature_has_subparts;
  }

  $self->panel->endGroup($gd);

  pop @FEATURE_STACK;

}

sub connector { return }

sub parts_overlap {
    my $self = shift;
    return $self->option('parts_overlap');
}  

sub bump_limit { shift->option('bump_limit') }

# the "level" is the level of testing of the glyph
# groups are level -1, top level glyphs are level 0, subcomponents are level 1 and so forth.
sub level {
  shift->{level};
}

# return the feature's parent;
sub parent_feature {
    my $self      = shift;
    my $ancestors = shift;
    $ancestors    = 1 unless defined $ancestors;

    return unless @FEATURE_STACK;
    my $index    = $#FEATURE_STACK - $ancestors;
    return unless $index >= 0;
    return $FEATURE_STACK[$index];
}

sub draw_connectors {
  my $self = shift;

  return if $self->{overbumped};
  my $gd = shift;
  my ($dx,$dy) = @_;
  my @parts = sort { $a->left <=> $b->left } $self->parts;
  for (my $i = 0; $i < @parts-1; $i++) {
    # don't let connectors double-back on themselves
    next if ($parts[$i]->bounds)[2] > ($parts[$i+1]->bounds)[0] && !$self->parts_overlap;
    $self->_connector($gd,$dx,$dy,$parts[$i]->bounds,$parts[$i+1]->bounds);
  }

  # extra connectors going off ends
  if (@parts) {
    my($x1,$y1,$x2,$y2) = $self->bounds(0,0);
    my($xl,$xt,$xr,$xb) = $parts[0]->bounds;
    $self->_connector($gd,$dx,$dy,$x1,$xt,$x1,$xb,$xl,$xt,$xr,$xb)      if $x1 < $xl;

    @parts = sort {$a->right<=>$b->right} @parts;
    my ($xl2,$xt2,$xr2,$xb2) = $parts[-1]->bounds;
    if ($x2 > $xr2) {
	$self->_connector($gd,$dx,$dy,$parts[-1]->bounds,$x2,$xt2,$x2,$xb2);
    }
  } else {
      # This code draws the connectors from end-to-end when there are no parts in
      # view (e.g. zoomed into a gap in an alignment).
      my ($x1,$y1,$x2,$y2) = $self->bounds($dx,$dy);
      $self->draw_connector($gd,$y1,$y2,$x1,$y1,$y2,$x2);
  }

}

# return true if this feature should be highlited
sub hilite_color {
  my $self         = shift;
  return     if $self->level; # only highlite top level glyphs
  my $index   = $self->option('hilite') or return;
  $self->factory->translate_color($index);
}

sub draw_highlight {
  my $self              = shift;
  my ($gd,$left,$top)   = @_;
  my $color  = $self->hilite_color or return;
  my @bounds = $self->bounds;
  $gd->filledRectangle($bounds[0]+$left - 3,
		       $bounds[1]+$top  - 3,
		       $bounds[2]+$left + 3,
		       $bounds[3]+$top  + 3,
		       $color);
}

sub _connector {
  my $self = shift;
  my ($gd,
      $dx,$dy,
      $xl,$xt,$xr,$xb,
      $yl,$yt,$yr,$yb) = @_;
  my $left   = $dx + $xr;
  my $right  = $dx + $yl;
  my $top1     = $dy + $xt;
  my $bottom1  = $dy + $xb;
  my $top2     = $dy + $yt;
  my $bottom2  = $dy + $yb;

  # restore this comment if you don't like the group dash working
  # its way backwards.
  return if $right-$left < 1 && !$self->isa('Bio::Graphics::Glyph::group');

  $self->draw_connector($gd,
			$top1,$bottom1,$left,
			$top2,$bottom2,$right,
		       );
}

sub draw_connector {
  my $self   = shift;
  my $gd     = shift;
  my $color          = $self->connector_color;
  my $connector_type = $self->connector or return;

  if ($connector_type eq 'hat') {
    $self->draw_hat_connector($gd,$color,@_);
  } elsif ($connector_type eq 'solid') {
    $self->draw_solid_connector($gd,$color,@_);
  } elsif ($connector_type eq 'dashed') {
    $self->draw_dashed_connector($gd,$color,@_);
  } elsif ($connector_type eq 'quill') {
    $self->draw_quill_connector($gd,$color,@_);
  } elsif ($connector_type eq 'crossed') {
    $self->draw_crossed_connector($gd,$color,@_);
  } else {
    ; # draw nothing
  }
}

sub draw_hat_connector {
  my $self = shift;
  my $gd   = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  cluck "gd object is $gd" unless ref $gd;

  my $center1  = ($top1 + $bottom1)/2;
  my $quarter1 = $top1 + ($bottom1-$top1)/4;
  my $center2  = ($top2 + $bottom2)/2;
  my $quarter2 = $top2 + ($bottom2-$top2)/4;

  if ($center1 != $center2) {
    $self->draw_solid_connector($gd,$color,@_);
    return;
  }

  if ($right - $left > 4) {  # room for the inverted "V"
      my $middle = $left + int(($right - $left)/2);
      $gd->line($left,$center1,$middle,$top1,$color);
      $gd->line($middle,$top1,$right-1,$center1,$color);
    } elsif ($right-$left > 1) { # no room, just connect
      $gd->line($left,$quarter1,$right-1,$quarter1,$color);
    }

}

sub draw_solid_connector {
  my $self = shift;
  my $gd   = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  my $center1  = ($top1 + $bottom1)/2;
  my $center2  = ($top2 + $bottom2)/2;

  $gd->line($left,$center1,$right,$center2,$color);
}

sub draw_dashed_connector {
  my $self = shift;
  my $gd   = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  my $center1  = ($top1 + $bottom1)/2;
  my $center2  = ($top2 + $bottom2)/2;
  my $image_class   = $self->panel->image_class;
  my $gdTransparent = $image_class->gdTransparent;
  my $gdStyled      = $image_class->gdStyled;
  $gd->setStyle($color,$color,$gdTransparent,$gdTransparent);
  $gd->line($left,$center1,$right,$center2,$gdStyled);
}

sub draw_quill_connector {
  my $self = shift;
  my $gd   = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  my $center1  = ($top1 + $bottom1)/2;
  my $center2  = ($top2 + $bottom2)/2;

  $gd->line($left,$center1,$right,$center2,$color);
  my $direction = $self->feature->strand;
  return unless $direction;
  $direction *= -1 if $self->{flip};

  if ($direction > 0) {
    my $start = $left+4;
    my $end   = $right-1;
    for (my $position=$start; $position <= $end; $position += QUILL_INTERVAL) {
      $gd->line($position,$center1,$position-2,$center1-2,$color);
      $gd->line($position,$center1,$position-2,$center1+2,$color);
    }
  } else {
    my $start = $left+1;
    my $end   = $right-4;
    for (my $position=$start; $position <= $end; $position += QUILL_INTERVAL) {
      $gd->line($position,$center1,$position+2,$center1-2,$color);
      $gd->line($position,$center1,$position+2,$center1+2,$color);
    }
  }
}

sub draw_crossed_connector {
  my $self = shift;
  my $gd = shift;
  my $color = shift;
  my ($top1,$bottom1,$left,$top2,$bottom2,$right) = @_;

  #Draw the horizontal line
  my $center1  = ($top1 + $bottom1)/2;
  my $center2  = ($top2 + $bottom2)/2;

  $gd->line($left,$center1,$right,$center2,$color);

  #Extra validations
  ($left, $right)   = ($right, $left)   if ($right < $left);
  ($top1, $bottom1) = ($bottom1, $top1) if ($bottom1 < $top1);
  ($top2, $bottom2) = ($bottom2, $top2) if ($bottom2 < $top2);

  #Draw the "X"
  my $middle = int(($right - $left) / 2) + $left;
  my $midLen = int(($bottom1 - $top1) / 2);

  $gd->line($middle-$midLen,$top1,   $middle+$midLen,$bottom2,$color);
  $gd->line($middle-$midLen,$bottom1,$middle+$midLen,$top2,$color);
}

sub filled_box {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2,$bg,$fg,$lw) = @_;

  $bg ||= $self->bgcolor;
  $fg ||= $self->fgcolor;
  $lw ||= $self->option('linewidth') || 1;
  $x2 = $x1+1 if abs($x2-$x1) < 1;

  $gd->filledRectangle($x1,$y1,$x2,$y2,$bg);
  $fg = $self->set_pen($lw,$fg) if $lw > 1;

  # draw a box
  $gd->rectangle($x1,$y1,$x2,$y2,$fg);

  # if the left end is off the end, then cover over
  # the leftmost line
  $self->blunt($gd,$x1,$y1,$x2,$y2,$bg,$fg,$lw);
}

sub blunt {
    my $self = shift;
    my $gd   = shift;
    my ($x1,$y1,$x2,$y2,$bg,$fg,$lw) = @_;

    # if the left end is off the end, then cover over
    # the leftmost line
    my ($width) = $gd->getBounds;

    $bg = $self->set_pen($lw,$bg) if $lw > 1;

    $gd->line($x1,$y1+$lw,$x1,$y2-$lw,$bg)
	if $x1 < $self->panel->pad_left;

    $gd->line($x2,$y1+$lw,$x2,$y2-$lw,$bg)
	if $x2 > $width - $self->panel->pad_right;
}

sub filled_oval {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2,$bg,$fg,$lw) = @_;
  my $cx = ($x1+$x2)/2;
  my $cy = ($y1+$y2)/2;

  $fg ||= $self->fgcolor;
  $bg ||= $self->bgcolor;
  $lw ||= $self->linewidth;

  $fg = $self->set_pen($lw) if $lw > 1;

  # Maintain backwards compatability with gd 1.8.4
  # which does not support the ellipse methods.
  # can() method fails with GD::SVG...
  if ($gd->can('ellipse') || $gd =~ /SVG/ ) {
    $gd->filledEllipse($cx,$cy,$x2-$x1,$y2-$y1,$bg);
    # Draw the edge around the ellipse
    $gd->ellipse($cx,$cy,$x2-$x1,$y2-$y1,$fg);
  } else {
    $gd->arc($cx,$cy,$x2-$x1,$y2-$y1,0,360,$fg);
    $gd->fillToBorder($cx,$cy,$fg,$bg);
  }
}

sub oval {
  my $self = shift;
  my $gd = shift;
  my ($x1,$y1,$x2,$y2) = @_;
  my $cx = ($x1+$x2)/2;
  my $cy = ($y1+$y2)/2;

  my $fg = $self->fgcolor;
  my $linewidth = $self->linewidth;
  $fg = $self->set_pen($linewidth) if $linewidth > 1;

  # Maintain backwards compatability with gd 1.8.4 which does not
  # support the ellipse method.
  if ($gd->can('ellipse') || $gd =~ /SVG/ ) {
    $gd->ellipse($cx,$cy,$x2-$x1,$y2-$y1,$fg);
  } else {
    $gd->arc($cx,$cy,$x2-$x1,$y2-$y1,0,360,$fg);
  }
}

sub filled_arrow {
  my $self = shift;
  my $gd   = shift;
  my $orientation = shift;
  my ($x1,$y1,$x2,$y2,$fg,$bg,$force)  = @_;

  $orientation *= -1 if $self->{flip};

  my ($width) = $gd->getBounds;
  my $indent  = $y2-$y1 < $x2-$x1 ? $y2-$y1 : ($x2-$x1)/2;

  my $panel        = $self->panel;
  my $offend_left  = $x1 < $panel->pad_left;
  my $offend_right = $x2 > $panel->width + $panel->pad_left;

  return $self->filled_box($gd,@_)
      if !$force &&
      (($orientation == 0)
       or ($x1 < 0 && $orientation < 0)
       or ($x2 > $width && $orientation > 0)
       or ($indent <= 0)
       or ($x2 - $x1 < 3)
       or ($offend_left && $orientation < 0)
       or ($offend_right && $orientation > 0));

  $fg   ||= $self->fgcolor;
  $bg   ||= $self->bgcolor;

  my $lw = $self->option('linewidth') || 1;
  $fg    = $self->set_pen($lw,$fg) if $lw > 1;

  my $pkg  = $self->polygon_package;
  my $poly = $pkg->new();
  if ($orientation >= 0) {
    $poly->addPt($x1,$y1);
    $poly->addPt($x2-$indent,$y1);
    $poly->addPt($x2,($y2+$y1)/2);
    $poly->addPt($x2-$indent,$y2);
    $poly->addPt($x1,$y2);
  } else {
    $poly->addPt($x2,$y1);
    $poly->addPt($x2,$y2);
    $poly->addPt($x1+$indent,$y2);
    $poly->addPt($x1,($y2+$y1)/2);
    $poly->addPt($x1+$indent,$y1);
  }
  $gd->filledPolygon($poly,$bg);
  $gd->polygon($poly,$fg);

  # blunt it a bit if off the end

  $self->blunt($gd,$x1,$y1,$x2,$y2,$bg,$fg,$lw) if 
       ($offend_left     && $orientation > 0)
       or ($offend_right && $orientation < 0);
}

sub linewidth {
  shift->option('linewidth') || 1;
}

sub fill {
  my $self = shift;
  my $gd   = shift;
  my ($x1,$y1,$x2,$y2) = @_;
  if ( ($x2-$x1) >= 2 && ($y2-$y1) >= 2 ) {
    $gd->fill($x1+1,$y1+1,$self->bgcolor);
  }
}
sub set_pen {
  my $self = shift;
  my ($linewidth,$color) = @_;
  $linewidth ||= $self->linewidth;
  $color     ||= $self->fgcolor;
  return $color unless $linewidth > 1;
  $self->panel->set_pen($linewidth,$color);
}

sub draw_component {
  my $self = shift;
  my ($gd,$left,$top,$partno,$total_parts) = @_;
  my($x1,$y1,$x2,$y2) = $self->bounds($left,$top);

  # clipping
  my $panel = $self->panel;
  return unless $x2 >= $panel->left and $x1 <= $panel->right;

  if ($self->stranded) {
    $self->filled_arrow($gd,
			$self->feature->strand,
			$x1, $y1,
			$x2, $y2)
  } else {
    $self->filled_box($gd,
		      $x1, $y1,
		      $x2, $y2)
  }
}

sub show_strand {
    my $self = shift;
    my $s = $self->option('strand_arrow');
    return $s if defined $s;
    return $self->option('stranded');
}
sub stranded {
  my $self = shift;
  my $s = $self->show_strand;
  return unless $s;
  return 1 unless $s eq 'ends';

  my $f       = $self->feature;
  my $strand  = $f->strand;
  $strand    *= -1 if $self->{flip};
  my $part_no = $self->{partno};
  my $parts   = $self->{total_parts};
  return ($strand > 0 && $part_no == $parts-1)
    ||   ($strand < 0 && $part_no == 0);
}


sub no_subparts {
  return shift->option('no_subparts');
}

sub maxdepth {
  my $self = shift;

  my $maxdepth =  $self->option('maxdepth');
  return $maxdepth if defined $maxdepth;

  # $feature->compound is an artefact from aggregators. Sadly, an aggregated feature can miss
  # parts that are out of the query range - this is a horrible mis-feature. Aggregated features have
  # a compound flag to hack around this.
  my $feature = $self->feature;
  return 1 if $feature->can('compound') && $feature->compound;

  return;
}

sub feature_limit {
    return shift->option('feature_limit') || 0;
}

sub exceeds_depth {
  my $self = shift;
  my $max_depth     = $self->maxdepth;
  return unless defined $max_depth;

  my $current_depth = $self->level || 0;
  return $current_depth >= $max_depth;
}

# memoize _subfeat -- it's a bottleneck with segments
sub subfeat {
  my $self    = shift;
  my $feature = shift;

  return $self->_subfeat($feature) unless ref $self;  # protect against class invocation

  return if $self->level == 0 && $self->no_subparts;
  return if $self->exceeds_depth;

  return @{$self->{cached_subfeat}{$feature}} if exists $self->{cached_subfeat}{$feature};
  my @ss = $self->_subfeat($feature);
  $self->{cached_subfeat}{$feature} = \@ss;
  @ss;
}

sub _subfeat {
  my $class   = shift;
  my $feature = shift;

  return $feature->segments     if $feature->can('segments');

  my @split = eval { my $id   = $feature->location->seq_id;
		     my @subs = $feature->location->sub_Location;
		     grep {$id eq $_->seq_id} @subs;
		   };

  return @split if @split;

  # Either the APIs have changed, or I got confused at some point...
  return $feature->get_SeqFeatures         if $feature->can('get_SeqFeatures');
  return $feature->sub_SeqFeature          if $feature->can('sub_SeqFeature');
  return;
}

# synthesize a key glyph
sub keyglyph {
  my $self = shift;
  my $feature = $self->make_key_feature;
  my $factory = $self->factory->clone;
  $factory->set_option(label       => 1);
  $factory->set_option(description => 0);
  $factory->set_option(bump  => 0);
  $factory->set_option(connector  => 'solid');
  return $factory->make_glyph(0,$feature);
}

# synthesize a key glyph
sub make_key_feature {
  my $self = shift;

  my $scale = 1/$self->scale;  # base pairs/pixel

  # one segments, at pixels 0->80
  my $offset = $self->panel->offset;

  my $feature =
    Bio::Graphics::Feature->new(-start =>0 * $scale +$offset,
				-end   =>80*$scale+$offset,
				-name => $self->make_key_name(),
				-strand => '+1');
  return $feature;
}

sub make_key_name {
  my $self = shift;

  # breaking encapsulation - this should be handled by the panel
  my $key      = $self->option('key') || '';
  return $key unless $self->panel->add_category_labels;

  my $category = $self->option('category');
  my $name     = defined $category ? "$key ($category)" : $key;
  return $name;
}

sub all_callbacks {
  my $self = shift;
  return $self->{all_callbacks} if exists $self->{all_callbacks}; # memoize
  return $self->{all_callbacks} = $self->_all_callbacks;
}

sub _all_callbacks {
  my $self = shift;
  my $track_level = $self->option('all_callbacks');
  return $track_level if defined $track_level;
  return $self->panel->all_callbacks;
}

sub subpart_callbacks {
  my $self = shift;
  return $self->{subpart_callbacks} if exists $self->{subpart_callbacks}; # memoize
  return $self->{subpart_callbacks} = $self->_subpart_callbacks;
}

sub _subpart_callbacks {
  my $self = shift;
  return 1 if $self->all_callbacks;
  my $do_subparts = $self->option('subpart_callbacks');
  return $self->{level} == 0 || ($self->{level} > 0 && $do_subparts);
}

sub default_factory {
  croak "no default factory implemented";
}

sub finished {
  my $self = shift;
  delete $self->{factory};
  foreach (@{$self->{parts} || []}) {
    $_->finished;
  }
  delete $self->{parts};
}


############################################################
# autogeneration of options documentation
############################################################

sub options {
    my $self      = shift;
    my $seenit    = shift || {};
    no strict 'refs';
    my $class  = ref $self || $self;
    my $isa    = "$class\:\:ISA";

    $seenit->{$class}++;
    my $options = $self->my_options
                 if defined &{"$class\:\:my_options"};

    my @inherited_options;

    for my $base (@$isa) {
	next if $seenit->{$base}++;
	$base->can('options') or next;
	my $o = $base->options($seenit);
	push @inherited_options,%$o;
    }
    return wantarray ? ($options,{@inherited_options})
	             : {@inherited_options,%$options};
}


sub options_usage {
    my $self  = shift;
    my ($read,$write);
    pipe($read,$write);
    my $child = fork();
    unless ($child) {
	close $read;
	print $write $self->options_pod;
	exit 0;
    }
    close $write;
    eval "use Pod::Usage";
    pod2usage({-input  =>$read,
	       -verbose=>2,
	      });
}

sub options_man {
    my $self         = shift;
    my $nroff;
    chomp($nroff  = `which nroff`) if $ENV{SHELL};
    unless ($nroff) {
	$self->options_usage;
	return;
    }
    my $class        = ref $self   || $self;
    my $extra        = '';

    if ($ENV{TERM} && $ENV{TERM}=~/^(xterm|vt10)/) {
	my ($pager)      = grep {`which $_`} ($ENV{PAGER},'less','more');
	$extra           = "|$pager";
    }
    open my $fh,"| pod2man -n $class | $nroff -man $extra" or die;
    print $fh $self->options_pod;
    close $fh;
    # exit 0 ??
}

sub options_pod {
    my $self         = shift;
    my ($new_options,$old_options)      = $self->options;

    my $class        = ref $self || $self;
    my ($glyph_name) = $class =~ /([^:]+)$/;

    my $description  = join "\n",$self->my_description;

    my $pod  = '';
    $pod    .= "=head1 NAME\n\n";
    $pod    .= <<END;

The B<$glyph_name> glyph.

END
;
    $pod  .=  "=head1 SYNOPSIS\n\n";
    $pod  .=  <<"END";
$description
See the L<Bio\:\:Graphics\:\:Glyph\:\:$glyph_name> manual page
for full details.

 \$panel->add_track(\$features,
                   -glyph    => $glyph_name,
		   -option1  => \$value1,
		   -option2  => \$value2...);

To experiment with this glyph\'s options, use the glyph_help.pl
script with either the -v or -p switch. Run "glyph_help -help" for details.

END
    ;
    $pod  .=  "=head1 OPTIONS DEFINED IN THIS GLYPH\n\n";
    $pod  .=  "Glyph-specific options for the I<$glyph_name> glyph:\n\n";
    $pod  .=  "=over 4\n\n";
    $pod  .=  $self->_pod_options($new_options || {});
    $pod  .=  "=back\n\n";

    $pod  .=  "=head1 INHERITED OPTIONS\n\n";
    $pod  .=  "Options inherited from more general glyph classes:\n\n";
    $pod  .=  "=over 4\n\n";
    $pod  .=  $self->_pod_options($old_options || {});
    $pod  .=  "=back\n\n";

    $pod  .= "=head1 COLOR OPTIONS\n\n";
    $pod  .= "The following list of named colors can be used as an argument to any option ";
    $pod  .= "that takes a color:\n\n";
    eval "require Bio::Graphics::Panel" unless Bio::Graphics::Panel->can('color_names');
    for my $c (sort Bio::Graphics::Panel->color_names) {
	$pod .= " $c\n";
    }
    $pod;
}

sub _pod_options {
    my $self    = shift;
    my $options = shift;

    my $pod     = %$options ? ''  : "B<(none)>\n\n";
    for my $option (sort keys %$options) {
	my ($range,$default,@description) = @{$options->{$option}};
	$default = $range eq 'boolean' ? "'undef' (false)" 
	                               : "'undef'"
                   unless defined $default;
	$default = "1 (true)" if $range eq 'boolean' && $default == 1;
	$range =  join ', ',map {"'$_'"} @$range if ref $range eq 'ARRAY';
	$pod  .=  "=item B<-$option> <$range>  [default $default]\n\n";
	$pod  .=  join "\n",@description;
	if ($range eq 'font') {
	    $pod  .=  "\nValid choices: 'gdTinyFont', 'gdSmallFont', 'gdMediumBoldFont', 'gdLargeFont', 'gdGiantFont'";
	} elsif ($range eq 'color') {
	    $pod  .= "\nSee next section for color choices.\n";
	}

	$pod  .= "\n\n";
    }
    return $pod;
}



1;

__END__

=head1 NAME

Bio::Graphics::Glyph - Base class for Bio::Graphics::Glyph objects

=head1 SYNOPSIS

See L<Bio::Graphics::Panel>.

=head1 DESCRIPTION

Bio::Graphics::Glyph is the base class for all glyph objects.  Each
glyph is a wrapper around an Bio:SeqFeatureI object, knows how to
render itself on an Bio::Graphics::Panel, and has a variety of
configuration variables.

End developers will not ordinarily work directly with
Bio::Graphics::Glyph objects, but with Bio::Graphics::Glyph::generic
and its subclasses.  Similarly, most glyph developers will want to
subclass from Bio::Graphics::Glyph::generic because the latter
provides labeling and arrow-drawing facilities.

=head1 METHODS

This section describes the class and object methods for
Bio::Graphics::Glyph.

=head2 CONSTRUCTORS

Bio::Graphics::Glyph objects are constructed automatically by an
Bio::Graphics::Glyph::Factory, and are not usually created by
end-developer code.

=over 4

=item $glyph = Bio::Graphics::Glyph-E<gt>new(-feature=E<gt>$feature,-factory=E<gt>$factory)

Given a sequence feature, creates an Bio::Graphics::Glyph object to
display it.  The B<-feature> argument points to the Bio:SeqFeatureI
object to display, and B<-factory> indicates an
Bio::Graphics::Glyph::Factory object from which the glyph will fetch
all its run-time configuration information.  Factories are created and
manipulated by the Bio::Graphics::Panel object.

A standard set of options are recognized.  See L<OPTIONS>.

=back

=head2 OBJECT METHODS

Once a glyph is created, it responds to a large number of methods.  In
this section, these methods are grouped into related categories.

Retrieving glyph context:

=over 4

=item $factory = $glyph-E<gt>factory

Get the Bio::Graphics::Glyph::Factory associated with this object.
This cannot be changed once it is set.

=item $panel = $glyph-E<gt>panel

Get the Bio::Graphics::Panel associated with this object.  This cannot
be changed once it is set.

=item $feature = $glyph-E<gt>feature

Get the sequence feature associated with this object.  This cannot be
changed once it is set.

=item $feature = $glyph-E<gt>parent_feature()

Within callbacks only, the parent_feature() method returns the parent
of the current feature, if there is one. Called with a numeric
argument, ascends the parentage tree: parent_feature(1) will return
the parent, parent_feature(2) will return the grandparent, etc. If
there is no parent, returns undef.

=item $feature = $glyph-E<gt>add_feature(@features)

Add the list of features to the glyph, creating subparts.  This is
most common done with the track glyph returned by
Bio::Graphics::Panel-E<gt>add_track().

If the Bio::Graphics::Panel was initialized with B<-feature_limit> set
to a non-zero value, then calls to a track glyph's add_feature()
method will maintain a count of features added to the track.  Once the
feature count exceeds the value set in -feature_limit, additional
features will displace existing ones in a way that effects a uniform
sampling of the total feature set. This is useful to protect against
excessively large tracks. The total number of features added can be
retrieved by calling the glyph's feature_count() method.

=item $feature = $glyph-E<gt>add_group(@features)

This is similar to add_feature(), but the list of features is treated
as a group and can be configured as a set.

=item $glyph-E<gt>finished

When you are finished with a glyph, you can call its finished() method
in order to break cycles that would otherwise cause memory leaks.
finished() is typically only used by the Panel object.

=item $subglyph = $glyph-E<gt>make_subglyph($level,@sub_features)

This method is called to create subglyphs from a list of
subfeatures. The $level indicates the current level of the glyph
(top-level glyphs are level 0, subglyphs are level 1, etc).

Ordinarily this method simply calls
$self-E<gt>factory-E<gt>make_subglyph($level,@sub_features). Override
it in subclasses to create subglyphs of a particular type. For
example:

 sub make_subglyph {
    my $self = shift;
    my $level = shift;
    my $factory = $self->factory;
    $factory->make_glyph($factory,'arrow',@_);
 }

=item $count = $glyph-E<gt>feature_count()

Return the number of features added to this glyph via add_feature().

=item $flag = $glyph->features_clipped()

If the panel was initialized with -feature_limit set to a non-zero
value, then calls to add_features() will limit the number of glyphs to
the indicated value. If this value was exceeded, then
features_clipped() will return true.

=back

Retrieving glyph options:

=over 4

=item $fgcolor = $glyph-E<gt>fgcolor

=item $bgcolor = $glyph-E<gt>bgcolor

=item $fontcolor = $glyph-E<gt>fontcolor

=item $fontcolor = $glyph-E<gt>font2color

=item $fillcolor = $glyph-E<gt>fillcolor

These methods return the configured foreground, background, font,
alternative font, and fill colors for the glyph in the form of a
GD::Image color index.

=item $color = $glyph-E<gt>tkcolor

This method returns a color to be used to flood-fill the entire glyph
before drawing (currently used by the "track" glyph).

=item ($left,$top,$right,$bottom) = $glyph-E<gt>bounds($dx,$dy)

Given the topleft coordinates of the glyph, return the bounding box of
its contents, exclusive of padding. This is typically called by the
draw() and draw_component() methods to recover the position of the
glyph.

=item ($left,$top,$right,$bottom) = $glyph-E<gt>calculate_boundaries($dx,$dy)

An alias for bounds(), used by some glyphs for compatibility with older versions of this module.

=item $width = $glyph-E<gt>width([$newwidth])

Return the width of the glyph, not including left or right padding.
This is ordinarily set internally based on the size of the feature and
the scale of the panel.

=item $width = $glyph-E<gt>layout_width

Returns the width of the glyph including left and right padding.

=item $width = $glyph-E<gt>height

Returns the height of the glyph, not including the top or bottom
padding.  This is calculated from the "height" option and cannot be
changed.

=item $font = $glyph-E<gt>font

Return the font for the glyph.

=item $option = $glyph-E<gt>option($option)

Return the value of the indicated option.

=item $index = $glyph-E<gt>color($option_name)

Given an option name that corresponds to a color (e.g. 'fgcolor') look
up the option and translate it into a GD color index.

=item $index = $glyph-E<gt>translate_color($color)

Given a symbolic or #RRGGBB-form color name, returns its GD index.

=item $level = $glyph-E<gt>level

The "level" is the nesting level of the glyph.
Groups are level -1, top level glyphs are level 0,
subparts (e.g. exons) are level 1 and so forth.

=item @parts = $glyph-E<gt>parts

For glyphs that can contain subparts (e.g. the segments glyph), this
method will return the list of subglyphs it contains. Subglyphs are
created automatically by the new() method and are created subject to
the maximum recursion depth specified by the maxdepth() method and/or
the -maxdepth option.


=back

Setting an option:

=over 4

=item $glyph-E<gt>configure(-name=E<gt>$value)

You may change a glyph option after it is created using set_option().
This is most commonly used to configure track glyphs.

=back

Retrieving information about the sequence:

=over 4

=item $start = $glyph-E<gt>start

=item $end   = $glyph-E<gt>end

These methods return the start and end of the glyph in base pair
units.

=item $offset = $glyph-E<gt>offset

Returns the offset of the segment (the base pair at the far left of
the image).

=item $length = $glyph-E<gt>length

Returns the length of the sequence segment.

=back


Retrieving formatting information:

=over 4

=item $top = $glyph-E<gt>top

=item $left = $glyph-E<gt>left

=item $bottom = $glyph-E<gt>bottom

=item $right = $glyph-E<gt>right

These methods return the top, left, bottom and right of the glyph in
pixel coordinates.

=item $height = $glyph-E<gt>height

Returns the height of the glyph.  This may be somewhat larger or
smaller than the height suggested by the GlyphFactory, depending on
the type of the glyph.

=item $scale = $glyph-E<gt>scale

Get the scale for the glyph in pixels/bp.

=item $height = $glyph-E<gt>labelheight

Return the height of the label, if any.

=item $label = $glyph-E<gt>label

Return a human-readable label for the glyph.

=back

These methods are called by Bio::Graphics::Track during the layout
process:

=over 4

=item $glyph-E<gt>move($dx,$dy)

Move the glyph in pixel coordinates by the indicated delta-x and
delta-y values.

=item ($x1,$y1,$x2,$y2) = $glyph-E<gt>box

Return the current position of the glyph.

=back

These methods are intended to be overridden in subclasses:

=over 4

=item $glyph-E<gt>calculate_height

Calculate the height of the glyph.

=item $glyph-E<gt>calculate_left

Calculate the left side of the glyph.

=item $glyph-E<gt>calculate_right

Calculate the right side of the glyph.

=item $glyph-E<gt>draw($gd,$left,$top)

Optionally offset the glyph by the indicated amount and draw it onto
the GD::Image object.

=item $glyph-E<gt>draw_label($gd,$left,$top)

Draw the label for the glyph onto the provided GD::Image object,
optionally offsetting by the amounts indicated in $left and $right.

=item $glyph-E<gt>maxdepth()

This returns the maximum number of levels of feature subparts that the
glyph will recurse through. For example, returning 0 indicates that
the glyph will only draw the top-level feature. Returning 1 indicates
that it will only draw the top-level feature and one level of
subfeatures. Returning 2 will descend down two levels. Overriding this
method will speed up rendering by avoiding creating of a bunch of
subglyphs that will never be drawn.

The default behavior is to return undef (unlimited levels of descent)
unless the -maxdepth option is passed, in which case this number is
returned.

Note that Bio::Graphics::Glyph::generic overrides maxdepth() to return
0, meaning no descent into subparts will be performed.

=back

These methods are useful utility routines:

=over 4

=item @pixels = $glyph-E<gt>map_pt(@bases);

Map the list of base position, given in base pair units, into pixels,
using the current scale and glyph position. This method will accept a
single base position or an array.

=item $glyph-E<gt>filled_box($gd,$x1,$y1,$x2,$y2)

Draw a filled rectangle with the appropriate foreground and fill
colors, and pen width onto the GD::Image object given by $gd, using
the provided rectangle coordinates.

=item $glyph-E<gt>filled_oval($gd,$x1,$y1,$x2,$y2)

As above, but draws an oval inscribed on the rectangle.

=item $glyph-E<gt>exceeds_depth

Returns true if descending into another level of subfeatures will
exceed the value returned by maxdepth().

=back

=head2 OPTIONS

The following options are standard among all Glyphs.  See individual
glyph pages for more options.

Also try out the glyph_help.pl script, which attempts to document each
glyph's shared and specific options and provides an interface for
graphically inspecting the effect of different options.

  Option      Description                      Default
  ------      -----------                      -------

  -fgcolor      Foreground color	       black

  -bgcolor      Background color               turquoise

  -fillcolor    Synonym for -bgcolor

  -linewidth    Line width                     1

  -height       Height of glyph		       10

  -font         Glyph font		       gdSmallFont

  -connector    Connector type                 undef (false)

  -connector_color
                Connector color                black

  -strand_arrow Whether to indicate            undef (false)
                 strandedness

  -stranded     Whether to indicate            undef (false)
                 strandedness
                 (same as above))

  -label        Whether to draw a label	       undef (false)

  -description  Whether to draw a description  undef (false)

  -no_subparts  Set to true to prevent         undef (false)
                drawing of the subparts
                of a feature.

  -ignore_sub_part Give the types/methods of   undef
                subparts to ignore (as a 
                space delimited list).

  -maxdepth     Specifies the maximum number   undef (unlimited) 
                child-generations to decend
                when getting subfeatures

  -sort_order   Specify layout sort order      "default"

  -always_sort  Sort even when bumping is off  undef (false)

  -bump_limit   Maximum number of levels to bump undef (unlimited)

  -hilite       Highlight color                undef (no color)

  -link, -title, -target
               These options are used when creating imagemaps
               for display on the web.  See L<Bio::Graphics::Panel/"Creating Imagemaps">.


For glyphs that consist of multiple segments, the B<-connector> option
controls what's drawn between the segments.  The default is undef (no
connector).  Options include:

   "hat"     an upward-angling conector
   "solid"   a straight horizontal connector
   "quill"   a decorated line with small arrows indicating strandedness
             (like the UCSC Genome Browser uses)
   "dashed"  a horizontal dashed line.
   "crossed" a straight horizontal connector with an "X" on it
              (Can be used when segments are not yet validated
               by some internal experiments...)

The B<-connector_color> option controls the color of the connector, if
any.

The label is printed above the glyph.  You may pass an anonymous
subroutine to B<-label>, in which case the subroutine will be invoked
with the feature as its single argument and is expected to return the
string to use as the label.  If you provide the numeric value "1" to
B<-label>, the label will be read off the feature's seqname(), info()
and primary_tag() methods will be called until a suitable name is
found.  To create a label with the text "1", pass the string "1 ".  (A
1 followed by a space).

The description is printed below the glyph.  You may pass an anonymous
subroutine to B<-description>, in which case the subroutine will be
invoked with the feature as its single argument and is expected to
return the string to use as the description.  If you provide the
numeric value "1" to B<-description>, the description will be read off
the feature's source_tag() method.  To create a description with the
text "1", pass the string "1 ".  (A 1 followed by a space).

In the case of ACEDB Ace::Sequence feature objects, the feature's
info(), Brief_identification() and Locus() methods will be called to
create a suitable description.

The B<-strand_arrow> option, if true, requests that the glyph indicate
which strand it is on, usually by drawing an arrowhead.  Not all
glyphs will respond to this request.  For historical reasons,
B<-stranded> is a synonym for this option. Multisegmented features
will draw an arrowhead on each component unless you specify a value of
"ends" to -strand_arrow, in which case only the rightmost component
(for + strand features) or the leftmost component (for - strand
features) will have arrowheads.

B<sort_order>: By default, features are drawn with a layout based only on the
position of the feature, assuring a maximal "packing" of the glyphs
when bumped.  In some cases, however, it makes sense to display the
glyphs sorted by score or some other comparison, e.g. such that more
"important" features are nearer the top of the display, stacked above
less important features.  The -sort_order option allows a few
different built-in values for changing the default sort order (which
is by "left" position): "low_score" (or "high_score") will cause
features to be sorted from lowest to highest score (or vice versa).
"left" (or "default") and "right" values will cause features to be
sorted by their position in the sequence.  "longest" (or "shortest")
will cause the longest (or shortest) features to be sorted first, and
"strand" will cause the features to be sorted by strand: "+1"
(forward) then "0" (unknown, or NA) then "-1" (reverse).  Finally,
"name" will sort by the display_name of the features.

In all cases, the "left" position will be used to break any ties.  To
break ties using another field, options may be strung together using a
"|" character; e.g. "strand|low_score|right" would cause the features
to be sorted first by strand, then score (lowest to highest), then by
"right" position in the sequence.

Finally, a subroutine coderef with a $$ prototype can be provided.  It
will receive two B<glyph> as arguments and should return -1, 0 or 1
(see Perl's sort() function for more information).  For example, to
sort a set of database search hits by bits (stored in the features'
"score" fields), scaled by the log of the alignment length (with
"start" position breaking any ties):

  sort_order = sub ($$) {
    my ($glyph1,$glyph2) = @_;
    my $a = $glyph1->feature;
    my $b = $glyph2->feature;
    ( $b->score/log($b->length)
          <=>
      $a->score/log($a->length) )
          ||
    ( $a->start <=> $b->start )
  }

It is important to remember to use the $$ prototype as shown in the
example.  Otherwise Bio::Graphics will quit with an exception. The
arguments are subclasses of Bio::Graphics::Glyph, not the features
themselves.  While glyphs implement some, but not all, of the feature
methods, to be safe call the two glyphs' feature() methods in order to
convert them into the actual features.

The '-always_sort' option, if true, will sort features even if bumping
is turned off.  This is useful if you would like overlapping features
to stack in a particular order.  Features towards the end of the list
will overlay those towards the beginning of the sort order.

The B<-hilite> option draws a colored box behind each feature using the
indicated color. Typically you will pass it a code ref that returns a
color name.  For example:

  -hilite => sub { my $name = shift->display_name; 
                   return 'yellow' if $name =~ /XYZ/ }

The B<-no_subparts> option will prevent the glyph from searching its
feature for subfeatures. This may enhance performance if you know in
advance that none of your features contain subfeatures.

=head1 SUBCLASSING Bio::Graphics::Glyph

By convention, subclasses are all lower-case.  Begin each subclass
with a preamble like this one:

 package Bio::Graphics::Glyph::crossbox;

 use strict;
 use base qw(Bio::Graphics::Glyph);

Then override the methods you need to.  Typically, just the draw()
method will need to be overridden.  However, if you need additional
room in the glyph, you may override calculate_height(),
calculate_left() and calculate_right().  Do not directly override
height(), left() and right(), as their purpose is to cache the values
returned by their calculating cousins in order to avoid time-consuming
recalculation.

A simple draw() method looks like this:

 sub draw {
  my $self = shift;
  $self->SUPER::draw(@_);
  my $gd = shift;

  # and draw a cross through the box
  my ($x1,$y1,$x2,$y2) = $self->calculate_boundaries(@_);
  my $fg = $self->fgcolor;
  $gd->line($x1,$y1,$x2,$y2,$fg);
  $gd->line($x1,$y2,$x2,$y1,$fg);
 }

This subclass draws a simple box with two lines criss-crossed through
it.  We first call our inherited draw() method to generate the filled
box and label.  We then call calculate_boundaries() to return the
coordinates of the glyph, disregarding any extra space taken by
labels.  We call fgcolor() to return the desired foreground color, and
then call $gd-E<gt>line() twice to generate the criss-cross.

For more complex draw() methods, see Bio::Graphics::Glyph::transcript
and Bio::Graphics::Glyph::segments.

Please avoid using a specific image class (via "use GD" for example)
within your glyph package. Instead, rely on the image package passed
to the draw() method. This approach allows for future expansion of
supported image classes without requiring glyph redesign. If you need
access to the specific image classes such as Polygon, Image, or Font,
generate them like such:

 sub draw {
  my $self = shift;
  my $image_class = shift;

  my $polygon_package = $self->polygon_package->new()
  ...
  }

=head1 BUGS

Please report them.

=head1 SEE ALSO

L<Bio::DB::GFF::Feature>,
L<Ace::Sequence>,
L<Bio::Graphics::Panel>,
L<Bio::Graphics::Track>,
L<Bio::Graphics::Glyph::Factory>,
L<Bio::Graphics::Glyph::alignment>,
L<Bio::Graphics::Glyph::anchored_arrow>,
L<Bio::Graphics::Glyph::arrow>,
L<Bio::Graphics::Glyph::box>,
L<Bio::Graphics::Glyph::broken_line>,
L<Bio::Graphics::Glyph::cds>,
L<Bio::Graphics::Glyph::christmas_arrow>,
L<Bio::Graphics::Glyph::crossbox>,
L<Bio::Graphics::Glyph::dashed_line>,
L<Bio::Graphics::Glyph::diamond>,
L<Bio::Graphics::Glyph::dna>,
L<Bio::Graphics::Glyph::dot>,
L<Bio::Graphics::Glyph::dumbbell>,
L<Bio::Graphics::Glyph::ellipse>,
L<Bio::Graphics::Glyph::ex>,
L<Bio::Graphics::Glyph::extending_arrow>,
L<Bio::Graphics::Glyph::flag>,
L<Bio::Graphics::Glyph::gene>,
L<Bio::Graphics::Glyph::generic>,
L<Bio::Graphics::Glyph::graded_segments>,
L<Bio::Graphics::Glyph::group>,
L<Bio::Graphics::Glyph::heterogeneous_segments>,
L<Bio::Graphics::Glyph::image>,
L<Bio::Graphics::Glyph::lightning>,
L<Bio::Graphics::Glyph::line>,
L<Bio::Graphics::Glyph::merge_parts>,
L<Bio::Graphics::Glyph::merged_alignment>,
L<Bio::Graphics::Glyph::minmax>,
L<Bio::Graphics::Glyph::oval>,
L<Bio::Graphics::Glyph::pentagram>,
L<Bio::Graphics::Glyph::pinsertion>,
L<Bio::Graphics::Glyph::primers>,
L<Bio::Graphics::Glyph::processed_transcript>,
L<Bio::Graphics::Glyph::protein>,
L<Bio::Graphics::Glyph::ragged_ends>,
L<Bio::Graphics::Glyph::redgreen_box>,
L<Bio::Graphics::Glyph::redgreen_segment>,
L<Bio::Graphics::Glyph::repeating_shape>,
L<Bio::Graphics::Glyph::rndrect>,
L<Bio::Graphics::Glyph::ruler_arrow>,
L<Bio::Graphics::Glyph::saw_teeth>,
L<Bio::Graphics::Glyph::segmented_keyglyph>,
L<Bio::Graphics::Glyph::segments>,
L<Bio::Graphics::Glyph::so_transcript>,
L<Bio::Graphics::Glyph::span>,
L<Bio::Graphics::Glyph::splice_site>,
L<Bio::Graphics::Glyph::stackedplot>,
L<Bio::Graphics::Glyph::ternary_plot>,
L<Bio::Graphics::Glyph::text_in_box>,
L<Bio::Graphics::Glyph::three_letters>,
L<Bio::Graphics::Glyph::tic_tac_toe>,
L<Bio::Graphics::Glyph::toomany>,
L<Bio::Graphics::Glyph::track>,
L<Bio::Graphics::Glyph::transcript>,
L<Bio::Graphics::Glyph::transcript2>,
L<Bio::Graphics::Glyph::translation>,
L<Bio::Graphics::Glyph::triangle>,
L<Bio::Graphics::Glyph::two_bolts>,
L<Bio::Graphics::Glyph::wave>,
L<Bio::Graphics::Glyph::weighted_arrow>,
L<Bio::Graphics::Glyph::whiskerplot>,
L<Bio::Graphics::Glyph::xyplot>

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
