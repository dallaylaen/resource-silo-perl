#!perl

=head1 DESCRIPTION

Simplest operations.

=cut

use strict;
use warnings;
use Test::More;

use Resource::Silo;

do {
    # define resources
    resource safe => pure => 1 => undef;

    my $id = 0;
    resource unsafe => sub {
        my $self = shift;
        return $self->safe . "-" . ++$id;
    };
};

subtest 'process id' => sub {
    my $rs = Resource::Silo->new( safe => 'foo', unsafe => 'bar' );
    is $rs->pid, $$, 'process ID saved';
    is $rs->safe, 'foo', 'safe resource preserved';
    is $rs->unsafe, 'bar', 'unsafe resource preserved';
};

subtest 'list_resources' => sub {
    my $hash = Resource::Silo->list_resources;
    is ref $hash, 'HASH', 'returned hash'
        or return;
    is_deeply [ sort keys %$hash ], [ 'safe', 'unsafe' ], "keys as expected";
    is_deeply $hash, {
        safe   => { pure => 1 },
        unsafe => { pure => 0 },
    }, 'hash content';
};

subtest 'silo dsl' => sub {
    Resource::Silo->setup( safe => 'quux' );
    is silo->safe, 'quux', 'pure resource preserved';
    is silo->unsafe, 'quux-1', 'non-pure resource initialized';
    silo->reset;
    is silo->unsafe, 'quux-2', 'non-pure resource reinitialized';
};


done_testing;

