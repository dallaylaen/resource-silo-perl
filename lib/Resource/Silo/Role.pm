package Resource::Silo::Role;

=head1 NAME

Resource::Silo::Role - Moo/Moose role for Resource::Silo

=head1 SYNOPSIS

    package Foo;
    use Moo;
    with 'Resource::Silo::Role';

    Foo->new->res; # == silo() default instance

=cut

use strict;
use warnings;
use Moo::Role;

# Avoid putting anything into role's namespace.
use Resource::Silo qw();

=head1 ATTRIBUTES

=head2 res

A lazy, read-only dependency container reference.

Default = Resource::Silo::silo().

=cut

# Don't call it silo. It's possible (with enough care from R::S itself)
# but will lead to enormous confusion and undebuggable code.
# Should it be lazy?
# Should it be writable?
has res => is => 'ro', lazy => 1, builder => \&Resource::Silo::silo;

1;
