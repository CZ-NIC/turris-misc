#!/usr/bin/perl
# Copyright (c) 2015, CZ.NIC, z.s.p.o. (http://www.nic.cz/)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the CZ.NIC nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL CZ.NIC BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use common::sense;
use utf8;
use Storable qw(store retrieve);

# Configure where the gpg directory with trusted keys to sign git commits lives.
# Then run the git-log command that reads and checks the signatures on commits.
$ENV{GNUPGHOME} = "$ENV{HOME}/git-gpg";
open my $cmd, '-|', 'git', 'log', '--pretty=%H %G? %ae %ce %s' or die "Couldn't run the git log command: $!\n";

# Read cache of known commits, but don't fail if the file is not there
my $known_commits = {};
my $cache_file = "$ENV{HOME}/git-gpg/known_commits";
eval { $known_commits = retrieve $cache_file };

# Regular expression of addresses of people who must sign their commits.
# Anybody from CZ.NIC must. Also, list some email addresses of team members
# that may use their personal address by accident sometimes.
my $require_sign = qr'^(.*@nic\.cz|vorner@.*|r\.oburka@.*|m\.strbacka@.*)$';

my @bad_sigs;
my %bad_stats;
my $other_commits;

while (my $line = <$cmd>) {
	# Parse into fields
	chomp $line;
	my ($hash, $gpg, $author, $committer, $subject) = split /\s+/, $line, 5;

	# Skip over hashes we've seen in previous runs
	next if exists $known_commits->{$hash};
	$known_commits->{$hash} = 1;

	if ($committer =~ $require_sign) {
		# It is one of the people who should sign theer commits.
		next if $gpg eq 'G'; # Properly signed. Next commit, please.

		push @bad_sigs, {
			author => $author,
			committer => $committer,
			reason => $gpg,
			hash => $hash,
			subject => $subject
		};
		$bad_stats{$committer} ++;
	} else {
		$other_commits ++;
	}
}

# Dump the case for the next run
store $known_commits, $cache_file or warn "Couldn't store cache: $!\n";

print "There are $other_commits from unknown people\n" if $other_commits;

if (@bad_sigs) {
	print "There are untrusted commits:\n";
	print "• $_: $bad_stats{$_}\n" for sort keys %bad_stats;
	print "\n";
	print "List of specific commits:\n";
	print "• $_->{hash}\t$_->{reason}\t$_->{committer}\t$_->{subject}\n" for @bad_sigs;
	exit 1;
}
