package Bio::Graphics::Panel;
use Bio::Graphics::Glyph::Factory;
use GD;

use strict;
use Carp 'cluck';
our $VERSION = '0.50';

use constant KEYLABELFONT => gdSmallFont;
use constant KEYSPACING   => 10; # extra space between key columns
use constant KEYPADTOP    => 5;  # extra padding before the key starts
use constant KEYCOLOR     => 'cornsilk';

my %COLORS;  # translation table for symbolic color names to RGB triple

# Create a new panel of a given width and height, and add lists of features
# one by one
sub new {
  my $class = shift;
  my %options = @_;

  $class->read_colors() unless %COLORS;

  my $length = $options{-length} || 0;
  my $offset = $options{-offset} || 0;
  my $spacing = $options{-spacing} || 5;
  my $keycolor = $options{-keycolor} || KEYCOLOR;
  my $keyspacing = $options{-keyspacing} || KEYSPACING;

  $length   ||= $options{-segment}->length  if $options{-segment};
  $offset   ||= $options{-segment}->start-1 if $options{-segment};

  return bless {
		tracks => [],
		width  => $options{-width} || 600,
		pad_top    => $options{-pad_top}||0,
		pad_bottom => $options{-pad_bottom}||0,
		pad_left   => $options{-pad_left}||0,
		pad_right  => $options{-pad_right}||0,
		length => $length,
		offset => $offset,
		height => 0, # AUTO
		spacing => $spacing,
		keycolor => $keycolor,
		keyspacing => $keyspacing,
	       },$class;
}

sub pad_left {
  my $self = shift;
  my $g = $self->{pad_left};
  $self->{pad_left} = shift if @_;
  $g;
}
sub pad_right {
  my $self = shift;
  my $g = $self->{pad_right};
  $self->{pad_right} = shift if @_;
  $g;
}
sub pad_top {
  my $self = shift;
  my $g = $self->{pad_top};
  $self->{pad_top} = shift if @_;
  $g;
}
sub pad_bottom {
  my $self = shift;
  my $g = $self->{pad_bottom};
  $self->{pad_bottom} = shift if @_;
  $g;
}
sub map_pt {
  my $self = shift;
  my $offset = $self->{offset};
  my $scale  = $self->scale;
  my @result;
  foreach (@_) {
    push @result,($_-$offset) * $scale;
  }
  @result;
}
sub scale {
  my $self = shift;
  $self->{scale} ||= $self->width/$self->length;
}

sub width {
  my $self = shift;
  my $d = $self->{width};
  $self->{width} = shift if @_;
  $d + $self->pad_left + $self->pad_right;
}

sub spacing {
  my $self = shift;
  my $d = $self->{spacing};
  $self->{spacing} = shift if @_;
  $d;
}

sub length {
  my $self = shift;
  my $d = $self->{length};
  if (@_) {
    my $l = shift;
    $l = $l->length if ref($l) && $l->can('length');
    $self->{length} = $l;
  }
  $d;
}

# create a feature and factory pair
# see Factory.pm for the format of the options
# The thing returned is actually a generic Glyph
sub add_track {
  my $self = shift;

  # due to indecision, we accept features
  # and/or glyph types in the first two arguments
  my ($features,$glyph_name) = ([],'generic');
  while ( @_ && $_[0] !~ /^-/) {
    my $arg = shift;
    $features   = $arg and next if ref($arg);
    $glyph_name = $arg and next unless ref($arg);
  }

  my %args = @_;
  my ($map,$ss,%options);

  foreach (keys %args) {
    (my $canonical = lc $_) =~ s/^-//;
    if ($canonical eq 'map') {
      $map = $args{$_};
      delete $args{$_};
    } elsif ($canonical eq 'stylesheet') {
      $ss  = $args{$_};
      delete $args{$_};
    } else {
      $options{$canonical} = $args{$_};
    }
  }

  my $panel_map = $map 
    ?  sub {
          my $feature = shift;
	  return 'track' if $feature->type eq 'track';
	  return 'group' if $feature->type eq 'group';
	  return $map->($feature);
	}
      :
	sub {
	  my $feature = shift;
	  return 'track' if $feature->type eq 'track';
	  return 'group' if $feature->type eq 'group';
	  return $glyph_name;
	};

  $self->_add_track($features,+1,-map=>$panel_map,-stylesheet=>$ss,-options=>\%options);
}

