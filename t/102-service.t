#!perl

=head1 DESCRIPTION

Test *real* inversion of control.

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

BEGIN {
    package Foo;
    # Knows nothing about Resource::Silo
    use Moo;
    my $id;
    has id   => is => 'ro', default => sub { ++$id };
    has conn => is => 'ro';
    sub do_stuff {
        my $self = shift;
        return $self->conn ."+".$self->id;
    };
};

use Resource::Silo;

my $id = 100;
resource name => is => 'setting';
resource conn => is => 'resource', build => sub { $_[0]->name .'-'. ++$id};
resource serv => is => 'service', depends => [ 'conn' ], class => 'Foo';

my $rs = Resource::Silo->new(name => 'bar');

is $rs->serv->do_stuff, 'bar-101+1', 'service generated';
is $rs->serv->do_stuff, 'bar-101+2', 'always a fresh object';
is $rs->serv(id => 42)->do_stuff, 'bar-101+42', 'parameters accepted';

done_testing;
