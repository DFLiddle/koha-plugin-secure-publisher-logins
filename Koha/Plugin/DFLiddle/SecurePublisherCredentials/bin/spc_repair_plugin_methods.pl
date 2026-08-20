#!/usr/bin/perl

use Modern::Perl;

use FindBin qw($Bin);
use lib "$Bin/../../../../../";

use Koha::Script;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants qw( PLUGIN_NAME );

=head1 NAME

spc_repair_plugin_methods.pl - Register Secure Publisher Logins Koha hooks

=head1 SYNOPSIS

  spc_repair_plugin_methods.pl

Repairs the plugin_methods table for this plugin only. Use when
misc/devel/install_plugins.pl fails with Duplicate entry on api_namespace
(Koha 24.11 registers every public method and can choke on duplicates)
or when staff pages lack spc-staff.js (intranet_js not registered)
or when Disable on the Plugins page has no effect (enable/disable not registered).

Does not run InstallPlugins for other plugins.

=cut

my $class = 'Koha::Plugin::DFLiddle::SecurePublisherCredentials';

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

eval {
    require Koha::Plugins::Methods;
    require Koha::Plugins::Method;
    require Koha::Cache::Memory::Lite;

    my $plugin = $class->new();
    unless ($plugin) {
        die "Could not instantiate $class (is enable_plugins set?)\n";
    }

    my $added = 0;
    for my $method (@hooks) {
        next unless $plugin->can($method);
        my $exists = Koha::Plugins::Methods->search(
            {
                plugin_class  => $class,
                plugin_method => $method,
            }
        )->count;
        if ($exists) {
            print "ok  $method\n";
            next;
        }
        Koha::Plugins::Method->new(
            {
                plugin_class  => $class,
                plugin_method => $method,
            }
        )->store();
        print "add $method\n";
        $added++;
    }

    if ($added) {
        Koha::Cache::Memory::Lite->clear_from_cache('enabled_plugins');
        print PLUGIN_NAME . ": registered $added hook method(s).\n";
    }
    else {
        print PLUGIN_NAME . ": all hook methods already registered.\n";
    }
    1;
} or do {
    print PLUGIN_NAME . " repair failed: $@\n";
    exit 1;
};

exit 0;
