package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;

use Modern::Perl;

use Koha::Database;
use Koha::Encryption;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Domain qw(
    normalize_domain validate_registrable_domain
);

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials - Credential persistence

=cut

sub table_name {
    my ($class) = @_;
    return Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames->credentials;
}

sub find {
    my ( $class, $id ) = @_;
    my $dbh = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sth = $dbh->prepare("SELECT * FROM $table WHERE id = ?");
    $sth->execute($id);
    my $row = $sth->fetchrow_hashref;
    return unless $row;
    return Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential->new($row);
}

sub search {
    my ( $class, $where, $order ) = @_;
    $order //= 'publisher_name ASC';
    my $dbh = Koha::Database->dbh;
    my $table = $class->table_name;

    my @bind;
    my @clauses = ('1=1');
    if ( $where->{access_scope_type} ) {
        push @clauses, 'access_scope_type = ?';
        push @bind, $where->{access_scope_type};
    }
    if ( defined $where->{not_inactive} && $where->{not_inactive} ) {
        push @clauses, "access_scope_type != 'inactive'";
    }

    my $sql = "SELECT * FROM $table WHERE " . join( ' AND ', @clauses ) . " ORDER BY $order";
    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind);

    my @rows;
    while ( my $row = $sth->fetchrow_hashref ) {
        push @rows, Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential->new($row);
    }
    return \@rows;
}

sub validate_domains_string {
    my ( $class, $domains_str ) = @_;
    my @invalid;
    my @valid;
    for my $part ( split /,/, $domains_str // '' ) {
        $part =~ s/^\s+|\s+$//g;
        next unless length $part;
        my ( $ok, $norm ) = validate_registrable_domain($part);
        if ($ok) {
            push @valid, $norm;
        } else {
            push @invalid, $part;
        }
    }
    return ( \@valid, \@invalid );
}

sub duplicate_exists {
    my ( $class, $publisher_name, $scope_type, $scope_code, $exclude_id ) = @_;
    my $dbh = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sql = qq{
        SELECT id FROM $table
        WHERE publisher_name = ? AND access_scope_type = ?
        AND (access_scope_code <=> ?)
    };
    $sql .= ' AND id != ?' if $exclude_id;
    my $sth = $dbh->prepare($sql);
    my @bind = ( $publisher_name, $scope_type, $scope_code );
    push @bind, $exclude_id if $exclude_id;
    $sth->execute(@bind);
    return $sth->fetchrow_array ? 1 : 0;
}

sub create {
    my ( $class, $params ) = @_;
    my ( $valid, $invalid ) = $class->validate_domains_string( $params->{domains} );
    return { error => 'invalid_domains', invalid => $invalid } if @{$invalid};
    return { error => 'no_domains' } unless @{$valid};

    if ( $class->duplicate_exists( $params->{publisher_name}, $params->{access_scope_type},
            $params->{access_scope_code} ) )
    {
        return { error => 'duplicate' };
    }

    my $crypt = eval { Koha::Encryption->new };
    return { error => 'encryption', message => "$@" } if $@;
    my $enc = eval { $crypt->encrypt_hex( $params->{password} // '' ) };
    return { error => 'encryption', message => "$@" } if $@;

    my $dbh   = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sth   = $dbh->prepare(
        qq{
        INSERT INTO $table
        (publisher_name, domains, username, password_encrypted,
         access_scope_type, access_scope_code, staff_note, patron_note)
        VALUES (?,?,?,?,?,?,?,?)
    }
    );
    my $ok = eval {
        $sth->execute(
            $params->{publisher_name},
            join( ', ', @{$valid} ),
            $params->{username},
            $enc,
            $params->{access_scope_type},
            $params->{access_scope_code},
            $params->{staff_note},
            $params->{patron_note},
        );
        1;
    };
    return { error => 'database', message => "$@" } if $@ || !$ok;

    my $id = eval { $dbh->last_insert_id( undef, undef, $table, 'id' ) };
    $id = $dbh->{mysql_insertid} if !defined $id || $id eq '';
    return { id => $id };
}

sub update {
    my ( $class, $id, $params ) = @_;
    my $existing = $class->find($id);
    return { error => 'not_found' } unless $existing;

    my ( $valid, $invalid ) = $class->validate_domains_string( $params->{domains} );
    return { error => 'invalid_domains', invalid => $invalid } if @{$invalid};
    return { error => 'no_domains' } unless @{$valid};

    if ( $class->duplicate_exists(
            $params->{publisher_name}, $params->{access_scope_type},
            $params->{access_scope_code}, $id
        )
    ) {
        return { error => 'duplicate' };
    }

    my $crypt = Koha::Encryption->new;
    my $password = $params->{password};
    if ( !defined $password || $password eq '' ) {
        $password = $existing->decrypt_password;
    }
    my $enc = $crypt->encrypt_hex($password);

    my $dbh   = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sth   = $dbh->prepare(
        qq{
        UPDATE $table SET
          publisher_name = ?, domains = ?, username = ?, password_encrypted = ?,
          access_scope_type = ?, access_scope_code = ?, staff_note = ?, patron_note = ?
        WHERE id = ?
    }
    );
    $sth->execute(
        $params->{publisher_name},
        join( ', ', @{$valid} ),
        $params->{username},
        $enc,
        $params->{access_scope_type},
        $params->{access_scope_code},
        $params->{staff_note},
        $params->{patron_note},
        $id,
    );
    return { id => $id };
}

sub delete {
    my ( $class, $id ) = @_;
    my $dbh   = Koha::Database->dbh;
    my $table = $class->table_name;
    my $sth   = $dbh->prepare("DELETE FROM $table WHERE id = ?");
    $sth->execute($id);
    return { deleted => $sth->rows };
}

1;
