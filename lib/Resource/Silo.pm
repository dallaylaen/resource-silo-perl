package Resource::Silo;

use 5.010;
use strict;
use warnings;

=head1 NAME

Resource::Silo - Dependency injection non-framework

=cut

our $VERSION = 0.01;

=head1 DESCRIPTION

Resource::Silo provides a container object that holds shared resources
such as database connections or configuration files.

Such resources may depend on each other and will be initialized on demand,
and possibly re-initialized if e.g. the application forks.

A default instance of the container is provided,
but more instances can be created with new() if needed.

A Moose-like declarative syntax is provided to define resource
configuration and initialization, as well as a bundle of some useful presets.

A Moo role is provided that handles dependency injection.

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
use List::Util qw(uniq);
use Scalar::Util qw(reftype);

use Exporter qw(import);
our @EXPORT = qw( resource silo );

# <DSL>
my $instance;   # The default instance.
my %meta;       # Known resources

# define possible resource types. river referes to dependency ordering
#     (aka CPAN river)
my @res_river = qw[ value resource service ];
my %res_type = map { $res_river[$_] => $_ } 0..@res_river-1;

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

Pure resources will not be re-initialized. Default is 0.

=item required => 1|0

Resource is forced to be loaded during Resource::Silo->setup.

B<NOTE> This does not affect calling Resource::Silo->new.

=item depends => [ 'name', ... ]

Resources that must be present to initialize this one.

The dependencies will not normally be checked until setup() is called.

=item tentative => 1|0

This definition is preliminary and may be overridden later.

Default: 0.

=item override => 1|0

Override a previous definition.
Without this option, trying to do so will result in error.

Default: 0.

=back

=cut

my %def_options = map { $_=>1 } qw(
    build depends override pure required tentative type validate );
sub resource (@) { ## no critic prototype
    my $name = shift;
    my $builder = @_%2 ? pop : undef;
    my %opt = @_;

    croak "Bad resource name, must be an identifier"
        unless $name =~ /^[a-z][a-z_0-9]*$/i;
    my @unknown = grep { !$def_options{$_} } keys %opt;
    croak "Unexpected parameters in resource: ".join ', ', sort @unknown
        if @unknown;
    my $river = $opt{pure} ? 0 : 1; # TODO rely on opt{type}
    croak "unknown resource type $opt{type}"
        unless defined $river;

    return if $meta{$name} and $opt{tentative};

    croak "Attempt to redefine resource type $name"
        if $meta{$name}
            and not ($opt{override} or $meta{$name}{tentative});
    croak "Resource name '$name' clashes with a method in Resource::Silo"
        if Resource::Silo->can($name) and !$meta{$name};

    croak "Builder specified twice"
        if $opt{build} and $builder;
    $builder //= delete $opt{build};

    croak "No builder found for impure resource"
        if !$builder and $river;

    $builder //= sub {
        # TODO should we even allow non-mandatory resource w/o builder?
        confess "Resource $name wasn't specified and no builder found";
    };
    croak "Builder is not a function"
        if !ref $builder || reftype $builder ne 'CODE';

    # TODO moar validation


    $meta{$name} = {
        river   => $river,
        build   => $builder,
        depends => [ sort uniq @{ $opt{depends} || [] } ],
    };

    # use PerlX::Myabe?
    $meta{$name}{tentative} = 1 if $opt{tentative};
    $meta{$name}{required} = 1 if $opt{required};

    my $code;
    if ($river == 0) {
        $code = sub {
            my $self = shift;
            return $self->{val}{$name} //= $builder->($self);
        };
    } elsif ($river == 1) {
        $code = sub {
            my $self = shift;

            if ($self->{pid} != $$) {
                delete $self->{res};
                $self->{pid} = $$;
            };

            return $self->{res}{$name} //= $builder->($self);
        };
    } else {
        $code = $builder;
    };

    $meta{$name}{fetch} = $code;

    no strict 'refs'; ## no critic
    no warnings 'redefine'; ## no critic
    *$name = $code;

    return; # ensure void
};

=head1 STATIC METHODS

=head2 Resource::Silo->setup( %options )

Setup the global Resource::Silo instance available via C<silo>.

May only be called once.

=cut

sub setup {
    my $class = shift;

    croak "Attempt to call ".__PACKAGE__."->setup() twice"
        if $instance;

    check_deps(); # delay until all possible resource defs have been loaded
    my $probe = $class->new( @_ );
    $probe->get( grep { $meta{$_}{required} } keys %meta );
    $instance = $probe;
};

=head2 teardown

Erase the default instance and try to free the resources it allocated.

=cut

# TODO better doc

sub teardown {
    # trigger resource deallocation
    $instance->reset
        if $instance;
    undef $instance;
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

    # Deep copy so that noone can mess with real %meta
    # (dclone doesn't work because of closures)
    my %out;
    foreach my $name( keys %meta ) {
        local $_ = $meta{$name};
        $out{$name} = {
            build   => $_->{build},
            pure    => $_->{river} == 0 ? 1 : 0,
            depends => [@{ $_->{depends} }],
        };
    };
    return \%out;
};

=head2 check_deps

Dies if some resources have unsatisfied dependencies.

=cut

sub check_deps {
    my @bad;
    # TODO check circularity, too
    foreach my $name( sort keys %meta ) {
        my $entry = $meta{$name};
        my @missing;
        foreach (@{ $entry->{depends} }) {
            push @missing, $_
                unless ($meta{$_});
            # TODO pure resources can't depend on impure!
        };
        push @bad, "resource $name depends on [".(join ', ', @missing).']'
            if @missing;
    };
    # TODO maybe structured return here?
    croak "Resource::Silo: unsatisfied dependencies: ".join "; ", @bad
        if @bad;

    return;
}

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
    delete $self->{res};
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

=head2 fresh( 'name' )

Initialize a fresh, dedicated instance of resource.
The instance stored inside Resource::Silo object is unchanged.

If you are using this method, something probably went wrong.

You should be able to manage isolation / pooling of resources
without this hack.

=cut

sub fresh {
    my ($self, $name) = @_;

    return $meta{$name}{build}->($self);
};

=head2 override( name => $value, ... )

Set resources in existing objects.

If you are using this method, something probably went wrong.

There should be a way to set up resources in a readonly fashion.

Returns self.

=cut

sub override {
    my ($self, %values) = @_;

    my @unknown = grep { !defined $meta{$_} } keys %values;
    croak 'Attempt to set unknown resources: '.join ', ', sort @unknown
        if @unknown;

    foreach( keys %values ) {
        my $river = $meta{$_}{river};
        croak "Attempt to set a volatile resource"
            if $river > 1;
        if ($river) {
            $self->{res}{$_} = $values{$_};
        } else {
            $self->{val}{$_} = $values{$_};
        };
    };
    return $self;
};

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
