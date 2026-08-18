package Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;

use Modern::Perl;

use Koha::Database;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames;

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs

=cut

use constant RETENTION_DAYS => 1100;

sub retention_days {
    my ($class) = @_;
    return $class->RETENTION_DAYS;
}

sub table_name {
    my ($class) = @_;
    return Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames->access_log;
}

sub log {
    my ( $class, $params ) = @_;
    my $dbh   = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sth   = $dbh->prepare(
        qq{
        INSERT INTO $table (credential_id, borrowernumber, action, biblionumber)
        VALUES (?,?,?,?)
    }
    );
    $sth->execute(
        $params->{credential_id},
        $params->{borrowernumber},
        $params->{action},
        $params->{biblionumber},
    );
    return $dbh->last_insert_id( undef, undef, $table, 'id' );
}

sub log_patron_view {
    my ( $class, $credential_id, $biblionumber ) = @_;
    my $anon = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->anonymous_borrowernumber;
    return unless $anon;
    return $class->log(
        {
            credential_id  => $credential_id,
            borrowernumber => $anon,
            action         => 'view',
            biblionumber   => $biblionumber,
        }
    );
}

sub log_staff_view {
    my ( $class, $staff, $credential_id, $biblionumber ) = @_;
    return $class->log(
        {
            credential_id  => $credential_id,
            borrowernumber => $staff->borrowernumber,
            action         => 'view',
            biblionumber   => $biblionumber,
        }
    );
}

sub log_staff_action {
    my ( $class, $staff, $action, $credential_id ) = @_;
    return $class->log(
        {
            credential_id  => $credential_id,
            borrowernumber => $staff->borrowernumber,
            action         => $action,
            biblionumber   => undef,
        }
    );
}

sub search {
    my ( $class, $limit ) = @_;
    $limit //= 500;
    my $dbh   = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sth   = $dbh->prepare(
        qq{
        SELECT * FROM $table ORDER BY logged_on DESC LIMIT ?
    }
    );
    $sth->execute($limit);
    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows, $row;
    }
    return \@rows;
}

sub count_older_than_days {
    my ( $class, $days ) = @_;
    $days //= $class->retention_days;
    my $dbh   = Koha::Database->dbh;
    my $table = $class->table_name;
    my ($count) = $dbh->selectrow_array(
        qq{
        SELECT COUNT(*) FROM $table
        WHERE logged_on < DATE_SUB(NOW(), INTERVAL ? DAY)
    },
        undef,
        $days
    );
    return $count // 0;
}

sub purge_older_than_days {
    my ( $class, $days ) = @_;
    $days //= $class->retention_days;
    my $dbh   = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sth   = $dbh->prepare(
        qq{
        DELETE FROM $table WHERE logged_on < DATE_SUB(NOW(), INTERVAL ? DAY)
    }
    );
    $sth->execute($days);
    return $sth->rows;
}

1;
