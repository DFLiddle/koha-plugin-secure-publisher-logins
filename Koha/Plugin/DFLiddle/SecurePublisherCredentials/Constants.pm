package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants;

use Modern::Perl;
use Exporter qw(import);

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants

Shared display strings and API path pieces. JavaScript copies the same
values in F<js/spc-config.js> (keep those in sync).

=cut

use constant PLUGIN_NAME        => 'Secure Publisher Logins';
use constant VIEW_LOGIN_LABEL   => 'View login info';
use constant MANAGE_LOGIN_LABEL => 'Manage login info';
use constant API_NAMESPACE      => 'secure_publisher_credentials';
use constant API_BASE_PATH      => '/api/v1/contrib/' . API_NAMESPACE;
use constant TOOL_LOG_LIMIT     => 1000;

our @EXPORT_OK = qw(
    PLUGIN_NAME
    VIEW_LOGIN_LABEL
    MANAGE_LOGIN_LABEL
    API_NAMESPACE
    API_BASE_PATH
    TOOL_LOG_LIMIT
);

1;
