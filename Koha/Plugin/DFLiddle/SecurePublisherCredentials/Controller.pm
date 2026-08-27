package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Controller;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants qw(
    VIEW_LOGIN_LABEL
    MANAGE_LOGIN_LABEL
    LOGIN_TO_CHECK_ACCESS_LABEL
    LIBRARY_NOT_SUBSCRIBED_LABEL
    LOGIN_INFO_NOT_AVAILABLE_LABEL
    SCOPE_DENIED_MESSAGE
    SUGGEST_FOR_PURCHASE_LABEL
    ACCOUNT_BLOCKED_MESSAGE
);
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Domain qw(extract_registrable_domain);
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher;

use constant {
    Access      => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access',
    AccessLogs  => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs',
    Credentials => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials',
    Health      => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health',
    I18N        => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N',
    Matcher     => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher',
};

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Controller - REST API

=cut

sub health {
    my $c = shift->openapi->valid_input or return;

    my $health = Health->check;
    return $c->render(
        status  => 200,
        openapi => {
            ok       => $health->{ok} ? 1 : 0,
            errors   => $health->{errors}   // [],
            warnings => $health->{warnings} // [],
        }
    );
}

sub availability {
    my $c = shift->openapi->valid_input or return;

    my $biblionumber = $c->param('biblionumber');
    my $interface    = $c->param('interface') // 'opac';

    unless ( _plugin_enabled_in_koha() ) {
        return $c->render(
            status  => 200,
            openapi => _availability_empty_payload( $interface, 'hidden' )
        );
    }

    if ( $interface eq 'staff' ) {
        return $c->render(
            status  => 200,
            openapi => _staff_availability_payload( $c, $biblionumber )
        );
    }

    return $c->render(
        status  => 200,
        openapi => _opac_availability_payload( $c, $biblionumber )
    );
}

sub _availability_empty_payload {
    my ( $interface, $state ) = @_;
    $state //= 'hidden';

    return {
        show            => 0,
        label           => '',
        state           => $state,
        suggestion_url  => '',
        help_email      => '',
        modal_message   => '',
        suggestion_link_label => '',
        manage          => 0,
        manage_label    => '',
        manage_url      => '',
        credential_id => 0,
    };
}

sub _staff_availability_payload {
    my ( $c, $biblionumber ) = @_;

    my $payload = _availability_empty_payload( 'staff', 'hidden' );

    my $viewer = _viewer_from_context( $c, 'staff' );
    unless ($viewer) {
        return $payload;
    }

    my $cred = eval { Matcher->matching_credentials_for_biblio( $biblionumber, $viewer ) };
    if ($@) {
        warn "SPC availability match error: $@";
        return $payload;
    }

    unless ($cred) {
        return $payload;
    }

    $payload->{show}            = 1;
    $payload->{state}           = 'view_allowed';
    $payload->{label}           = _t(VIEW_LOGIN_LABEL);
    $payload->{credential_id}   = 0 + $cred->id;

    my $can_manage = Access->staff_has_erm($viewer)
        && ( $viewer->is_superlibrarian || Access->staff_may_manage_scope( $viewer, $cred ) );
    if ($can_manage) {
        $payload->{manage}       = 1;
        $payload->{manage_label} = _t(MANAGE_LOGIN_LABEL);
        $payload->{manage_url} =
              '/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::DFLiddle::SecurePublisherCredentials'
            . '&method=tool&edit_id='
            . ( 0 + $cred->id );
    }

    if ( $c->param('debug') && $viewer->is_superlibrarian ) {
        $payload->{debug} = _availability_debug( $c, $biblionumber, 'staff', $viewer );
    }

    return $payload;
}

sub _apply_scope_denied_payload {
    my ( $payload, $biblionumber ) = @_;

    $payload->{state}                  = 'scope_denied';
    $payload->{label}                 = _t(LIBRARY_NOT_SUBSCRIBED_LABEL);
    $payload->{suggestion_url}        = Access->opac_suggestion_url_for_biblio($biblionumber);
    $payload->{modal_message}         = _t(SCOPE_DENIED_MESSAGE);
    $payload->{suggestion_link_label} = _t(SUGGEST_FOR_PURCHASE_LABEL);
    return $payload;
}

sub _apply_account_blocked_payload {
    my ( $payload, $patron ) = @_;

    my $email = Access->patron_help_email($patron);
    $payload->{state}       = 'account_blocked';
    $payload->{label}       = _t(LOGIN_INFO_NOT_AVAILABLE_LABEL);
    $payload->{help_email}  = $email // '';
    $payload->{modal_message} = sprintf(
        _t(ACCOUNT_BLOCKED_MESSAGE),
        $email ? $email : _t('your library')
    );
    return $payload;
}

