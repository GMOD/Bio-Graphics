#!/usr/bin/perl

use Pod::Html;
use File::Path 'mkpath';
mkpath "docs/Graphics/Glyph";

foreach $pod ('Graphics.pm',<Graphics/*.pm>,<Graphics/Glyph/*.pm>,<Graphics/Util/*.pm>) {
  (my $out = $pod) =~ s/\.pm$/.shtml/;

  if (open(POD,"-|")) {
    open (OUT,">docs/$out");
    while (<POD>) {

      if (m!</HEAD>!) {
	print OUT qq(<link rel="stylesheet" type="text/css" href="stylesheet.css">\n);
	print OUT qq(</HEAD>\n);
      }

      elsif (/<BODY>/) {
	print OUT <<END;
<BODY BGCOLOR="white">
<!--#include virtual="/TOP.html" -->
END
;
      } elsif (m!</BODY>!i) {
	print OUT <<END;
<!--#include virtual="/BOTTOM.html" -->
</BODY>
END
;
      }

      else {
	s!/./blib/lib/Bio/!!g;
	s!<A HREF="/Bio/.+">the ([^<]+) manpage</A>!<em>$1</em>!ig;
	print OUT;
      }
    }

  } else {  # child process
    pod2html(
	     $pod,
	     '--podroot=.',
	     '--podpath=.',
	     '--noindex',
	     "--infile=$pod",
	     "--outfile=-"
	    );
    exit 0;
  }
}
