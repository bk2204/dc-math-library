#!/usr/bin/perl

use warnings;
use strict;

use Carp;

local $SIG{HUP} = sub { Carp::confess "interrupt!"; };

use Test::More tests => 3 * 4;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::DC::Stack;

test_cmd('[1p]SA LAZd-+', 'macro cleanup');
test_cmd('5 d-+', 'integer cleanup');
test_cmd('5 Zd-+', 'macro cleanup for integers');

sub test_cmd {
	my ($cmd, $desc) = @_;

	my $stack = Test::DC::Stack->new($cmd);
	$stack->run;
	is($stack->depth, 0, "$desc results in clean stack");
	is($stack->clean, 1, 'no pollution') or diag explain $stack->pollution;
	is($stack->output, '', 'no output');
	is($stack->errors, '', 'no errors');

	return;
}
