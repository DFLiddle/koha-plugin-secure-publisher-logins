package Koha::Plugin::DFLiddle::SecurePublisherCredentials;

use Modern::Perl;
use CGI qw(-utf8);
use Mojo::JSON qw(decode_json encode_json);

use Koha::Database;

use base qw(Koha::Plugins::Base);

our $VERSION = '1.2.8';

our $metadata = {
    name            => 'Secure Publisher Logins',
    author          => 'David F Liddle',
    description     => 'Securely store and share publisher login details for e-resources matched via 856$u domains.',
    date_authored   => '2026-08-14',
    date_updated    => '2026-08-18',
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
    return 'secure_publisher_credentials';
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
    $self->{cgi} ||= CGI->new;
    my $cgi = $self->{cgi};

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health;

    my $staff = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->current_staff_patron;
    unless ($staff) {
        print $cgi->header;
        print '<h1>Login required</h1>';
        return;
    }

    unless ( Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff) ) {
        print $cgi->header;
        print '<h1>Cataloguing permission required</h1>';
        return;
    }

    my $health = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health->check;

    if ( $cgi->param('action') eq 'save' ) {
        return $self->_tool_save($staff);
    }
    if ( my $delete_id = $cgi->param('delete_id') ) {
        return $self->_tool_delete( $staff, $delete_id );
    }
    if ( $cgi->param('view') eq 'log' ) {
        return $self->_tool_log($staff);
    }

    my $edit_id = $cgi->param('edit_id');
    if ($edit_id) {
        return $self->_tool_form( $staff, $health, $edit_id );
    }
    if ( $cgi->param('action') eq 'new' ) {
        return $self->_tool_form( $staff, $health );
    }

    return $self->_tool_list( $staff, $health );
}

sub _tool_list {
    my ( $self, $staff, $health ) = @_;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
    require Koha::Libraries;

    my $all = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->search( {} );
    my @visible = grep {
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope( $staff, $_ )
            || $staff->is_superlibrarian
            || ( $_->access_scope_type ne 'inactive'
            && Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff) )
    } @{$all};

    my @libraries = Koha::Libraries->search( {}, { order_by => ['branchname'] } )->as_list;
    my %lib_names = map { $_->branchcode => $_->branchname } @libraries;

    my $dbh    = Koha::Database->dbh;
    my $groups = eval {
        $dbh->selectall_arrayref(
            'SELECT id, title FROM library_groups WHERE parent_id IS NULL ORDER BY title',
            { Slice => {} }
        );
    } // [];
    $groups = [] if $@ || ref($groups) ne 'ARRAY';
    my %group_titles = map { $_->{id} => $_->{title} } @{$groups};

    my @login_rows = map {
        {
            login       => $_,
            scope_label => $_->access_scope_label( \%lib_names, \%group_titles ),
        }
    } @visible;

    my $template = $self->get_template( { file => 'templates/tool_list.tt' } );
    $template->param(
        login_rows  => \@login_rows,
        health      => $health,
        can_manage  => Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff),
        is_superlib => $staff->is_superlibrarian,
        plugin_class => $self->{class},
    );
    $self->output_html( $template->output() );
}

sub _tool_form {
    my ( $self, $staff, $health, $edit_id, $save_result, $form_values ) = @_;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
    require Koha::Libraries;

    my $credential;
    if ($edit_id) {
        $credential = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->find($edit_id);
        unless (
            $credential
            && (
                $staff->is_superlibrarian
                || Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope(
                    $staff, $credential )
            )
        ) {
            print $self->{cgi}->header;
            print '<h1>Not authorized</h1>';
            return;
        }
    } elsif ($form_values) {
        require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential;
        $credential = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential->new($form_values);
    }

    my @libraries = Koha::Libraries->search( {}, { order_by => ['branchname'] } )->as_list;
    my $dbh       = Koha::Database->dbh;
    my $groups    = eval {
        $dbh->selectall_arrayref(
            'SELECT id, title FROM library_groups WHERE parent_id IS NULL ORDER BY title',
            { Slice => {} }
        );
    } // [];
    $groups = [] if $@ || ref($groups) ne 'ARRAY';

    my $template = $self->get_template( { file => 'templates/tool_form.tt' } );
    $template->param(
        credential   => $credential,
        libraries    => \@libraries,
        groups       => $groups,
        health       => $health,
        is_superlib  => $staff->is_superlibrarian,
        plugin_class => $self->{class},
        save_error   => $save_result ? $self->_save_error_message($save_result) : undef,
    );
    $self->output_html( $template->output() );
}

