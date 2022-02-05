#!perl

=head1 DESCRIPTION

Check that resources whose names aren't identifiers can still be extracted.

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

use Resource::Silo;

{
    package Foo;
    use Moo;
    my $id = 100;
    has dbh => is => 'ro';
    has id  => is => 'ro', default => sub { ++$id };
    sub do_stuff {
        my $self = shift;
        return join '+', $self->dbh, $self->id;
    };
};

my %id;
resource 'dbh:pg' => sub {
    return 'dbh-pg-'.++$id{pg};
};
resource 'redis-cache' => add_method => 1, sub {
    return 'redis-'.++$id{redis};
};

resource foo => is => 'service', class => 'Foo', depends => [ [dbh => 'dbh:pg' ] ];

my $rs = Resource::Silo->new;

ok !$rs->can('dbh:pg'), 'method skipped for a non-id resource name';
ok  $rs->can('redis-cache'), 'method not skipped if asked for';

is $rs->get( 'dbh:pg' ), 'dbh-pg-1', 'can get resource by name';
is $rs->foo->do_stuff, 'dbh-pg-1+101', 'can depend on such resource';

done_testing;
