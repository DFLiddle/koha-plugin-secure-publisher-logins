package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants;

use Modern::Perl;
use Exporter qw(import);

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants

Shared display strings (English msgids) and API path pieces. Translate
via F<I18N.pm> and F<po/*.po>. JavaScript copies the English fallback
in F<js/spc-config.js> (keep those in sync).

=cut

use constant PLUGIN_NAME                 => 'Secure Publisher Logins';
use constant VIEW_LOGIN_LABEL            => 'View login info';
use constant MANAGE_LOGIN_LABEL          => 'Manage login info';
use constant LOGIN_TO_CHECK_ACCESS_LABEL => 'Log in to check access';
use constant LIBRARY_NOT_SUBSCRIBED_LABEL => 'Library not subscribed';
use constant LOGIN_INFO_NOT_AVAILABLE_LABEL => 'Login info not available';
use constant SCOPE_DENIED_MESSAGE =>
    'Your library is not subscribed to this online resource. Click the link below to suggest it for purchase.';
use constant SUGGEST_FOR_PURCHASE_LABEL => 'Suggest for purchase';
use constant ACCOUNT_BLOCKED_MESSAGE =>
    'Your account requires attention before the login info can be shown. Please write to %s for help.';
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
    LOGIN_TO_CHECK_ACCESS_LABEL
    LIBRARY_NOT_SUBSCRIBED_LABEL
    LOGIN_INFO_NOT_AVAILABLE_LABEL
    SCOPE_DENIED_MESSAGE
    SUGGEST_FOR_PURCHASE_LABEL
    ACCOUNT_BLOCKED_MESSAGE
    API_NAMESPACE
    API_BASE_PATH
    TOOL_LOG_LIMIT
);

1;