sub _add_track {
  my $self = shift;
  my ($features,$direction,@options) = @_;

  # build the list of features into a Bio::Graphics::Feature object
  $features = [$features] unless ref $features eq 'ARRAY';

  # optional middle-level glyph is the group
  foreach my $f (@$features) {
    next unless ref $f eq 'ARRAY';
    $f = Bio::Graphics::Feature->new(
				     -segments=>$f,
				     -type => 'group'
				       );
  }

  # top-level glyph is the track
  my $feature = Bio::Graphics::Feature->new(
					    -segments=>$features,
					    -type => 'track'
					   );

  my $factory = Bio::Graphics::Glyph::Factory->new($self,@options);
  my $track   = $factory->make_glyph($feature);

  if ($direction >= 0) {
    push @{$self->{tracks}},$track;
  } else {
    unshift @{$self->{tracks}},$track;
  }
  return $track;
}

sub height {
  my $self = shift;
  my $spacing    = $self->spacing;
  my $height = 0;
  $height += $_->layout_height + $spacing foreach @{$self->{tracks}};
  $height + $self->pad_top + $self->pad_bottom;
}

sub gd {
  my $self = shift;

  return $self->{gd} if $self->{gd};

  my $width  = $self->width;
  my $height = $self->height;
  my $gd = GD::Image->new($width,$height);
  my %translation_table;
  for my $name ('white','black',keys %COLORS) {
    my $idx = $gd->colorAllocate(@{$COLORS{$name}});
    $translation_table{$name} = $idx;
  }

  $self->{translations} = \%translation_table;
  $self->{gd}                = $gd;
  my $offset = 0;
  my $pl = $self->pad_left;
  my $pt = $self->pad_top;

  for my $track (@{$self->{tracks}}) {
    $track->draw($gd,$pl,$offset+$pt,0,1);
    $offset += $track->layout_height + $self->spacing;
  }

  return $self->{gd} = $gd;
}

sub boxes {
  my $self = shift;
  my @boxes;
  my $offset = 0;
  my $pl = $self->pad_left;
  my $pt = $self->pad_top;
  for my $track (@{$self->{tracks}}) {
    my $boxes = $track->boxes($pl,$offset+$pt);
    push @boxes,@$boxes;
    $offset += $track->layout_height + $self->spacing;
  }
  return wantarray ? @boxes : \@boxes;
}

# reverse of translate(); given index, return rgb tripler
sub rgb {
  my $self = shift;
  my $idx  = shift;
  my $gd = $self->{gd} or return;
  return $gd->rgb($idx);
}

sub translate_color {
  my $self = shift;
  my $color = shift;
  if ($color =~ /^\#([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})$/i) {
    my $gd = $self->gd or return 1;
    my ($r,$g,$b) = (hex($1),hex($2),hex($3));
    return $gd->colorClosest($r,$g,$b);
  } else {
    my $table = $self->{translations} or return 1;
    return defined $table->{$color} ? $table->{$color} : 1;
  }
}

sub set_pen {
  my $self = shift;
  my ($linewidth,$color) = @_;
  return $self->{pens}{$linewidth} if $self->{pens}{$linewidth};

  my $pen = $self->{pens}{$linewidth} = GD::Image->new($linewidth,$linewidth);
  my @rgb = $self->rgb($color);
  my $bg = $pen->colorAllocate(255,255,255);
  my $fg = $pen->colorAllocate(@rgb);
  $pen->fill(0,0,$fg);
  $self->{gd}->setBrush($pen);
}

sub png {
  my $gd = shift->gd;
  $gd->png;
}

sub read_colors {
  my $class = shift;
  while (<DATA>) {
    chomp;
    last if /^__END__/;
    my ($name,$r,$g,$b) = split /\s+/;
    $COLORS{$name} = [hex $r,hex $g,hex $b];
  }
}

sub color_names {
    my $class = shift;
    $class->read_colors unless %COLORS;
    return wantarray ? keys %COLORS : [keys %COLORS];
}

1;

