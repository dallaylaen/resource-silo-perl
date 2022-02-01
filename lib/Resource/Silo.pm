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

    # Moose-like resource DSL - this has to be done only once
    resource config_file => pure => 1;
    resource config => pure => 1, sub {
        my $self = shift;
        Load(read_text($self->config_file));
    };
    resource dbh => pure => 0, sub {
        my $self = shift;
        my $conf = $self->config->{database};
        return DBI->connect( $conf->{dsn}, $conf->{username}, $conf->{password}, { RaiseError => 1} );
    };

    # at the start of your script
    Resource::Silo->setup( config_file => "$FindBin::Bin/../etc/config.yaml" );

    # everywhere else
    silo->dbh; # returns a database handle, reconnecting if needed

    # somewhere in test files
    Resource::Silo->setup( dbh => $mock_database );

    # in you classes
    with 'Resource::Silo::Role';

    sub do_something {
        my $self = shift;
        $self->res->dbh->do( $sql );
    };

=head1 EXPORT

A clumsy DSL to define one's resources.

=cut

use Carp;
use Exporter qw(import);
our @EXPORT = qw( resource silo );

# <DSL>
my $instance;   # The default instance.
my %is_pure;    # Known resources

=head2 Resource::Silo->setup( %options )

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
    my $builder = @_%2 ? pop : undef;
    my %opt = @_;

    if ($opt{pure}) {
        _pure_accessor( $name, $builder );
    } else {
        _fork_accessor( $name, $builder );
    };
};

=head2 list_resources

Returns a nested hash describing available resource methods:

    resource_type => {
        pure => 1|0,
    },
    ...

=cut

sub list_resources {
    my $class = shift; # unused

    # TODO add builder subs?
    return { map {
        $_ => {
            pure => $is_pure{$_},
        }
    } keys %is_pure };
};

# </DSL>

=head1 INSTANCE METHODS

=head2 new

Options may include anything that was set up via resource() call.

=cut

sub new {
    my $class = shift;
    my %opt = @_;

    my $self = bless {
        pid  => $$,
    }, $class;
    $self->override( %opt );
    return $self;
}

=head2 pid

Returns the process id ($$) under which the object was created.

=cut

sub pid {
    my $self = shift;
    return $self->{pid};
};

=head2 reset

Force re-initialization of non-pure resources.

=cut

sub reset {
    my $self = shift;
    delete $self->{load};
    return $self;
};

=head2 get( name, ... )

Fetch multiple resources at once.

In list context, returns requested resources preserving order.
In scalar context, only the first resource is returned.

May be used in void context to force instantiation of resources.

=cut

sub get {
    # TODO name?
    my ($self, @list) = @_;

    # TODO validate
    my @ret = map { $self->$_ } @list;
    return wantarray ? @ret : $ret[0];
}

=head2 override( name => $value, ... )

Set resources in existing objects.

If you are using this function, something is probably wrong.
There should be a way to set up resources in a readonly fashion.

Returns self.

=cut

sub override {
    my ($self, %values) = @_;

    my @unknown = grep { !defined $is_pure{$_} } keys %values;
    croak 'Attempt to set unknown resources: '.join ', ', sort @unknown
        if @unknown;

    foreach( keys %values ) {
        if ($is_pure{$_}) {
            $self->{pure}{$_} = $values{$_};
        } else {
            $self->{load}{$_} = $values{$_};
        };
    };
    return $self;
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

=item * Bug tracker:

L<https://github.com/dallaylaen/resource-silo-perl/issues>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Resource-Silo>

=item * Search CPAN

L<https://metacpan.org/pod/Resource::Silo>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is free software.
It is available on the same terms as Perl itself.

Copyright (c) 2022 by Konstantin Uvarin.

=cut

1; # End of Resource::Silo
