package Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames;

use Modern::Perl;

use constant PLUGIN_CLASS => 'Koha::Plugin::DFLiddle::SecurePublisherCredentials';

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::TableNames - Plugin table names

Uses the same algorithm as Koha::Plugins::Base::get_qualified_table_name.

=cut

sub qualified {
    my ( $class, $suffix ) = @_;
    return lc join '_', split( '::', PLUGIN_CLASS ), $suffix;
}

sub credentials { return shift->qualified('credentials') }
sub access_log  { return shift->qualified('access_log') }

1;
