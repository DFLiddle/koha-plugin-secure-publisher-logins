#!/usr/bin/perl

use Modern::Perl;

use FindBin qw($Bin);
use lib "$Bin/../../../../../";

use Koha::Script;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Constants qw( PLUGIN_NAME );
use Koha::Plugin::DFLiddle::SecurePublisherCredentials ();

=head1 NAME

spc_diagnose_plugin_methods.pl - Inspect plugin_methods vs Class::Inspector

=head1 SYNOPSIS

  spc_diagnose_plugin_methods.pl

Prints public methods Koha would register via InstallPlugins (Class::Inspector),
highlights duplicate names, and lists rows currently in plugin_methods for this plugin.

Use when misc/devel/install_plugins.pl fails with Duplicate entry on api_namespace.

=cut

my $class = 'Koha::Plugin::DFLiddle::SecurePublisherCredentials';

eval {
    require Class::Inspector;
    require Koha::Plugins::Methods;

    # Same args as Koha::Plugins::InstallPlugins (loads even if plugins UI is off).
    my $plugin = $class->new( { enable_plugins => 1 } );
    unless ($plugin) {
        die "Could not instantiate $class\n";
    }

    my $methods_ref = Class::Inspector->methods( $class, 'public' );
    my @public      = ( $methods_ref && ref $methods_ref eq 'ARRAY' ) ? @$methods_ref : ();
    if ( !@public ) {
        die "Class::Inspector returned no public methods for $class\n";
    }

    my %count;
    for my $name (@public) {
        $count{$name}++;
    }

    print "=== Class::Inspector public methods ($class) ===\n";
    print "Total entries: " . scalar(@public) . "\n";
    print "Distinct names: " . scalar( keys %count ) . "\n";

    my @dupes = grep { $count{$_} > 1 } sort keys %count;
    if (@dupes) {
        print "Duplicates (cause InstallPlugins duplicate PRIMARY key):\n";
        for my $name (@dupes) {
            print "  $name x$count{$name}\n";
        }
    }
    else {
        print "No duplicate method names in Class::Inspector list.\n";
    }

    if ( exists $count{api_namespace} ) {
        print "api_namespace count: $count{api_namespace}\n";
    }
    else {
        print "api_namespace: not listed as public\n";
    }

    my $has_api_namespace_row = Koha::Plugins::Methods->search(
        {
            plugin_class  => $class,
            plugin_method => 'api_namespace',
        }
    )->count;
    my $has_api_namespace_constant_row = Koha::Plugins::Methods->search(
        {
            plugin_class  => $class,
            plugin_method => 'API_NAMESPACE',
        }
    )->count;
    if ( !$has_api_namespace_row && $has_api_namespace_constant_row ) {
        print "\nWARNING: plugin_methods has API_NAMESPACE but not api_namespace.\n";
        print "MySQL ci collation treats them as duplicate; InstallPlugins fails and REST may miss routes.\n";
        print "Run spc_repair_plugin_methods.pl or delete API_NAMESPACE and insert api_namespace.\n";
    }

    print "\n=== plugin_methods table (current rows) ===\n";
    my @rows;
    my $it = Koha::Plugins::Methods->search(
        { plugin_class => $class },
        { order_by     => 'plugin_method' }
    );
    while ( my $row = $it->next ) {
        push @rows, $row->plugin_method;
    }
    if (@rows) {
        print join( "\n", @rows ), "\n";
        print "Row count: " . scalar(@rows) . "\n";
    }
    else {
        print "(no rows)\n";
    }

    1;
} or do {
    print PLUGIN_NAME . " diagnose failed: $@\n";
    exit 1;
};

exit 0;
