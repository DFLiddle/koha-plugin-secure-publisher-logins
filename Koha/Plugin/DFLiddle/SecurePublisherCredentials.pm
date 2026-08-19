package Koha::Plugin::DFLiddle::SecurePublisherCredentials;

use Modern::Perl;
use CGI qw(-utf8);
use Mojo::JSON qw(decode_json encode_json);

use Koha::Database;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants qw(
    PLUGIN_NAME
    VIEW_LOGIN_LABEL
    MANAGE_LOGIN_LABEL
    API_NAMESPACE
    API_BASE_PATH
);

use base qw(Koha::Plugins::Base);

our $VERSION = '1.2.14';

our $metadata = {
    name            => PLUGIN_NAME,
    author          => 'David F Liddle',
    description     => 'Securely store and share publisher login details for e-resources matched via 856$u domains.',
    date_authored   => '2026-08-14',
    date_updated    => '2026-08-19',
    minimum_version => '24.11',
    maximum_version => undef,
    version         => $VERSION,
};

use constant {
    Access     => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access',
    AccessLogs => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs',
    Matcher    => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher',
    Tool       => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials::Tool',
};

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials

=cut

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    $args->{'class'}    = $class;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub get_metadata { return $metadata; }

sub get_template {
    my ( $self, $args ) = @_;
    $self->{cgi} ||= CGI->new;
    return $self->SUPER::get_template($args);
}

