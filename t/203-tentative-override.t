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
resource foo => pure => 1, build => sub { 42 };
resource bar => pure => 1, build => sub { 3.14 }, tentative => 1;

subtest 'before overrides' => sub {
    Resource::Silo->setup;
    is silo->foo, 42, 'foo as expected';
    is silo->bar, 3.14, 'bar as expected';
    Resource::Silo->teardown;
};

subtest 'teardown actually worked' => sub {
    throws_ok { silo } qr/instance.*before.*setup/, 'another setup required';
};

subtest 'duplicate definition' => sub {
    throws_ok {
        resource foo => pure => 1, build => sub { 137 };
    } qr/redefine .* foo/, 'duplicate definition = error';

    Resource::Silo->setup;
    is silo->foo, 42, 'foo unchanged';
    Resource::Silo->teardown;
};

subtest 'tentative overrides' => sub {
    lives_ok {
        resource foo => pure => 1, tentative => 1, build => sub { 137 };
        resource bar => pure => 1, tentative => 1, build => sub { 3.1415 };
    } 'duplicate definition ok if tentative';

    # new values got thrown away!
    Resource::Silo->setup;
    is silo->foo, 42, 'foo as expected';
    is silo->bar, 3.14, 'bar as expected';
    Resource::Silo->teardown;
};

subtest 'overrides' => sub {
    lives_ok {
        resource foo => pure => 1, override => 1, build => sub { 137 };
        resource bar => pure => 1, build => sub { 3.1415 };
    } 'duplicate definition ok if tentative';

    Resource::Silo->setup;
    is silo->foo, 137, 'foo is updated';
    is silo->bar, 3.1415, 'bar is updated';
    Resource::Silo->teardown;
};

done_testing;
