package Koha::Plugin::DFLiddle::SecurePublisherCredentials;

use Modern::Perl;
use CGI qw(-utf8);
use File::Spec;
use Mojo::JSON qw(decode_json encode_json);

use Koha::Database;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants qw(
    PLUGIN_NAME
    VIEW_LOGIN_LABEL
    MANAGE_LOGIN_LABEL
    API_BASE_PATH
);

use base qw(Koha::Plugins::Base);

our $VERSION = '1.3.1';

our $metadata = {
    name            => PLUGIN_NAME,
    author          => 'David F Liddle',
    description     => 'Securely store and share publisher login details for e-resources matched via 856$u domains.',
    date_authored   => '2026-08-14',
    date_updated    => '2026-08-20',
    minimum_version => '24.11',
    maximum_version => undef,
    version         => $VERSION,
};

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials

=cut

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    $args->{'class'}    = $class;
    my $self = $class->SUPER::new($args);
    if ($self) {
        $self->_remove_deprecated_files;
        $self->_ensure_hook_methods_registered;
    }
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

    # Never throw: a die here becomes InstallDied/UpgradeDied and a plugins-upload 500,
    # even when tables already exist and the plugin is otherwise usable.
    my $ok = eval {
        my $dbh = Koha::Database->dbh;

        my $credentials = $self->get_qualified_table_name('credentials');
        my $log         = $self->get_qualified_table_name('access_log');

        # Prefix publisher_name so the unique key stays under InnoDB's 767-byte limit
        # on utf8mb4 COMPACT tables (255*4 would overflow).
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
              UNIQUE KEY publisher_scope (publisher_name(191), access_scope_type, access_scope_code)
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

        1;
    };
    if ( !$ok ) {
        warn PLUGIN_NAME . " install error: $@";
        return $self->_credentials_table_exists ? 1 : 0;
    }
    return 1;
}

sub _credentials_table_exists {
    my ($self) = @_;
    my $exists = eval {
        my $dbh   = Koha::Database->dbh;
        my $table = $self->get_qualified_table_name('credentials');
        my $sth   = $dbh->prepare('SHOW TABLES LIKE ?');
        $sth->execute($table);
        $sth->fetchrow_array ? 1 : 0;
    };
    return $exists ? 1 : 0;
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
    # Version bumps should not re-run CREATE TABLE on every upload; tables already
    # exist on DEV/production. Fresh installs still go through install() from Base::new.
    return 1 if $self->_credentials_table_exists;
    return $self->install($args);
}

# Koha plugin upload only overwrites files present in the .kpz; removed paths from
# older releases can linger (e.g. templates/spc_i18n.inc from the 1.2.15 i18n attempt).
sub _remove_deprecated_files {
    my ($self) = @_;
    my $base = eval { $self->bundle_path };
    return unless $base && -d $base;
    my $path = File::Spec->catfile( $base, 'templates', 'spc_i18n.inc' );
    if ( -f $path ) {
        unlink $path or warn PLUGIN_NAME . " could not remove deprecated file $path: $!";
    }
}

# Koha discovers callable plugin methods via the plugin_methods table (InstallPlugins).
# plugins-disable.pl / plugins-enable.pl only work when enable/disable rows exist
# (Koha::Plugins::Handler). If InstallPlugins fails partway (e.g. Duplicate entry on
# api_namespace), UI hooks like intranet_js may be missing while run.pl?method=tool
# still works. Repair missing rows whenever the plugin class loads.
sub _ensure_hook_methods_registered {
    my ($self) = @_;
    my $class = $self->{'class'};
    return unless $class;

    eval {
        require Koha::Plugins::Methods;
        require Koha::Plugins::Method;

        # Importing API_NAMESPACE into the plugin package registers API_NAMESPACE in
        # plugin_methods; with utf8mb4_unicode_ci that collides with api_namespace.
        my $has_api_namespace = Koha::Plugins::Methods->search(
            {
                plugin_class  => $class,
                plugin_method => 'api_namespace',
            }
        )->count;
        if ( !$has_api_namespace ) {
            Koha::Plugins::Methods->search(
                {
                    plugin_class  => $class,
                    plugin_method => 'API_NAMESPACE',
                }
            )->delete();
        }

        my @hooks = qw(
        enable
        disable
        install
        uninstall
        upgrade
        intranet_js
        intranet_head
        intranet_catalog_biblio_enhancements_toolbar_button
        opac_js
        opac_head
        tool
        api_namespace
        api_routes
        static_routes
        cronjob_nightly
    );

        my $fixed = 0;
        for my $method (@hooks) {
            next unless $self->can($method);
            my $exists = Koha::Plugins::Methods->search(
                {
                    plugin_class  => $class,
                    plugin_method => $method,
                }
            )->count;
            next if $exists;
            Koha::Plugins::Method->new(
                {
                    plugin_class  => $class,
                    plugin_method => $method,
                }
            )->store();
            $fixed++;
        }
        if ($fixed) {
            require Koha::Cache::Memory::Lite;
            Koha::Cache::Memory::Lite->clear_from_cache('enabled_plugins');
        }
        1;
    } or warn PLUGIN_NAME . " hook method repair: $@";
}

sub api_namespace {
    my ($self) = @_;
    return Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants::API_NAMESPACE;
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
    return Koha::Plugin::DFLiddle::SecurePublisherCredentials::Tool->dispatch($self);
}

