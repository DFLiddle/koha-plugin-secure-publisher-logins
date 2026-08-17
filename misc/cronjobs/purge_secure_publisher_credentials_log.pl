#!/usr/bin/perl

use Modern::Perl;

use Koha::Script;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;

=head1 NAME

purge_secure_publisher_credentials_log.pl - Purge access log entries older than 1100 days

=cut

my $days = 1100;
my $deleted = Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->purge_older_than_days($days);
print "Purged $deleted Secure Publisher Credentials log entries older than $days days.\n";
