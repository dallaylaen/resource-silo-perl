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

use Resource::Silo qw();

has res => is => 'ro', lazy => 1, builder => \&Resource::Silo::silo;

1;