sub _plugin_page_url {
    my ($self) = @_;
    return '/cgi-bin/koha/plugins/run.pl?class=' . $self->{class} . '&method=tool';
}

sub _biblionumber_from_context {
    my ( $self, $params ) = @_;
    if ( ref($params) eq 'HASH' ) {
        if ( defined $params->{biblionumber} && $params->{biblionumber} =~ /\A(\d+)\z/ ) {
            return $1;
        }
        if ( defined $params->{biblio_id} && $params->{biblio_id} =~ /\A(\d+)\z/ ) {
            return $1;
        }
        if ( ref( $params->{biblio} ) && $params->{biblio}->can('id') ) {
            my $id = $params->{biblio}->id;
            return $id if defined $id && $id =~ /\A(\d+)\z/;
        }
    }

    # Same query object detail.pl uses (more reliable than a fresh CGI under Plack).
    my $from_context = eval {
        require C4::Context;
        my $q = C4::Context->query;
        return unless $q;
        my $bn = scalar $q->param('biblionumber');
        return $bn if defined $bn && $bn =~ /\A(\d+)\z/;
        return;
    };
    return $from_context if defined $from_context;

    $self->{cgi} ||= CGI->new;
    my $bn = scalar $self->{cgi}->param('biblionumber');
    return $bn if defined $bn && $bn =~ /\A(\d+)\z/;
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

    # Koha 24.11 calls this from cat-toolbar.inc with no args; never die here.
    my $html = eval { $self->_toolbar_button_html($params) };
    if ($@) {
        warn PLUGIN_NAME . " toolbar button error: $@";
        return q{};
    }
    return $html // q{};
}

sub _toolbar_button_html {
    my ( $self, $params ) = @_;
    my $biblionumber = $self->_biblionumber_from_context($params);
    return q{} unless defined $biblionumber && $biblionumber =~ /\A\d+\z/;

    return q{} unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher;

    my $staff =
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->current_staff_patron;
    return q{} unless $staff;

    my $cred =
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher->matching_credentials_for_biblio(
        $biblionumber, $staff );
    return q{} unless $cred;

    my $has_erm =
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff);
    my $manage = $has_erm
        && (
        $staff->is_superlibrarian
        || Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope(
            $staff, $cred )
        );

    my $view_label   = VIEW_LOGIN_LABEL;
    my $manage_label = MANAGE_LOGIN_LABEL;
    eval {
        $view_label =
            Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N->translate(VIEW_LOGIN_LABEL);
        $manage_label =
            Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N->translate(MANAGE_LOGIN_LABEL);
        1;
    };
    $view_label   = CGI::escapeHTML($view_label);
    $manage_label = CGI::escapeHTML($manage_label);
    my $biblio_attr = CGI::escapeHTML($biblionumber);
    my $html        = qq{
        <div class="btn-group spc-toolbar" role="group">
          <a class="btn btn-default spc-view-login" data-biblionumber="$biblio_attr" href="#">
            <i class="fa fa-lock" aria-hidden="true"></i> $view_label
          </a>
    };

    if ($manage) {
        my $manage_href = CGI::escapeHTML( $self->_plugin_page_url . '&edit_id=' . ( 0 + $cred->id ) );
        $html .= qq{
          <a class="btn btn-default spc-manage-login" href="$manage_href">
            <i class="fa fa-pencil" aria-hidden="true"></i> $manage_label
          </a>
        };
    }

    $html .= '</div>';
    return $html;
}

sub opac_head {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    return unless Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->system_healthy_for_opac;

    return $self->_stylesheet_tag('css/spc.css');
}

sub opac_js {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    return unless Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->system_healthy_for_opac;

    return $self->_script_tag('js/spc-config.js')
        . $self->_spc_label_bootstrap_script()
        . $self->_script_tag('js/spc-opac.js');
}

sub intranet_head {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    return $self->_stylesheet_tag('css/spc.css');
}

sub intranet_js {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    return $self->_script_tag('js/spc-config.js')
        . $self->_spc_label_bootstrap_script()
        . $self->_script_tag('js/spc-staff.js');
}

sub _spc_label_bootstrap_script {
    my ($self) = @_;
    my $view   = VIEW_LOGIN_LABEL;
    my $manage = MANAGE_LOGIN_LABEL;
    eval {
        require Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N;
        $view   = Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N->translate($view);
        $manage = Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N->translate($manage);
        1;
    };
    my $nonce = $self->_csp_nonce;
    my $attr  = '';
    if ( defined $nonce && $nonce ne '' ) {
        $attr = ' nonce="' . CGI::escapeHTML($nonce) . '"';
    }
    my $view_js   = Mojo::JSON::encode_json($view);
    my $manage_js = Mojo::JSON::encode_json($manage);
    return qq{<script$attr>window.SPC=window.SPC||{};window.SPC.VIEW_LABEL=$view_js;window.SPC.MANAGE_LABEL=$manage_js;</script>};
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
    my $enabled = $self->retrieve_data('__ENABLED__');
    return !defined $enabled || $enabled;
}

=head3 cronjob_nightly

Purge access log entries older than L<AccessLogs/RETENTION_DAYS>.
Invoked by Koha's C<plugins_nightly.pl> (included in C<koha-common> daily cron).

=cut

sub cronjob_nightly {
    my ($self) = @_;

    return 1 unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;

    my $days =
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->retention_days;
    my $deleted =
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->purge_older_than_days(
        $days );

    print PLUGIN_NAME . ": purged $deleted access log entries older than $days days.\n";
    return 1;
}

1;
