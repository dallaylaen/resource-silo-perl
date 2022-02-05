#!perl

use strict;
use warnings;

use Test::More;
use File::Basename qw(dirname);
use Test::Pod 1.22;
use Lingua::Ispell;

BEGIN {
    local $SIG{__WARN__} = sub {};
    require Test::Pod::Spelling;
    Test::Pod::Spelling->import(
        spelling => {
            allow_words => [qw[
                Konstantin Uvarin
                github metacpan annocpan CPAN perldoc RT
                TBD DSL
                pid init
                Erathia
            ]],
        }
    );
};

my $dir = dirname(__FILE__);
my $root = $dir eq '.' ? '..' : dirname($dir);

my @files = @ARGV ? @ARGV : all_pod_files("$root/lib");

foreach ( @files ) {
    pod_file_spelling_ok($_);
};

done_testing;
