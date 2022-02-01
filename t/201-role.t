#!perl

=head1 DESCRIPTION

Check that role works in the most basic case

=cut

use strict;
use warnings;
use Test::More;

use Resource::Silo;

BEGIN {
    package Foo;
    use Moo;
    with 'Resource::Silo::Role';
};

my $id;
resource safe   => pure => 1, undef;
resource unsafe => pure => 0, sub {
    my $self = shift;
    return $self->safe . '-' . ++$id;
};

Resource::Silo->setup( safe => 'quux' );

subtest 'default instance' => sub {
    my $f = Foo->new;
    is $f->res->unsafe, 'quux-1', 'Default instance made it through';
};

subtest 'custom instance' => sub {
    my $f = Foo->new( res => Resource::Silo->new( safe => 42 ) );
    is $f->res->unsafe, '42-2', 'Constructor arg retained';
};

# TODO some real test with parallel invocation & reset()s

done_testing;
