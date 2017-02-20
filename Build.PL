#!/usr/bin/perl

use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name       => 'Bio::Graphics',
    license           => 'perl',
    dist_version_from => 'lib/Bio/Graphics.pm',
    dist_author       => 'Lincoln Stein <lincoln.stein@oicr.on.ca>',
    requires          => {
	'Bio::Root::Version'  => '1.005009001',
	'GD'                  => 2.30,
    'CGI'                 => 0,
    'Bio::Coordinate::Pair'   => '1.005009001',
    'Statistics::Descriptive' => 2.6,   # required for Bio::Graphics::Wiggle::Loader
                                            #and tests fail without it
    },
    recommends        => {
	'GD::SVG'                 => 0.32,
	'Text::ParseWords'        => 3.26,  # required for Bio::Graphics::Wiggle::Loader
#	'Bio::SCF'                => 1.01,  # required for Bio::Graphics::Glyph::trace
    },
    script_files => ['scripts/contig_draw.pl',
		     'scripts/feature_draw.pl',
		     'scripts/frend.pl',
		     'scripts/glyph_help.pl',
		     'scripts/search_overview.pl',
		     'scripts/render_msa.pl',
		     'scripts/bam_coverage_windows.pl',
		     'scripts/coverage_to_topoview.pl'
    ],
    create_makefile_pl => 'passthrough',
    build_class        => 'Module::Build',
    meta_merge => {
        resources => {
            homepage => 'http://gmod.org/',
            ## Oddly, the specs for resources mention a bugtracker
            ## and repository that are hash references.  However,
            ## those seem to be ignored by Module::Build at the
            ## moment.  The documented values are here commented for
            ## this is sorted out.
#            bugtracker => {
#                web => 'https://github.com/GMOD/Bio-Graphics/issues',
#            },
#            repository => {
#                url => 'https://github.com/GMOD/Bio-Graphics.git',
#                web => 'https://github.com/GMOD/Bio-Graphics',
#                type => 'git',
#            },
            bugtracker => 'https://github.com/GMOD/Bio-Graphics/issues',
            repository => 'https://github.com/GMOD/Bio-Graphics.git',
        },
    },
);

$build->create_build_script;
exit 0;