sub _opac_availability_payload {
    my ( $c, $biblionumber ) = @_;

    my $payload = _availability_empty_payload( 'opac', 'hidden' );

    unless ( Access->system_healthy_for_opac ) {
        return $payload;
    }

    my $domain_creds = eval { Matcher->credentials_for_biblio_domains($biblionumber) };
    if ($@) {
        warn "SPC availability domain match error: $@";
        return $payload;
    }
    if ( !$domain_creds || !@{$domain_creds} ) {
        return $payload;
    }

    my $patron = Access->current_patron;
    unless ($patron) {
        $payload->{state}  = 'login_required';
        $payload->{label} = _t(LOGIN_TO_CHECK_ACCESS_LABEL);
        return $payload;
    }

    unless ( Access->patron_may_access_opac($patron) ) {
        if ( Access->patron_matches_any_credential_scope( $patron, $domain_creds ) ) {
            _apply_account_blocked_payload( $payload, $patron );
        }
        else {
            _apply_scope_denied_payload( $payload, $biblionumber );
        }
        return $payload;
    }

    my $cred = eval { Matcher->matching_credentials_for_biblio( $biblionumber, $patron ) };
    if ($@) {
        warn "SPC availability match error: $@";
        return $payload;
    }

    if ($cred) {
        $payload->{show}          = 1;
        $payload->{state}          = 'view_allowed';
        $payload->{label}          = _t(VIEW_LOGIN_LABEL);
        $payload->{credential_id}  = 0 + $cred->id;
    }
    else {
        _apply_scope_denied_payload( $payload, $biblionumber );
    }

    if ( $c->param('debug') && $patron->is_superlibrarian ) {
        $payload->{debug} = _availability_debug( $c, $biblionumber, 'opac', $patron );
    }

    return $payload;
}

sub _availability_debug {
    my ( $c, $biblionumber, $interface, $viewer ) = @_;

    my $urls = Matcher->biblio_856_urls($biblionumber) || [];
    my @domains = grep {$_} map { extract_registrable_domain($_) } @{$urls};

    return {
        biblionumber      => 0 + $biblionumber,
        interface         => $interface,
        viewer_id         => 0 + $viewer->borrowernumber,
        viewer_branch     => $viewer->branchcode // '',
        is_superlibrarian => $viewer->is_superlibrarian ? 1 : 0,
        i18n              => eval {
            require Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N;
            I18N->debug_info;
        } // {},
        urls_from_856     => $urls,
        record_domains    => \@domains,
        login_count       => scalar @{ Credentials->search( { not_inactive => 1 } ) },
    };
}

sub view {
    my $c = shift->openapi->valid_input or return;

    unless ( _plugin_enabled_in_koha() ) {
        return $c->render(
            status  => 404,
            openapi => { error => 'not_found' }
        );
    }

    my $biblionumber = $c->param('biblionumber');
    my $interface    = $c->param('interface') // 'opac';

    my $viewer = _viewer_from_context( $c, $interface );
    unless ($viewer) {
        return $c->render(
            status  => 403,
            openapi => { error => 'forbidden' }
        );
    }

    if ( $interface eq 'opac' ) {
        unless ( Access->system_healthy_for_opac && Access->patron_may_access_opac($viewer) ) {
            return $c->render(
                status  => 403,
                openapi => { error => 'forbidden' }
            );
        }
    }

    my $cred = Matcher->matching_credentials_for_biblio( $biblionumber, $viewer );
    unless ($cred) {
        return $c->render(
            status  => 404,
            openapi => { error => 'not_found' }
        );
    }

    my $url_info = Matcher->best_url_for_credential( $biblionumber, $cred );

    if ( $interface eq 'opac' ) {
        AccessLogs->log_patron_view( $cred->id, $biblionumber );
    }
    else {
        AccessLogs->log_staff_view( $viewer, $cred->id, $biblionumber );
    }

    return $c->render(
        status  => 200,
        openapi => {
            publisher_name => $cred->publisher_name // '',
            username       => $cred->username       // '',
            password       => $cred->decrypt_password // '',
            patron_note    => $cred->patron_note    // '',
            staff_note     => ( $interface eq 'staff' ) ? ( $cred->staff_note // '' ) : '',
            url            => $url_info->{url}            // '',
            url_valid_link => $url_info->{valid_link} ? 1 : 0,
            ui             => {
                username   => _t('Username:'),
                password   => _t('Password:'),
                copy       => _t('Copy'),
                close      => _t('Close'),
                staff_note => _t('Staff note:'),
                login_info => _t('Login info'),
            },
        }
    );
}

sub _plugin_enabled_in_koha {
    return eval {
        require Koha::Plugins::Datas;
        Koha::Plugins::Datas->search(
            {
                plugin_class => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials',
                plugin_key   => '__ENABLED__',
                plugin_value => 1,
            }
        )->count;
    } || 0;
}

sub _t {
    my ($msgid) = @_;
    my $out = $msgid;
    eval {
        require Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N;
        $out = I18N->translate($msgid);
        1;
    };
    return $out;
}

sub _viewer_from_context {
    my ( $c, $interface ) = @_;

    if ( my $user = $c->stash('koha.user') ) {
        return $user if ref($user) && $user->can('borrowernumber');
    }

    return _viewer_for_interface($interface);
}

sub _viewer_for_interface {
    my ($interface) = @_;
    if ( $interface eq 'staff' ) {
        return Access->current_staff_patron;
    }
    return Access->current_patron;
}

1;
