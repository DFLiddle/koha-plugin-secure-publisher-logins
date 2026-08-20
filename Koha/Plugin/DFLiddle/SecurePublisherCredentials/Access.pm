package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;

use Modern::Perl;

use C4::Context;
use Koha::Libraries;
use Koha::Patrons;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health;

use constant Health => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health';

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access - Permission and scope checks

=cut

# Lower number = more restrictive (wins when multiple credentials match)
our %SCOPE_PRIORITY = (
    library       => 1,
    library_group => 2,
    all           => 3,
    inactive      => 99,
);

sub current_patron {
    my ($class) = @_;
    my $userenv = C4::Context->userenv;
    return unless $userenv && $userenv->{number};
    return Koha::Patrons->find( $userenv->{number} );
}

sub current_staff_patron {
    my ($class) = @_;
    my $userenv = C4::Context->userenv;
    return unless $userenv && $userenv->{number};
    return Koha::Patrons->find( $userenv->{number} );
}

sub patron_may_access_opac {
    my ( $class, $patron ) = @_;
    return unless $patron;
    return if $patron->debarred;
    return if $patron->is_expired;
    return 1;
}

sub staff_has_erm {
    my ( $class, $patron ) = @_;
    return unless $patron;
    return 1 if $patron->is_superlibrarian;

    if ( $patron->can('has_permission') ) {
        my $ok = eval { $patron->has_permission( { erm => 1 } ) };
        return 1 if $ok;
    }

    my $flags = $patron->flags;
    return 0 unless defined $flags;
    return $flags->{erm} ? 1 : 0 if ref $flags eq 'HASH';

    # Raw borrowers.flags bitmask: non-zero staff accounts may still lack erm.
    my $userid = eval { $patron->userid };
    return 0 unless $userid;
    my $perms = eval {
        require C4::Auth;
        C4::Auth::getuserflags( $flags, $userid );
    };
    return ( $perms && $perms->{erm} ) ? 1 : 0;
}

sub staff_may_manage_scope {
    my ( $class, $staff, $credential ) = @_;
    return unless $staff && $credential;
    return 1 if $staff->is_superlibrarian;

    return 0 if $credential->access_scope_type eq 'all';
    return 0 unless $class->staff_has_erm($staff);

    my $branch = $staff->branchcode;
    if ( $credential->access_scope_type eq 'library' ) {
        return ( $credential->access_scope_code || '' ) eq ( $branch || '' );
    }
    if ( $credential->access_scope_type eq 'library_group' ) {
        return $class->patron_in_library_group( $staff, $credential->access_scope_code );
    }
    return 0 if $credential->access_scope_type eq 'inactive';
    return 0;
}

sub staff_may_view_log {
    my ( $class, $staff ) = @_;
    return unless $staff;
    return 1 if $staff->is_superlibrarian;
    return $class->staff_has_erm($staff);
}

sub patron_home_branch {
    my ( $class, $patron ) = @_;
    return unless $patron;
    return $patron->branchcode;
}

sub patron_in_library_group {
    my ( $class, $patron, $group_id ) = @_;
    return unless $patron && defined $group_id && $group_id ne '';
    my $branch = $patron->branchcode;
    return unless $branch;

    my $dbh = Koha::Database->dbh;
    my $sth = $dbh->prepare(
        'SELECT COUNT(*) FROM library_groups WHERE parent_id = ? AND branchcode = ?'
    );
    $sth->execute( $group_id, $branch );
    my ($count) = $sth->fetchrow_array;
    return $count ? 1 : 0;
}

sub viewer_matches_credential_scope {
    my ( $class, $patron, $credential ) = @_;
    return 0 unless $patron && $credential;
    return 0 if $credential->access_scope_type eq 'inactive';
    return 1 if $patron->is_superlibrarian;

    if ( $credential->access_scope_type eq 'all' ) {
        return 1;
    }
    if ( $credential->access_scope_type eq 'library' ) {
        return ( $class->patron_home_branch($patron) || '' ) eq ( $credential->access_scope_code || '' );
    }
    if ( $credential->access_scope_type eq 'library_group' ) {
        return $class->patron_in_library_group( $patron, $credential->access_scope_code );
    }
    return 0;
}

sub pick_most_restrictive {
    my ( $class, @credentials ) = @_;
    return unless @credentials;
    return $credentials[0] if @credentials == 1;

    my @sorted = sort {
        ( $SCOPE_PRIORITY{ $a->access_scope_type } // 99 )
            <=> ( $SCOPE_PRIORITY{ $b->access_scope_type } // 99 )
    } @credentials;

    return $sorted[0];
}

sub system_healthy_for_opac {
    my ($class) = @_;
    my $health = Health->check;
    return $health->{ok};
}

sub anonymous_borrowernumber {
    my ($class) = @_;
    return C4::Context->preference('AnonymousPatron');
}

1;
