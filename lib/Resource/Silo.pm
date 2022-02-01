package Resource::Silo;

use 5.006;
use strict;
use warnings;

=head1 NAME

Resource::Silo - Dependency injection non-framework

=cut

our $VERSION = 0.01;

=head1 SYNOPSIS

    use Resource::Silo;

    my $foo = Resource::Silo->new();
    ...

=head1 EXPORT

A clumsy DSL to define one's resources.

=cut

use Carp;
use Exporter qw(import);
our @EXPORT = qw( resource silo );

# <DSL>
my $instance;

=head2 setup( %options )

Setup the global Resource::Silo instance available via C<silo>.

May only be called once.

=cut

sub setup {
    my $class = shift;

    croak "Attempt to call ".__PACKAGE__."->setup() twice"
        if $instance;
    $instance = $class->new( @_ );
};

=head2 silo

Instance method. Returns *the* instance created by setup,
dies if setup wasn't called.

=cut

# TODO alias to Resource::Silo->instance
sub silo () { ## no critic prototype
    croak __PACKAGE__." instance requested before setup()"
        if !$instance;
    return $instance;
};

=head2 resource 'name' => %options => sub { ... }

Define a new resource.

Last argument is the builder sub.

%options may include:

=over

=item pure => 1|0

Whether resource is pure, or may be reinitialized e.g. after fork.

=back

=cut

sub resource (@) { ## no critic prototype
    my $name = shift;
    my $builder = pop;
    my %opt = @_;

    if ($opt{pure}) {
        _pure_accessor( $name, $builder );
    } else {
        _fork_accessor( $name, $builder );
    };
};
# </DSL>

my %is_pure;

=head1 SUBROUTINES/METHODS

=head2 new

Options may include anything that was set up via resource() call.

=cut

sub new {
    my $class = shift;
    my %opt = @_;
    # TODO options

    my (%pure, %fork);

    foreach( keys %opt ) {
        if (!defined $is_pure{$_}) {
            croak "Unknown option $_";
        } elsif ($is_pure{$_}) {
            $pure{$_} = $opt{$_};
        } else {
            $fork{$_} = $opt{$_};
        };
    };

    return bless {
        pure => \%pure,
        load => \%fork,
        pid  => $$,
    }, $class;
}

=head2 pid

Returns the process id ($$) under which the object was created.

=cut

sub pid {
    my $self = shift;
    return $self->{pid};
};

sub _pure_accessor {
    my ($name, $builder) = @_;

    $builder //= sub {
        croak "Resource $name cannot be built!";
    };

    $is_pure{$name} = 1;
    my $code = sub {
        my $self = shift;
        return $self->{pure}{$name} //= $builder->($self);
    };
    no strict 'refs'; ## no critic
    *$name = $code;
}

sub _fork_accessor {
    # TODO better name!
    my ($name, $builder) = @_;

    $is_pure{$name} = 0;
    my $code = sub {
        my $self = shift;

        if ($self->{pid} != $$) {
            warn "pid changed, reset";
            delete $self->{load};
            $self->{pid} = $$;
        };

        return $self->{load}{$name} //= $builder->($self);
    };
    no strict 'refs'; ## no critic
    *$name = $code;
}


=head1 BUGS

Please report any bugs or feature requests to C<bug-Resource-Silo at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Resource-Silo>.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Resource::Silo


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Resource-Silo>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Resource-Silo>

=item * Search CPAN

L<https://metacpan.org/release/Resource-Silo>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is free software.

Copyright (c) 2022 by Konstantin Uvarin.

=cut

1; # End of Resource::Silo
