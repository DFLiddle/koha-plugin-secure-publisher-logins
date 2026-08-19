package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Controller;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Domain qw(extract_registrable_domain);
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher;

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Controller - REST API

=cut

sub health {
    my $c = shift->openapi->valid_input or return;

    my $health = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health->check;
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

    my $viewer = _viewer_from_context( $c, $interface );
    unless ($viewer) {
        return $c->render(
            status  => 200,
            openapi => { show => 0, label => '' }
        );
    }

    if ( $interface eq 'opac' ) {
        unless (
            Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->system_healthy_for_opac
            && Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->patron_may_access_opac($viewer)
        ) {
            return $c->render(
                status  => 200,
                openapi => { show => 0, label => '' }
            );
        }
    }

    my $cred = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher
        ->matching_credentials_for_biblio( $biblionumber, $viewer );

    my $payload = {
        show  => $cred ? 1 : 0,
        label => $cred ? Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants::VIEW_LOGIN_LABEL : '',
    };

    if ( $c->param('debug') && $viewer->is_superlibrarian ) {
        my $urls = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher
            ->biblio_856_urls($biblionumber) || [];
        my @domains = grep {$_} map { extract_registrable_domain($_) } @{$urls};
        $payload->{debug} = {
            biblionumber      => 0 + $biblionumber,
            interface         => $interface,
            viewer_id         => 0 + $viewer->borrowernumber,
            viewer_branch     => $viewer->branchcode // '',
            is_superlibrarian => $viewer->is_superlibrarian ? 1 : 0,
            urls_from_856     => $urls,
            record_domains    => \@domains,
            login_count  => scalar @{
                Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->search(
                    { not_inactive => 1 } )
            },
        };
    }

    return $c->render( status => 200, openapi => $payload );
}

sub view {
    my $c = shift->openapi->valid_input or return;

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
        unless (
            Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->system_healthy_for_opac
            && Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->patron_may_access_opac($viewer)
        ) {
            return $c->render(
                status  => 403,
                openapi => { error => 'forbidden' }
            );
        }
    }

    my $cred = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher
        ->matching_credentials_for_biblio( $biblionumber, $viewer );
    unless ($cred) {
        return $c->render(
            status  => 404,
            openapi => { error => 'not_found' }
        );
    }

    my $url_info = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher
        ->best_url_for_credential( $biblionumber, $cred );

    if ( $interface eq 'opac' ) {
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->log_patron_view(
            $cred->id, $biblionumber );
    } else {
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->log_staff_view(
            $viewer, $cred->id, $biblionumber );
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
        }
    );
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
        return Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->current_staff_patron;
    }
    return Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->current_patron;
}

1;
