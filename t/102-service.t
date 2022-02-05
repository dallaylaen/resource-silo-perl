#!perl

=head1 DESCRIPTION

Test *real* inversion of control.

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

use Resource::Silo;

my $id;
resource name => is => 'setting';
resource inst => is => 'service', depends => [ 'name' ], build => sub {
    my ($self, $add) = @_;
    return join '-', $self->name, ++$id, $add ? $add : ();
};

my $rs = Resource::Silo->new(name => 'foo');

is $rs->inst, 'foo-1', 'service generated';
is $rs->inst, 'foo-2', 'always a fresh object';
is $rs->inst('bar'), 'foo-3-bar', 'parameter accepted';

done_testing;
