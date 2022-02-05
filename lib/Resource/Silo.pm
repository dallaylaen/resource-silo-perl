package Resource::Silo;

use 5.010;
use strict;
use warnings;

=head1 NAME

Resource::Silo - Dependency injection non-framework

=cut

our $VERSION = 0.01;

=head1 DESCRIPTION

Resource::Silo provides a container object that holds shared resources,
such as database connections or configuration files.

Resources may depend on each other and will be initialized on demand,
and possibly re-initialized if e.g. the application forks.

A default instance of the container is provided,
but more instances can be created with new() if needed.

A Moose-like declarative syntax is provided to define resource
configuration and initialization, as well as a bundle of some useful presets.

A Moo role is provided that handles dependency injection.

The module name is a reference to I<Heroes of Might and Magic III: The
Restoration of Erathia> video game.

=head1 SYNOPSIS

    use Resource::Silo;

    # Moose-like resource DSL - this has to be done only once

    # A simple setting
    resource config_file => is => 'setting';

    # A setting with a builder
    resource config => is => 'setting', depends => [ 'config_file' ], required => 1, build => sub {
        my $self = shift;
        Load(read_text($self->config_file));
    };

    # A resource per se - a database connection.
    resource dbh => sub {
        my $self = shift;
        my $conf = $self->config->{database};
        return DBI->connect( $conf->{dsn}, $conf->{username}, $conf->{password}, { RaiseError => 1} );
    };

    # At the start of your script
    # This will trigger loading the config because it is 'required'
    Resource::Silo->init( config_file => "$FindBin::Bin/../etc/config.yaml" );

    # somewhere else
    silo->dbh; # returns a database handle, reconnecting if needed

    # somewhere in test files
    Resource::Silo->init( dbh => $mock_database );

    # in your classes
    with 'Resource::Silo::Role';

    sub do_something {
        my $self = shift;
        $self->res->dbh->do( $sql );
    };

=head1 EXPORT

Here goes a DSL that helps defining the application's resources,
together with a prototyped default instance getter.

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
my @res_river = qw[ setting resource service ];
my %res_type = map { $res_river[$_] => $_ } 0..@res_river-1;

=head2 silo

Instance method. Returns *the* instance created with Resource::Silo->init,
dies if init wasn't called.

=cut

# TODO alias to Resource::Silo->instance
sub silo () { ## no critic prototype
    croak __PACKAGE__." instance requested before init()"
        if !$instance;
    return $instance;
};

=head2 resource 'name' => %options [=> sub { ... }]

Define a new resource.

Last argument is the builder sub.

%options may include:

=over

=item is   => 'setting' | 'resource' | 'service'

A I<setting> is an immutable value that persists forever once set.
(Literal in L<Bread::Board> terminology).

A I<resource> may be re-initialized if needed (e.g. on fork).
Typically an impure shared resource such as a database handle.

A I<service> is an object that will be created from scratch every time,
and may thus accept arguments.

Default is 'resource'.

=item build => sub { ... }

A function that builds the resource.
May also be specified as the last argument without a key.

The first argument to this function will be the Resource::Silo object
from which the resource was requested.

=item depends => [ 'needed_resource_name', ... ]

Resources that must be present to initialize this one.

The dependencies will not normally be checked until init() is called.

=item class => 'My::Class'

If present, this parameter will be used in conjunction with C<depends>
to instantiate the resource.
The values in the list will be passed to $class->new() as name => value pairs
(in unknown order).

The names in the C<depends> list may be replaced with pairs of the form
C<[constructor_argument =E<gt> resource_to_fetch]> if names differ.

=item required => 1|0

Resource is forced to be loaded during Resource::Silo->init.

B<NOTE> This does not currently affect calling Resource::Silo->new.

=item tentative => 1|0

This definition is preliminary and may be overridden later.
If the resource is defined already, this definition will be skipped.

Default: 0.

=item override => 1|0

Override a previous definition.
Without this option, trying to do so will result in error.

Default: 0.

=back

=cut

my %def_options = map { $_=>1 } qw(
    add_method build class depends is override required tentative value );
