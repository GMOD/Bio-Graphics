package Bio::Graphics::GDWrapper;

use base 'GD::Image';
use Memoize 'memoize';

#memoize('_match_font');

sub new {
    my $self = shift;
    my $gd   = shift;
    return bless $gd,ref $self || $self;
}

# print with a truetype string
sub string {
    my $self = shift;
    my ($font,$x,$y,$string,$color) = @_;
    return $self->SUPER::string(@_) if $self->isa('GD::SVG');
    my $fontface   = $self->_match_font($font);
    my ($fontsize) = $fontface =~ /-(\d+)/;
    $self->stringFT($color,$fontface,$fontsize,0,$x,$y+$fontsize+1,$string);
}

# find a truetype match for a built-in font
sub _match_font {
    my $self = shift;
    my $font = shift;
    return $font unless ref $font && $font->isa('GD::Font');
    $self->useFontConfig(1);
    my $height = $font->height-4;
    my $style  = $font eq GD->gdMediumBoldFont ? 'bold'
	        :$font eq GD->gdGiantFont      ? 'bold'
                :'normal';
    return "Helvetica-$height:$style";
}

1;
