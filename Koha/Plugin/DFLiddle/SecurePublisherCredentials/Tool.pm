package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Tool;

use Modern::Perl;
use CGI qw(-utf8);

use Koha::Database;
use Koha::Libraries;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health;

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Tool - Staff tool pages

Koha invokes C<tool> on the plugin class; that method delegates here.

=cut

sub dispatch {
    my ( $class, $plugin ) = @_;
    $plugin->{cgi} ||= CGI->new;
    my $cgi = $plugin->{cgi};

    my $staff = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->current_staff_patron;
    unless ($staff) {
        return _deny( $plugin, 'Login required' );
    }

    unless ( Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff) ) {
        return _deny( $plugin, 'Cataloguing permission required' );
    }

    my $health = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health->check;

    if ( $cgi->param('action') eq 'save' ) {
        return $class->save( $plugin, $staff );
    }
    if ( my $delete_id = $cgi->param('delete_id') ) {
        return $class->delete( $plugin, $staff, $delete_id );
    }
    if ( $cgi->param('view') eq 'log' ) {
        return $class->log( $plugin, $staff );
    }

    my $edit_id = $cgi->param('edit_id');
    if ($edit_id) {
        return $class->form( $plugin, $staff, $health, $edit_id );
    }
    if ( $cgi->param('action') eq 'new' ) {
        return $class->form( $plugin, $staff, $health );
    }

    return $class->list( $plugin, $staff, $health );
}

sub list {
    my ( $class, $plugin, $staff, $health ) = @_;

    my $all     = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->search( {} );
    my @visible = grep {
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope( $staff, $_ )
            || $staff->is_superlibrarian
            || ( $_->access_scope_type ne 'inactive'
            && Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff) )
    } @{$all};

    my ( $libraries, $groups ) = _libraries_and_groups();
    my %lib_names    = map { $_->branchcode => $_->branchname } @{$libraries};
    my %group_titles = map { $_->{id}       => $_->{title} } @{$groups};

    my @login_rows = map {
        {
            login       => $_,
            scope_label => $_->access_scope_label( \%lib_names, \%group_titles ),
        }
    } @visible;

    my $template = $plugin->get_template( { file => 'templates/tool_list.tt' } );
    $template->param(
        login_rows   => \@login_rows,
        health       => $health,
        can_manage   => Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_has_erm($staff),
        is_superlib  => $staff->is_superlibrarian,
        plugin_class => $plugin->{class},
        plugin_title => Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants::PLUGIN_NAME,
    );
    $plugin->output_html( $template->output() );
}

sub form {
    my ( $class, $plugin, $staff, $health, $edit_id, $save_result, $form_values ) = @_;

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
            return _deny( $plugin, 'Not authorized' );
        }
    } elsif ($form_values) {
        require Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential;
        $credential = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential->new($form_values);
    }

    my ( $libraries, $groups ) = _libraries_and_groups();

    my $template = $plugin->get_template( { file => 'templates/tool_form.tt' } );
    $template->param(
        credential   => $credential,
        libraries    => $libraries,
        groups       => $groups,
        health       => $health,
        is_superlib  => $staff->is_superlibrarian,
        plugin_class => $plugin->{class},
        plugin_title => Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants::PLUGIN_NAME,
        save_error   => $save_result ? $class->_save_error_message($save_result) : undef,
        tool_form_js => $plugin->_static_url('js/spc-tool-form.js'),
        csp_nonce    => $plugin->_csp_nonce,
    );
    $plugin->output_html( $template->output() );
}

sub save {
    my ( $class, $plugin, $staff ) = @_;
    my $cgi = $plugin->{cgi};

    my ( $scope_type, $scope_code ) = _scope_from_cgi($cgi);

    if ( $scope_type eq 'all' && !$staff->is_superlibrarian ) {
        return _deny( $plugin, 'Only superlibrarians may create All libraries logins' );
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
            return _deny( $plugin, 'Not authorized' );
        }
        $result = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->update( $edit_id, $params );
        if ( $result->{id} ) {
            eval {
                Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->log_staff_action( $staff, 'update',
                    $edit_id );
                1;
            };
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
        return $class->form(
            $plugin,
            $staff,
            Koha::Plugin::DFLiddle::SecurePublisherCredentials::Health->check,
            $edit_id, $result, $params
        );
    }

    print $cgi->redirect( -uri => $plugin->_plugin_page_url );
}

sub delete {
    my ( $class, $plugin, $staff, $id ) = @_;

    my $credential = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->find($id);
    unless (
        $credential
        && (
            $staff->is_superlibrarian
            || Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_manage_scope( $staff,
                $credential )
        )
    ) {
        return _deny( $plugin, 'Not authorized' );
    }

    Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->delete($id);
    Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->log_staff_action( $staff, 'delete', $id );
    print $plugin->{cgi}->redirect( -uri => $plugin->_plugin_page_url );
}

sub log {
    my ( $class, $plugin, $staff ) = @_;
    unless ( Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->staff_may_view_log($staff) ) {
        return _deny( $plugin, 'Not authorized' );
    }
    my $logs     = Koha::Plugin::DFLiddle::SecurePublisherCredentials::AccessLogs->search(
        Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants::TOOL_LOG_LIMIT
    );
    my $template = $plugin->get_template( { file => 'templates/tool_log.tt' } );
    $template->param(
        logs         => $logs,
        plugin_class => $plugin->{class},
        plugin_title => Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants::PLUGIN_NAME,
    );
    $plugin->output_html( $template->output() );
}

sub _libraries_and_groups {
    my @libraries = Koha::Libraries->search( {}, { order_by => ['branchname'] } )->as_list;
    my $dbh       = Koha::Database->dbh;
    my $groups    = eval {
        $dbh->selectall_arrayref(
            'SELECT id, title FROM library_groups WHERE parent_id IS NULL ORDER BY title',
            { Slice => {} }
        );
    } // [];
    $groups = [] if $@ || ref($groups) ne 'ARRAY';
    return ( \@libraries, $groups );
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
    my ( $class, $result ) = @_;
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

sub _deny {
    my ( $plugin, $message ) = @_;
    print $plugin->{cgi}->header;
    print "<h1>$message</h1>";
    return;
}

1;
