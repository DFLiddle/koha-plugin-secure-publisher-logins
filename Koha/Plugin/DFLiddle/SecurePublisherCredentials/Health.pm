package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health;

use Modern::Perl;

use C4::Context;
use Koha::Database;
use Koha::Patrons;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames;

use constant TableNames => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames';

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health - Deployment prerequisite checks

=cut

sub check {
    my ($class) = @_;

    my @errors;
    my @warnings;

    push @errors, 'enable_plugins is not enabled in koha-conf.xml'
        unless C4::Context->config('enable_plugins');

    push @errors, 'encryption_key is not set in koha-conf.xml'
        unless C4::Context->config('encryption_key');

    unless ( C4::Context->preference('ERMModule') ) {
        push @warnings, 'ERM module system preference is disabled';
    }

    my $anonymous = C4::Context->preference('AnonymousPatron');
    if ( !$anonymous ) {
        push @errors, 'AnonymousPatron system preference is not set';
    } else {
        my $patron = Koha::Patrons->find($anonymous);
        push @errors, 'AnonymousPatron does not reference a valid borrower'
            unless $patron;
    }

    my $superlib_count = Koha::Patrons->search( { flags => { '!=', 0 } } )->count;
    push @warnings, 'No superlibrarian account detected' unless $superlib_count;

    my $dbh = Koha::Database->dbh;
    for my $table (
        TableNames->credentials,
        TableNames->access_log,
    ) {
        my $sth = $dbh->prepare('SHOW TABLES LIKE ?');
        $sth->execute($table);
        push @errors,
            "Database table $table is missing; disable and re-enable the plugin or run install_plugins.pl"
            unless $sth->fetchrow_array;
    }

    return {
        ok       => scalar(@errors) ? 0 : 1,
        errors   => \@errors,
        warnings => \@warnings,
    };
}

1;
