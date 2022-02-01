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







done_testing;

