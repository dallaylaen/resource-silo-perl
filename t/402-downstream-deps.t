#!perl

=head1 DESCRIPTION

Check that settings <= resources <= services dependency-wise

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

use Resource::Silo;

resource foo => is => 'setting',  depends => ['bar'], build => sub {};
resource bar => is => 'resource', depends => ['qux'], build => sub {};
resource qux => is => 'service',  depends => ['banana'], build => sub {};

throws_ok {
    Resource::Silo->init
} qr/unsatisfied dependencies/;

my $err = $@;

like $err, qr/setting foo depends on downstream/;
like $err, qr/resource bar depends on downstream/;
like $err, qr/service qux depends on unknown/;

note $err;

done_testing;
