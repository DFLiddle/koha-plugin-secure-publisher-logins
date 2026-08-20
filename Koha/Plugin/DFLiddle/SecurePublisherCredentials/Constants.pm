package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants;

use Modern::Perl;
use Exporter qw(import);

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants

Shared display strings (English msgids) and API path pieces. Translate
via F<I18N.pm> and F<po/*.po>. JavaScript copies the English fallback
in F<js/spc-config.js> (keep those in sync).

=cut

use constant PLUGIN_NAME        => 'Secure Publisher Logins';
use constant VIEW_LOGIN_LABEL   => 'View login info';
use constant MANAGE_LOGIN_LABEL => 'Manage login info';
use constant API_NAMESPACE      => 'secure_publisher_credentials';
use constant API_BASE_PATH      => '/api/v1/contrib/' . API_NAMESPACE;
use constant TOOL_LOG_LIMIT     => 1000;

# Do not import API_NAMESPACE into SecurePublisherCredentials.pm (main plugin
# class): it becomes a public method and collides with api_namespace in
# plugin_methods under MySQL utf8mb4_unicode_ci.

our @EXPORT_OK = qw(
    PLUGIN_NAME
    VIEW_LOGIN_LABEL
    MANAGE_LOGIN_LABEL
    API_NAMESPACE
    API_BASE_PATH
    TOOL_LOG_LIMIT
);

1;
