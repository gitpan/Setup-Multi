
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'Module::Build' => '0.3601'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Various simple setup routines for testing',
  'dist_author' => [
    'Steven Haryanto <stevenharyanto@gmail.com>'
  ],
  'dist_name' => 'Setup-Multi',
  'dist_version' => '0.01',
  'license' => 'perl',
  'module_name' => 'Setup::Multi',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Setup::Test' => '0',
    'Sub::Spec' => '0.13',
    'perl' => '5.010000'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
