package Resource::Silo::Plugin::DBI;

use 5.010;
use strict;
use warnings;
our $VERSION = 0.01;

=head1 NAME

Resource::Silo::Plugin::DBI - defines C<dbh> resource for L<Resource::Silo>

=head1 SYNOPSIS

    use Resource::Silo;
    use Resource::Silo::Plugin::DBI;

    # Add some more resources including config

    Resource::Silo->setup( config_file => 'myfile.yaml' );

    my $dbh = silo->dbh; # a DBI instance with { RaiseError => 1 }

=head1 DESCRIPTION

Using this module adds a C<dbh> resource that depends on config and returns
a DBI instance.

=cut

use Resource::Silo;

resource dbh => depends => [ 'config' ], build => sub {
    my $self = shift;
    my $conf = $self->config->{database};

    # TODO generate dsn from driver, host, and database name
    require DBI;
    return DBI->connect( $conf->{dsn}, $conf->{username}, $conf->{password}, { RaiseError => 1 } );
};

# TODO append extra validation to the 'config' resource

1;
