#!perl

=head1 DESCRIPTION

Test tentative and override options in resource DSL

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

use Resource::Silo;

# normal setup
resource foo => is => 'setting', build => sub { 42 };
resource bar => is => 'setting', build => sub { 3.14 }, tentative => 1;

subtest 'before overrides' => sub {
    Resource::Silo->init;
    is silo->foo, 42, 'foo as expected';
    is silo->bar, 3.14, 'bar as expected';
    Resource::Silo->teardown;
};

subtest 'teardown actually worked' => sub {
    throws_ok { silo } qr/instance.*before.*init/, 'another init required';
};

subtest 'duplicate definition' => sub {
    throws_ok {
        resource foo => is => 'setting', build => sub { 137 };
    } qr/redefine .* foo/, 'duplicate definition = error';

    Resource::Silo->init;
    is silo->foo, 42, 'foo unchanged';
    Resource::Silo->teardown;
};

subtest 'tentative overrides' => sub {
    lives_ok {
        resource foo => is => 'setting', tentative => 1, build => sub { 137 };
        resource bar => is => 'setting', tentative => 1, build => sub { 3.1415 };
    } 'duplicate definition ok if tentative';

    # new values got thrown away!
    Resource::Silo->init;
    is silo->foo, 42, 'foo as expected';
    is silo->bar, 3.14, 'bar as expected';
    Resource::Silo->teardown;
};

subtest 'overrides' => sub {
    lives_ok {
        resource foo => is => 'setting', override => 1, build => sub { 137 };
        resource bar => is => 'setting', build => sub { 3.1415 };
    } 'duplicate definition ok if tentative';

    Resource::Silo->init;
    is silo->foo, 137, 'foo is updated';
    is silo->bar, 3.1415, 'bar is updated';
    Resource::Silo->teardown;
};

done_testing;
