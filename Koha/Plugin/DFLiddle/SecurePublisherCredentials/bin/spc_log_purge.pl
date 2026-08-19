#!/usr/bin/perl

use Modern::Perl;

use FindBin qw($Bin);
use lib "$Bin/../../../../../";

use Getopt::Long qw(GetOptions);

use Koha::Script -cron;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;

=head1 NAME

spc_log_purge.pl - Purge Secure Publisher Logins access log (manual / test use)

=head1 SYNOPSIS

  spc_log_purge.pl [--days N] [--dry-run]

Defaults to the same retention as the nightly job
(AccessLogs->retention_days). Use --days with a small value on
dev to test without waiting. Use --dry-run to count rows only.

=cut

my $days;
my $dry_run;
my $logs = 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs';

GetOptions(
    'days=i'    => \$days,
    'dry-run'   => \$dry_run,
    'help|h'    => sub { print_usage(); exit 0 },
) or exit 1;

$days //= $logs->retention_days;

if ($dry_run) {
    my $count = $logs->count_older_than_days($days);
    print "Would purge $count access log entries older than $days days.\n";
    exit 0;
}

my $deleted = $logs->purge_older_than_days($days);
print "Purged $deleted access log entries older than $days days.\n";
exit 0;

sub print_usage {
    my $default = $logs->retention_days;
    print <<"USAGE";
Usage: spc_log_purge.pl [--days N] [--dry-run]

  --days N     Purge threshold in days (default: $default)
  --dry-run    Count matching rows without deleting
  --help       Show this help

Run via koha-shell, for example:

  sudo koha-shell library -c 'perl /var/lib/koha/library/plugins/Koha/Plugin/DFLiddle/SecurePublisherCredentials/bin/spc_log_purge.pl --dry-run --days 30'
USAGE
}
