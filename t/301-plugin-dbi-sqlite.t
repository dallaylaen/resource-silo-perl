#!perl

=head1 DESCRIPTION

Check that DBI plugin actually works with a real database.

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

if (!eval { require DBD::SQLite }) {
    plan skip_all => "DBD::SQLite cannot be loaded: $@";
    exit 0; # think this is automagic but anyway
};

use Resource::Silo;
use Resource::Silo::Plugin::DBI;

resource config => is => 'setting', value => {
    database => { dsn => 'dbi:SQLite:database=:memory:' }
};

subtest 'base roundtrp + exceptions' => sub {
    my $rs = Resource::Silo->new('dbh/options', {PrintError => 0, RaiseError=>1});
    my $dbh = $rs->dbh;
    lives_ok {
        $dbh->do( 'CREATE TABLE foo ( id INT )' );
        $dbh->do( 'INSERT INTO foo (id) VALUES (?)', {}, 1 );
        $dbh->do( 'INSERT INTO foo (id) VALUES (?)', {}, 2 );
    } 'db setup lives';
    throws_ok {
        $dbh->do( 'INSERT INTO foo (bar) VALUES (?)', {}, 42 );
    } qr/foo.*column.*bar/, 'db throws by default';
    lives_and {
        my $list = $rs->dbh->selectcol_arrayref(q{SELECT id FROM foo});
        is_deeply [ sort @$list ], [1,2], 'data made it through';
    }
};

done_testing;