__DATA__
white                FF           FF            FF
black                00           00            00
aliceblue            F0           F8            FF
antiquewhite         FA           EB            D7
aqua                 00           FF            FF
aquamarine           7F           FF            D4
azure                F0           FF            FF
beige                F5           F5            DC
bisque               FF           E4            C4
blanchedalmond       FF           EB            CD
blue                 00           00            FF
blueviolet           8A           2B            E2
brown                A5           2A            2A
burlywood            DE           B8            87
cadetblue            5F           9E            A0
chartreuse           7F           FF            00
chocolate            D2           69            1E
coral                FF           7F            50
cornflowerblue       64           95            ED
cornsilk             FF           F8            DC
crimson              DC           14            3C
cyan                 00           FF            FF
darkblue             00           00            8B
darkcyan             00           8B            8B
darkgoldenrod        B8           86            0B
darkgray             A9           A9            A9
darkgreen            00           64            00
darkkhaki            BD           B7            6B
darkmagenta          8B           00            8B
darkolivegreen       55           6B            2F
darkorange           FF           8C            00
darkorchid           99           32            CC
darkred              8B           00            00
darksalmon           E9           96            7A
darkseagreen         8F           BC            8F
darkslateblue        48           3D            8B
darkslategray        2F           4F            4F
darkturquoise        00           CE            D1
darkviolet           94           00            D3
deeppink             FF           14            100
deepskyblue          00           BF            FF
dimgray              69           69            69
dodgerblue           1E           90            FF
firebrick            B2           22            22
floralwhite          FF           FA            F0
forestgreen          22           8B            22
fuchsia              FF           00            FF
gainsboro            DC           DC            DC
ghostwhite           F8           F8            FF
gold                 FF           D7            00
goldenrod            DA           A5            20
gray                 80           80            80
green                00           80            00
greenyellow          AD           FF            2F
honeydew             F0           FF            F0
hotpink              FF           69            B4
indianred            CD           5C            5C
indigo               4B           00            82
ivory                FF           FF            F0
khaki                F0           E6            8C
lavender             E6           E6            FA
lavenderblush        FF           F0            F5
lawngreen            7C           FC            00
lemonchiffon         FF           FA            CD
lightblue            AD           D8            E6
lightcoral           F0           80            80
lightcyan            E0           FF            FF
lightgoldenrodyellow FA           FA            D2
lightgreen           90           EE            90
lightgrey            D3           D3            D3
lightpink            FF           B6            C1
lightsalmon          FF           A0            7A
lightseagreen        20           B2            AA
lightskyblue         87           CE            FA
lightslategray       77           88            99
lightsteelblue       B0           C4            DE
lightyellow          FF           FF            E0
lime                 00           FF            00
limegreen            32           CD            32
linen                FA           F0            E6
magenta              FF           00            FF
maroon               80           00            00
mediumaquamarine     66           CD            AA
mediumblue           00           00            CD
mediumorchid         BA           55            D3
mediumpurple         100          70            DB
mediumseagreen       3C           B3            71
mediumslateblue      7B           68            EE
mediumspringgreen    00           FA            9A
mediumturquoise      48           D1            CC
mediumvioletred      C7           15            85
midnightblue         19           19            70
mintcream            F5           FF            FA
mistyrose            FF           E4            E1
moccasin             FF           E4            B5
navajowhite          FF           DE            AD
navy                 00           00            80
oldlace              FD           F5            E6
olive                80           80            00
olivedrab            6B           8E            23
orange               FF           A5            00
orangered            FF           45            00
orchid               DA           70            D6
palegoldenrod        EE           E8            AA
palegreen            98           FB            98
paleturquoise        AF           EE            EE
palevioletred        DB           70            100
papayawhip           FF           EF            D5
peachpuff            FF           DA            B9
peru                 CD           85            3F
pink                 FF           C0            CB
plum                 DD           A0            DD
powderblue           B0           E0            E6
purple               80           00            80
red                  FF           00            00
rosybrown            BC           8F            8F
royalblue            41           69            E1
saddlebrown          8B           45            13
salmon               FA           80            72
sandybrown           F4           A4            60
seagreen             2E           8B            57
seashell             FF           F5            EE
sienna               A0           52            2D
silver               C0           C0            C0
skyblue              87           CE            EB
slateblue            6A           5A            CD
slategray            70           80            90
snow                 FF           FA            FA
springgreen          00           FF            7F
steelblue            46           82            B4
tan                  D2           B4            8C
teal                 00           80            80
thistle              D8           BF            D8
tomato               FF           63            47
turquoise            40           E0            D0
violet               EE           82            EE
wheat                F5           DE            B3
whitesmoke           F5           F5            F5
yellow               FF           FF            00
yellowgreen          9A           CD            32
__END__
