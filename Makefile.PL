use ExtUtils::MakeMaker;
require 5.005003;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      'NAME'	     => 'Bio::Graphics',
	      'VERSION_FROM' => 'Graphics.pm', # finds $VERSION
	      'PREREQ_PM'    => {
				 GD => 0,
				 Text::Shellwords => 1.00,
				}, # e.g., Module::Name => 1.1
	      PL_FILES       => {
				 'scripts/feature_draw.PLS'  => 'scripts/feature_draw.pl',
				 },
	      EXE_FILES      => [
				 'scripts/feature_draw.pl'
				],
	      'LIBS'	     => [''], # e.g., '-lm'
	      'DEFINE'	     => '', # e.g., '-DHAVE_SOMETHING'
	      'INC'	     => '', # e.g., '-I/usr/include/other'
);
