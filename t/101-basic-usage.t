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
    resource safe => is => 'setting';

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

    note explain $hash;

    is_deeply [ sort keys %$hash ], [ 'safe', 'unsafe' ], "keys as expected";
    foreach( sort keys %$hash ) {
        my $data = $hash->{$_};
        subtest "key $_" => sub {
            is_deeply [sort keys %$data]
                , [qw[ build depends is ]]
                , 'no unexpected keys';
            like $data->{is}, qr/^(setting|resource|service)$/, 'purity is boolean';
            is ref $data->{build}, 'CODE', 'builder is present';
            is ref $data->{depends}, 'ARRAY', 'dependencies are an array';
        };
    };
    is $hash->{safe}{is}, 'setting', 'safe is a setting';
    is $hash->{unsafe}{is}, 'resource', 'unsafe is a resource';

};

subtest 'silo dsl' => sub {
    Resource::Silo->init( safe => 'quux' );
    is silo->safe, 'quux', 'pure resource preserved';
    is silo->unsafe, 'quux-1', 'non-pure resource initialized';
    silo->reset;
    is silo->unsafe, 'quux-2', 'non-pure resource reinitialized';
};

subtest 'get resources' => sub {
    is_deeply [silo->get(qw(safe unsafe unsafe))]
        , [qw[quux quux-2 quux-2]]
        , 'fetching multiple values at once'
        ;
    is_deeply [scalar silo->get(qw(safe unsafe unsafe))]
        , [qw[quux]]
        , 'fetching multiple values at once, but scalar context'
        ;
};

subtest 'get fresh instance' => sub {
    is silo->fresh('unsafe'), 'quux-3', 'get a dedicated fresh instance';
    is silo->unsafe, 'quux-2', 'shared resource is unchanged';
};

done_testing;