sub _scope_from_cgi {
    my ($cgi) = @_;
    my $scope_type = scalar $cgi->param('access_scope_type');
    my $scope_code = scalar $cgi->param('access_scope_code');

    if ( $scope_type eq 'library' ) {
        my $library = scalar $cgi->param('access_scope_code_library');
        $scope_code = $library if ( !defined $scope_code || $scope_code eq '' ) && $library ne '';
    } elsif ( $scope_type eq 'library_group' ) {
        my $group = scalar $cgi->param('access_scope_code_group');
        $scope_code = $group if ( !defined $scope_code || $scope_code eq '' ) && $group ne '';
    }

    if ( $scope_type eq 'all' || $scope_type eq 'inactive' ) {
        $scope_code = undef;
    } elsif ( defined $scope_code && $scope_code eq '' ) {
        $scope_code = undef;
    }

    return ( $scope_type, $scope_code );
}

sub _save_error_message {
    my ( $self, $result ) = @_;
    return unless $result && $result->{error};

    if ( $result->{error} eq 'duplicate' ) {
        return 'A publisher login with this name and access scope already exists.';
    }
    if ( $result->{error} eq 'invalid_domains' ) {
        my $list = join( ', ', @{ $result->{invalid} // [] } );
        return "Invalid domain(s): $list";
    }
    if ( $result->{error} eq 'no_domains' ) {
        return 'Enter at least one valid registrable domain.';
    }
    if ( $result->{error} eq 'encryption' ) {
        return 'Could not encrypt the password. Check encryption_key in koha-conf.xml.';
    }
    if ( $result->{error} eq 'database' ) {
        my $msg = $result->{message} // '';
        if ( $msg =~ /doesn't exist/i ) {
            return 'Database tables are missing. Disable and re-enable the plugin, or run install_plugins.pl, then try again.';
        }
        return "Database error while saving: $msg";
    }
    return 'Could not save the publisher login.';
}

sub _tool_save {
    my ( $self, $staff ) = @_;
    my $cgi = $self->{cgi};

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;

    my ( $scope_type, $scope_code ) = _scope_from_cgi($cgi);

    if ( $scope_type eq 'all' && !$staff->is_superlibrarian ) {
        print $cgi->header;
        print '<h1>Only superlibrarians may create All libraries logins</h1>';
        return;
    }

    my $params = {
        publisher_name    => scalar $cgi->param('publisher_name'),
        domains           => scalar $cgi->param('domains'),
        username          => scalar $cgi->param('username'),
        password          => scalar $cgi->param('password'),
        access_scope_type => $scope_type,
        access_scope_code => $scope_code,
        staff_note        => scalar $cgi->param('staff_note'),
        patron_note       => scalar $cgi->param('patron_note'),
    };

    my $edit_id = scalar $cgi->param('id');
    my $result;
    if ($edit_id) {
        my $existing = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->find($edit_id);
        unless (
            $existing
            && (
                $staff->is_superlibrarian
                || Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope(
                    $staff, $existing )
            )
        ) {
            print $cgi->header;
            print '<h1>Not authorized</h1>';
            return;
        }
        $result = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->update( $edit_id, $params );
        if ( $result->{id} ) {
            eval { Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->log_staff_action( $staff, 'update', $edit_id ); 1 };
        }
    } else {
        $result = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->create($params);
        if ( $result->{id} ) {
            eval {
                Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->log_staff_action(
                    $staff, 'create', $result->{id} );
                1;
            };
        }
    }

    if ( $result->{error} ) {
        return $self->_tool_form(
            $staff,
            Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health->check,
            $edit_id, $result, $params
        );
    }

    print $cgi->redirect( -uri => $self->_plugin_page_url );
}

sub _plugin_page_url {
    my ($self) = @_;
    return '/cgi-bin/koha/plugins/run.pl?class=' . $self->{class} . '&method=tool';
}

sub _tool_delete {
    my ( $self, $staff, $id ) = @_;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;

    my $credential = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->find($id);
    unless (
        $credential
        && (
            $staff->is_superlibrarian
            || Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope( $staff,
                $credential )
        )
    ) {
        print $self->{cgi}->header;
        print '<h1>Not authorized</h1>';
        return;
    }

    Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->delete($id);
    Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->log_staff_action( $staff, 'delete', $id );
    print $self->{cgi}->redirect( -uri => $self->_plugin_page_url );
}

sub _tool_log {
    my ( $self, $staff ) = @_;
    unless ( Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_view_log($staff) ) {
        print $self->{cgi}->header;
        print '<h1>Not authorized</h1>';
        return;
    }
    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;
    my $logs = Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->search(1000);
    my $template = $self->get_template( { file => 'templates/tool_log.tt' } );
    $template->param( logs => $logs, plugin_class => $self->{class} );
    $self->output_html( $template->output() );
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

    my $staff = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->current_staff_patron;
    return unless $staff;

    my $cred = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher->matching_credentials_for_biblio(
        $biblionumber, $staff );
    return unless $cred;

    my $has_erm = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff);
    my $manage  = $has_erm
        && (
        $staff->is_superlibrarian
        || Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope( $staff, $cred )
        );

    my $biblio_attr = CGI::escapeHTML($biblionumber);
    my $html        = qq{
        <span class="spc-toolbar">
          <a class="btn btn-default spc-view-login" data-biblionumber="$biblio_attr" href="#">
            <i class="fa fa-lock" aria-hidden="true"></i> View login info
          </a>
    };

    if ($manage) {
        my $manage_href = CGI::escapeHTML( $self->_plugin_page_url . '&edit_id=' . ( 0 + $cred->id ) );
        $html .= qq{
          <a class="btn btn-default" href="$manage_href">
            <i class="fa fa-pencil" aria-hidden="true"></i> Manage login info
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
    return unless Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->system_healthy_for_opac;

    return $self->_stylesheet_tag('css/spc.css');
}

sub opac_js {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
    return unless Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->system_healthy_for_opac;

    return $self->_script_tag('js/spc-opac.js');
}

sub intranet_head {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    return $self->_stylesheet_tag('css/spc.css');
}

sub intranet_js {
    my ($self) = @_;
    return unless $self->_plugin_enabled;

    return $self->_script_tag('js/spc-staff.js');
}

sub _static_url {
    my ( $self, $rel ) = @_;

    # No query string: Koha's OpenAPI validator rejects undeclared params
    # (a ?v= cache-buster 400s and the browser never executes the file).
    return '/api/v1/contrib/' . $self->api_namespace . '/static/' . $rel;
}

sub _stylesheet_tag {
    my ( $self, $rel ) = @_;
    my $href = CGI::escapeHTML( $self->_static_url($rel) );
    return qq{<link rel="stylesheet" type="text/css" href="$href">};
}

sub _script_tag {
    my ( $self, $rel ) = @_;
    my $src = CGI::escapeHTML( $self->_static_url($rel) );
    return qq{<script src="$src"></script>};
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

    my $days    = Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->retention_days;
    my $deleted = Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->purge_older_than_days($days);

    print "Secure Publisher Logins: purged $deleted access log entries older than $days days.\n";
    return 1;
}

1;
