#!perl

=head1 DESCRIPTION

Check that resources are correctly re-initialized in case of a fork.

=cut

use strict;
use warnings;
use Test::More;

use Resource::Silo;

my ($sid, $uid) = (0,100);

resource safe   => is => 'setting', sub { ++$sid };
resource unsafe => sub { ++$uid };

my $rs = Resource::Silo->new;

my @old = $rs->get(qw( safe unsafe ));

my $pid = fork;
die "Fork failed: $!"
    unless defined $pid;

if (!$pid) {
    plan tests => 2;
    my @new = $rs->get(qw( safe unsafe ));
    is $new[0], $old[0], 'safe resource stays';
    is $new[1], $old[1]+1, 'unsafe resource recreated';
} else {
    waitpid($pid, 0);
    exit $?>>8;
};

