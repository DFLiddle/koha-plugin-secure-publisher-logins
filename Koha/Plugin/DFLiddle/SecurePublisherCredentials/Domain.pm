package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Domain;

use Modern::Perl;
use URI;

use parent qw(Exporter);
our @EXPORT_OK = qw(
    extract_registrable_domain
    normalize_domain
    validate_registrable_domain
    domains_match
);

# Common multi-part public suffixes (minimal set; Net::PublicSuffix preferred when available)
my @MULTI_PART_SUFFIXES = qw(
    co.uk org.uk ac.uk gov.uk
    com.au net.au org.au
    co.nz org.nz
    co.za org.za
);

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Domain - Registrable domain helpers

=cut

sub normalize_domain {
    my ($domain) = @_;
    return unless defined $domain;
    $domain = lc $domain;
    $domain =~ s/^\s+|\s+$//g;
    $domain =~ s/^\.+|\.+$//g;
    $domain =~ s/^www\.//;
    return $domain;
}

sub validate_registrable_domain {
    my ($domain) = @_;
    $domain = normalize_domain($domain);
    return ( 0, $domain ) unless $domain;
    return ( 0, $domain ) if length($domain) > 253;
    return ( 0, $domain ) unless $domain =~ /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\z/;
    return ( 0, $domain ) if $domain =~ /\.\./;
    return ( 1, $domain );
}

sub extract_registrable_domain {
    my ($url) = @_;
    return unless defined $url && length $url;

    my $uri = eval { URI->new($url) };
    return unless $uri && $uri->can('host') && $uri->host;

    my $host = normalize_domain( $uri->host );
    $host =~ s/^www\.//;

    if ( eval { require Net::PublicSuffix; 1 } ) {
        my $domain = Net::PublicSuffix->get_root_domain($host);
        return normalize_domain($domain) if $domain;
    }

    return _heuristic_etld1($host);
}

sub _heuristic_etld1 {
    my ($host) = @_;
    my @labels = split /\./, $host;
    return $host unless @labels >= 2;

    if ( @labels >= 3 ) {
        my $suffix = join '.', $labels[-2], $labels[-1];
        if ( grep { $_ eq $suffix } @MULTI_PART_SUFFIXES ) {
            return join '.', $labels[-3], $labels[-2], $labels[-1] if @labels >= 3;
        }
    }

    return join '.', $labels[-2], $labels[-1];
}

sub domains_match {
    my ( $record_domain, $credential_domains ) = @_;
    return unless $record_domain;
    $record_domain = normalize_domain($record_domain);
    for my $d ( @{$credential_domains} ) {
        my ( $ok, $norm ) = validate_registrable_domain($d);
        next unless $ok;
        return 1 if $record_domain eq $norm;
    }
    return;
}

1;
