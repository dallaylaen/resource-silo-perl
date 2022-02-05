#!perl

=head1 DESCRIPTION

use constant default value instead of a builder

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

use Resource::Silo;

subtest 'setup phase' => sub {
    lives_ok {
        resource foo => is => 'setting', value => 42;
    } 'value is permitted';
    throws_ok {
        resource bar => is => 'resource', value => 42;
    } qr/[Vv]alue .* setting/, 'not for stateful resources';
    throws_ok {
        resource quux => is => 'setting', value => 42, sub { 137 };
    } qr/[Vv]alue and builder/, 'not if builder was specified';
};

subtest 'value actually set' => sub {
    my $rs = Resource::Silo->new;
    is $rs->foo, 42, 'value preserved';
};

done_testing;