sub install {
    my ($self) = @_;

    my $dbh = Koha::Database->dbh;

    my $credentials = $self->get_qualified_table_name('credentials');
    my $log         = $self->get_qualified_table_name('access_log');

    $dbh->do(
        qq{
        CREATE TABLE IF NOT EXISTS $credentials (
          id INT(11) NOT NULL AUTO_INCREMENT,
          publisher_name VARCHAR(255) NOT NULL,
          domains TEXT NOT NULL,
          username VARCHAR(255) NOT NULL,
          password_encrypted TEXT NOT NULL,
          access_scope_type ENUM('all','library','library_group','inactive') NOT NULL DEFAULT 'library',
          access_scope_code VARCHAR(80) DEFAULT NULL,
          staff_note TEXT DEFAULT NULL,
          patron_note TEXT DEFAULT NULL,
          date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          date_modified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          UNIQUE KEY publisher_scope (publisher_name, access_scope_type, access_scope_code)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    }
    );

    $dbh->do(
        qq{
        CREATE TABLE IF NOT EXISTS $log (
          id BIGINT NOT NULL AUTO_INCREMENT,
          credential_id INT(11) DEFAULT NULL,
          borrowernumber INT(11) NOT NULL,
          action ENUM('view','create','update','delete') NOT NULL,
          biblionumber INT(11) DEFAULT NULL,
          logged_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id),
          KEY logged_on (logged_on)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    }
    );

    return 1;
}

sub uninstall {
    my ($self) = @_;
    my $dbh = Koha::Database->dbh;
    for my $t ( qw(credentials access_log) ) {
        my $table = $self->get_qualified_table_name($t);
        $dbh->do("DROP TABLE IF EXISTS $table");
    }
    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;
    $self->install($args);
    return 1;
}

sub api_namespace {
    my ($self) = @_;
    return API_NAMESPACE;
}

sub api_routes {
    my ($self) = @_;
    my $spec_str = $self->mbf_read('openapi.json');
    return decode_json($spec_str);
}

sub static_routes {
    my ($self) = @_;
    my $spec_str = $self->mbf_read('staticapi.json');
    return decode_json($spec_str);
}

sub tool {
    my ($self) = @_;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Tool;
    return Tool->dispatch($self);
}

sub _plugin_page_url {
    my ($self) = @_;
    return '/cgi-bin/koha/plugins/run.pl?class=' . $self->{class} . '&method=tool';
}

sub _biblionumber_from_context {
    my ( $self, $params ) = @_;
    if ( ref($params) eq 'HASH' && $params->{biblionumber} ) {
        return $params->{biblionumber};
    }
    if ( ref($params) eq 'HASH' && $params->{biblio_id} ) {
        return $params->{biblio_id};
    }
    $self->{cgi} ||= CGI->new;
    my $bn = scalar $self->{cgi}->param('biblionumber');
    return $bn if defined $bn && $bn =~ /\A\d+\z/;
    if ( my $uri = $ENV{REQUEST_URI} // '' ) {
        return $1 if $uri =~ /[?&]biblionumber=(\d+)/;
    }
    if ( my $qs = $ENV{QUERY_STRING} // '' ) {
        return $1 if $qs =~ /(?:^|&)biblionumber=(\d+)/;
    }
    return;
}

sub intranet_catalog_biblio_enhancements_toolbar_button {
    my ( $self, $params ) = @_;
    my $biblionumber = $self->_biblionumber_from_context($params);
    return unless defined $biblionumber && $biblionumber =~ /\A\d+\z/;

    return unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher;

    my $staff = Access->current_staff_patron;
    return unless $staff;

    my $cred = Matcher->matching_credentials_for_biblio( $biblionumber, $staff );
    return unless $cred;

    my $has_erm = Access->staff_has_erm($staff);
    my $manage  = $has_erm
        && ( $staff->is_superlibrarian || Access->staff_may_manage_scope( $staff, $cred ) );

    my $view_label   = CGI::escapeHTML(VIEW_LOGIN_LABEL);
    my $manage_label = CGI::escapeHTML(MANAGE_LOGIN_LABEL);
    my $biblio_attr  = CGI::escapeHTML($biblionumber);
    my $html         = qq{
        <span class="spc-toolbar">
          <a class="btn btn-default spc-view-login" data-biblionumber="$biblio_attr" href="#">
            <i class="fa fa-lock" aria-hidden="true"></i> $view_label
          </a>
    };

    if ($manage) {
        my $manage_href = CGI::escapeHTML( $self->_plugin_page_url . '&edit_id=' . ( 0 + $cred->id ) );
        $html .= qq{
          <a class="btn btn-default" href="$manage_href">
            <i class="fa fa-pencil" aria-hidden="true"></i> $manage_label
          </a>
        };
    }

    $html .= '</span>';
    return $html;
}

sub opac_head {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    return unless Access->system_healthy_for_opac;

    return $self->_stylesheet_tag('css/spc.css');
}

sub opac_js {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    return unless Access->system_healthy_for_opac;

    return $self->_script_tag('js/spc-config.js') . $self->_script_tag('js/spc-opac.js');
}

sub intranet_head {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    return $self->_stylesheet_tag('css/spc.css');
}

sub intranet_js {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    return $self->_script_tag('js/spc-config.js') . $self->_script_tag('js/spc-staff.js');
}

sub _static_url {
    my ( $self, $rel ) = @_;

    # No query string: Koha's OpenAPI validator rejects undeclared params
    # (a ?v= cache-buster 400s and the browser never executes the file).
    return API_BASE_PATH . '/static/' . $rel;
}

sub _stylesheet_tag {
    my ( $self, $rel ) = @_;
    my $href = CGI::escapeHTML( $self->_static_url($rel) );
    return qq{<link rel="stylesheet" type="text/css" href="$href">};
}

sub _csp_nonce {

    # Koha 24.11 has no CSP module. Later versions set a per-request nonce
    # (Koha.CSPNonce); omit the attribute when it is missing or CSP is off.
    return eval {
        require Koha::ContentSecurityPolicy;
        my $csp = Koha::ContentSecurityPolicy->new;
        return unless $csp->can('get_nonce');
        if ( $csp->can('is_enabled') ) {
            return unless $csp->is_enabled;
        }
        my $nonce = $csp->get_nonce;
        ( defined $nonce && $nonce ne '' ) ? $nonce : undef;
    };
}

sub _script_tag {
    my ( $self, $rel ) = @_;
    my $src   = CGI::escapeHTML( $self->_static_url($rel) );
    my $nonce = $self->_csp_nonce;
    my $attr  = '';
    if ( defined $nonce && $nonce ne '' ) {
        $attr = ' nonce="' . CGI::escapeHTML($nonce) . '"';
    }
    return qq{<script$attr src="$src"></script>};
}

sub _plugin_enabled {
    my ($self) = @_;
    return $self->retrieve_data('__ENABLED__') // 1;
}

=head3 cronjob_nightly

Purge access log entries older than L<AccessLogs/RETENTION_DAYS>.
Invoked by Koha's C<plugins_nightly.pl> (included in C<koha-common> daily cron).

=cut

sub cronjob_nightly {
    my ($self) = @_;

    return 1 unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;

    my $days    = AccessLogs->retention_days;
    my $deleted = AccessLogs->purge_older_than_days($days);

    print PLUGIN_NAME . ": purged $deleted access log entries older than $days days.\n";
    return 1;
}

1;
