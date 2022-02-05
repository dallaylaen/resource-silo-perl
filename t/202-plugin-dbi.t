#!perl

use strict;
use warnings;
use Test::More;

use Resource::Silo;
use Resource::Silo::Plugin::DBI;

resource config => is   => 'setting'; # defined after the dependency - this should be ok.

subtest 'pre-init' => sub {
    ok !DBI->can('errstr'), 'real DBI was not loaded';
};

{
    # Avoid loading real DBI
    package DBI;

    sub connect { return \@_ };

    $INC{'DBI.pm'}++;
};

Resource::Silo->init( config => {
    database => {
        dsn      => 'dbi:noexistsql:database=foobar',
        username => 'root',
        password => 'secret',
    },
} );

subtest 'metainfo' => sub {
    my $meta = Resource::Silo->list_resources->{dbh};

    is ref $meta, 'HASH', 'a hash describing dbh exists'
        or return;

    is $meta->{is}, 'resource', 'dbh is impure';
    is_deeply $meta->{depends}, [ 'config' ], 'dbh depends on config';
};

subtest 'fetch dbh' => sub {
    my $dbh = eval { silo->dbh };
    is $@, '', 'no error thrown'
        or return;
    is ref $dbh, 'ARRAY', 'connect returned a hash as we specified above';

    is_deeply $dbh,
        [
            'DBI',
            'dbi:noexistsql:database=foobar',
            'root',
            'secret',
            { RaiseError => 1 },
        ],
        'content as expected';

    push @$dbh, 'mark';

    is silo->dbh->[-1], 'mark', 'original resource is changed (emulate side effect)';

    silo->reset;
    is_deeply silo->dbh, [
            'DBI',
            'dbi:noexistsql:database=foobar',
            'root',
            'secret',
            { RaiseError => 1 },
        ],
        'reloaded resource is not changed';
};

done_testing;
