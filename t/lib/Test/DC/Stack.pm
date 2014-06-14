package Test::DC::Stack;

use strict;
use warnings;

no feature 'unicode_strings';

use IO::Handle ();
use IPC::Open3 ();

sub new {
	my ($class, $cmd) = @_;

	return bless {
		command => $cmd,
		sentinels => {},
		output => '',
		bad => {}
	}, $class;
}

sub run {
	my $self = shift;

	# OpenBSD has an extension with byte 255, so don't use that here.
	my @preserved = map { chr($_) } 0..254;

	my $preamble = '';
	my $sentinel;

	foreach my $reg (@preserved) {
		$sentinel = $self->{sentinels}{$reg} = rand(1000000);
		$preamble .= "$sentinel s$reg";
	}
	$sentinel = $self->{sentinels}{main} = rand(1000000);
	$preamble .= "$sentinel\n";

	my $in = IO::Handle->new;
	my $out = IO::Handle->new;
	my $err = IO::Handle->new;

	my $pid = IPC::Open3::open3($in, $out, $err, 'dc');
	print {$in} $preamble;
	print {$in} $self->{command};

	my $outvec = '';
	vec($outvec, fileno($out), 1) = 1;
	if (select($outvec, undef, undef, 0.25)) {
		local $/;
		$out->blocking(0);
		$self->{output} = <$out>;
		$out->blocking(1);
	}

	print {$in} "znAP\n";
	$self->{depth} = <$out> - 1;
	
	print {$in} "nAP\n";
	$sentinel = <$out>;
	chomp $sentinel;
	$self->{bad}{main} = $sentinel if ($sentinel ne $self->{sentinels}{main});

	foreach my $reg (@preserved) {
		print {$in} "l$reg nAP\n";

		$sentinel = <$out>;
		chomp $sentinel;
		$self->{bad}{$reg} = $sentinel
			if ($sentinel ne $self->{sentinels}{$reg});
	}

	print {$in} "f\nq\n";
	{
		local $/;
		$self->{stack} = [split /\n/, <$out>];
	}

	my $errvec = '';
	vec($errvec, fileno($err), 1) = 1;
	if (select($errvec, undef, undef, 0.25)) {
		local $/;
		$err->blocking(0);
		$self->{errors} = <$err>;
	}

	waitpid($pid, 0);

	return;
}

sub depth {
	my $self = shift;

	return $self->{depth};
}

sub clean {
	my $self = shift;

	return !keys %{$self->{bad}};
}

sub output {
	my $self = shift;

	return $self->{output};
}

sub errors {
	my $self = shift;

	return $self->{errors};
}

sub pollution {
	my $self = shift;

	my @result;

	foreach my $key (keys %{$self->{bad}}) {
		my $hex = $key eq "main" ? "main" : sprintf "0x%2x", ord($key);
		push @result, "stack $key ($hex) was $self->{sentinels}{$key}; " .
			"now $self->{bad}{$key}";
	}
	return \@result;
}


1;