sub resource (@) { ## no critic prototype
    my $name = shift;
    my $builder = @_%2 ? pop : undef;
    my %opt = @_;

    croak "Bad resource name, must be an identifier"
        unless $name =~ /^([a-z][a-z_0-9]*)((?:[-.:\/][a-z_0-9]+)*)$/i;
    $opt{add_method} //= $2 ? 0 : 1;
    my @unknown = grep { !$def_options{$_} } keys %opt;
    croak "Unexpected parameters in resource: ".join ', ', sort @unknown
        if @unknown;
    my $river = $res_type{ $opt{is} // 'resource' };
    croak "unknown resource type $opt{is}"
        unless defined $river;

    return if $meta{$name} and $opt{tentative};
    croak "Attempt to redefine resource type $name"
        if $meta{$name}
            and not ($opt{override} or $meta{$name}{tentative});

    croak "Resource name '$name' clashes with a method in Resource::Silo"
        if !$meta{$name} and Resource::Silo->can($name);
        # TODO allow silent resources that clash with method names, but later

    croak "Builder specified twice"
        if $opt{build} and $builder;
    $builder //= delete $opt{build};

    if (defined $opt{value}) {
        croak "Value may only be applicable to a setting"
            if $river > 0;
        croak "Value and builder specified at the same time"
            if defined $builder;
        my $value = $opt{value};
        $builder = sub { $value };
    }

    if ($river == 0) {
        $builder //= sub {
            # TODO should we even allow non-mandatory resource w/o builder?
            confess "A setting $name was requested but never set";
        };
    };

    if (!$builder and my $class = $opt{class}) {
        # TODO preload $class maybe?

        my (@key_list, @dep_list);
        foreach( @{ $opt{depends} || [] } ) {
            if (ref $_ eq 'ARRAY') {
                push @key_list, $_->[0];
                push @dep_list, $_->[1];
            } else {
                push @key_list, $_;
                push @dep_list, $_;
            };
        };
        $builder = sub {
            my $self = shift;
            my %prereq;
            @prereq{@key_list} = $self->get( @dep_list );
            return $class->new( %prereq, @_ );
        };
        $opt{depends} = \@dep_list;
    };

    croak "Builder was not specified"
        unless defined $builder;
    croak "Builder must be a function, not ".(ref $builder || 'a scalar')
        if !ref $builder || reftype $builder ne 'CODE';
    croak "depends must be a list of strings, or maybe pairs if class was set"
        if $opt{depends} and grep { ref $_ or !$_ } @{ $opt{depends} };

    my $spec = {
        river   => $river,
        build   => $builder,
        depends => [ sort uniq @{ $opt{depends} || [] } ],
    };

    # use PerlX::Myabe?
    $spec->{tentative} = 1 if $opt{tentative};
    $spec->{required} = 1 if $opt{required};
    $spec->{class} = $opt{class} if $opt{class};

    $meta{$name} = $spec;

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

    $meta{$name}{getter} = $code;

    if ($opt{add_method}) {
        no strict 'refs'; ## no critic
        no warnings 'redefine'; ## no critic
        *$name = $code;
    };

    return; # ensure void
};

=head1 STATIC METHODS

=head2 Resource::Silo->init( %options )

Initialize the global Resource::Silo instance available via C<silo>.

May only be called once.

=cut

sub init {
    my $class = shift;

    croak "Attempt to call ".__PACKAGE__."->init() twice"
        if $instance;

    check_deps(); # delay until all possible resource defs have been loaded
    my $probe = $class->new( @_ );
    $probe->get( grep { $meta{$_}{required} } keys %meta );
    $instance = $probe;
};

=head2 teardown

Erase the default instance and try to free the resources it allocated.

This will allow to call C<init> once again.

See also L</reset>.

=cut

sub teardown {
    # trigger resource deallocation
    $instance->reset
        if $instance;
    undef $instance;
};

=head2 list_resources

Returns a nested hash describing resources that were defined so far:

    resource_name => {
        is      => 'setting' | 'resource' | 'service',
        depends => [ ... ],
        build   => CODEREF,
        ...
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
            is      => $res_river[$_->{river}],
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
        my $res = $res_river[ $entry->{river} ];
        my @missing;
        my @downstream;
        foreach (@{ $entry->{depends} }) {
            if (!$meta{$_}) {
                push @missing, $_;
            } elsif ($meta{$_}{river} > $entry->{river}) {
                push @downstream, $_;
            };
        };
        push @bad, "$res $name depends on unknown resource(s) [".(join ', ', @missing).']'
            if @missing;
        push @bad, "$res $name depends on downstream resource(s) [".(join ', ', @downstream).']'
            if @downstream;
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

    my @missing = grep { !$meta{$_} } @list;
    croak "Unknown resources requested: ".join ", ", @missing
        if @missing;

    my @ret = map { $meta{$_}{getter}->($self) } @list;
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

    my $entry = $meta{$name};
    croak "Unknown resource requested: $name"
        unless $entry;

    return $entry->{build}->($self);
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
