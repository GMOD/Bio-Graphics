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
	'Text::ParseWords'    => 0,
    },
    recommends        => {
	'GD::SVG'   => 0, 
    },
    script_files => ['scripts/contig_draw.pl',
		     'scripts/feature_draw.pl',
		     'scripts/frend.pl',
		     'scripts/search_overview.pl',
		     'scripts/render_msa.pl',
    ],
    create_makefile_pl => 'passthrough',
    build_class        => 'Module::Build',
    );


$build->create_build_script;
exit 0;
