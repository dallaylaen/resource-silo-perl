package Resource::Silo::Config::YAML;

use 5.010;
use strict;
use warnings;

=head1 NAME

Resource::Silo::Config::YAML - defines a YAML config for Resource::Silo

=head1 SYNOPSIS

    use Resource::Silo;
    use Resource::Silo::Config::YAML;

    Resource::Silo->setup( config_file => 'myfile.yaml' );
    silo->config; # A hash with configuration

=cut

use Resource::Silo;

resource config => is => 'setting', depends => [ 'config_file' ], required => 1,
    build => sub {
        my $self = shift;

        require YAML::XS;
        return YAML::XS::LoadFile( $self->config_file );
    };

resource config_file => is => 'setting', tentative => 1;

1;
