#!perl

=head1 DESCRIPTION

Make sure bad options to services shall not pass.

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;

use Resource::Silo;
sub bad_args($$;$); ## no critic

bad_args [4, sub {} ], qr/[Bb]ad.*resource.*name/, 'bad resource name';
bad_args ['foo::bar', sub {} ], qr/[Bb]ad.*resource.*name/, 'unexpected characters';
bad_args ['foo' ], qr/No builder/, 'no builder';
bad_args ['foo', build => sub {}, sub {} ], qr/uilder.*twice/, 'double builder';
bad_args ['foo', build1 => sub {} ], qr/[Uu]nexpected/, 'unknown parameter name';
bad_args ['foo', 'bar' ], qr/[Bb]uilder.*not a function/, 'Builder is not a sub';

done_testing;

sub bad_args($$;$) { ## no critic
    my ($opt, $error, $desc) = @_;

    throws_ok {
        resource @$opt;
    } qr/$error/, $desc;
};

