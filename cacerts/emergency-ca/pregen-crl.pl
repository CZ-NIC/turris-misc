#!/usr/bin/perl
# A tool to pre-generate CRLs a year in advance. That is ugly, but was found
# to be the safest practical way in our case (we store the CRLs in a more secure
# place than the one active, and in case of an incident, we can just delete
# them and generate new ones). Accessing the CA key often is more dangerous,
# as is having a year-long CRL on the public server.
#
# The pre-generation is done by simply changing the system clock repeatedly, so
# turn NTP off during that.
use common::sense;
use DateTime;
use DateTime::Duration;

my $now = DateTime->now;
my $format = "%m%d%H%M%Y";
my $file_format = "%F";

# Set the system time to one passed here
sub date_set($) {
	my ($date) = @_;
	system('sudo', 'date', $date->strftime($format)) == 0 or die "Failed to override date: $?";
}

for my $add_days (0..365) {
	# Day by day, change the system time
	my $day = $now->clone;
	$day->add(DateTime::Duration->new(days => $add_days));
	date_set $day;
	# And ask for generation of the CRL (note that we make sure to generate it „before“ the day it is scheduled to be used.
	$day->add(DateTime::Duration->new(days => 1));
	system(qw(openssl ca -config config -gencrl -keyfile ca.key -cert ca.crt -out), $day->strftime($file_format). ".pem") == 0 or die "Failed to generate CRL: $?";
}

# Return the date back
date_set $now;
