#!perl

=head1 DESCRIPTION

Test Resource::Silo::Config::YAML;

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

use Resource::Silo;
use Resource::Silo::Config::YAML;

throws_ok {
    Resource::Silo->init;
} qr/setting config_file/, 'init does not work without config_file';

throws_ok {
    silo
} qr/instance.*before.*init/, 'init actually failed and produced no viable instance';

lives_ok {
    Resource::Silo->init( config_file => \*DATA );
} 'init works with config_file';

lives_and {
    is silo->config->{foo}, 42, 'value was read from DATA';
};

done_testing;

__DATA__
---
foo: 42
bar: 137
