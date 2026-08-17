package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher;

use Modern::Perl;

use URI;
use MARC::Record;

use C4::Context;

use Koha::Biblios;

use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials;
use Koha::Plugin::DFLiddle::SecurePublisherCredentials::Domain qw(
    extract_registrable_domain domains_match
);

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Matcher - Match bibs to credentials

=cut

sub _normalize_marc_url {
    my ($url) = @_;
    return unless defined $url;
    $url =~ s/^\s+|\s+$//g;
    return $url if $url =~ m{\Ahttps?://}i;
    return "http://$url" if $url =~ m{\A[a-z0-9][a-z0-9.-]*\.[a-z]{2,}}i;
    return;
}

sub _urls_from_856_field {
    my ($field) = @_;
    my @urls;
    for my $subfield ( $field->subfields ) {
        my ( $code, $value ) = @{$subfield};
        next unless defined $code && $code =~ /^[uzy]$/i;
        my $url = _normalize_marc_url($value);
        push @urls, $url if $url;
    }
    return @urls;
}

sub _marc_record_for_biblio {
    my ( $class, $biblio, $biblionumber ) = @_;

    my $record = eval { $biblio->metadata->record };
    if ( !$record || !$record->isa('MARC::Record') ) {
        $record = eval { $biblio->metadata_record( { embed_items => 0 } ) };
    }
    if ( !$record || !$record->isa('MARC::Record') ) {
        my $metadata = eval { $biblio->metadata };
        if ( $metadata && $metadata->can('metadata') && $metadata->metadata ) {
            $record = eval {
                MARC::Record::new_from_xml(
                    $metadata->metadata,
                    'UTF-8',
                    C4::Context->preference('marcflavour') // 'MARC21'
                );
            };
        }
    }
    return $record if $record && $record->isa('MARC::Record');
    return;
}

sub biblio_856_urls {
    my ( $class, $biblionumber ) = @_;
    my $biblio = Koha::Biblios->find($biblionumber);
    return unless $biblio;

    my $record = $class->_marc_record_for_biblio( $biblio, $biblionumber );
    return unless $record;

    my @urls;
    for my $field ( $record->field('856') ) {
        push @urls, _urls_from_856_field($field);
    }
    return \@urls;
}

sub url_display_info {
    my ( $class, $url ) = @_;
    my $domain = extract_registrable_domain($url);
    my $uri    = eval { URI->new($url) };    ## no critic
    my $valid_link = ( $uri && $uri->can('host') && $uri->host ) ? 1 : 0;
    return {
        url             => $url,
        domain          => $domain,
        valid_link      => $valid_link,
        display_as_text => $valid_link ? 0 : 1,
    };
}

sub matching_credentials_for_biblio {
    my ( $class, $biblionumber, $viewer ) = @_;
    return unless $viewer;

    my $urls = $class->biblio_856_urls($biblionumber) || [];
    return unless @{$urls};

    my @record_domains;
    for my $url ( @{$urls} ) {
        my $d = extract_registrable_domain($url);
        push @record_domains, $d if $d;
    }
    return unless @record_domains;

    my $all = Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credentials->search(
        { not_inactive => 1 } );

    my @matches;
    for my $cred ( @{$all} ) {
        next unless Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access
            ->viewer_matches_credential_scope( $viewer, $cred );

        for my $rd ( @record_domains ) {
            if ( domains_match( $rd, $cred->domain_list ) ) {
                push @matches, $cred;
                last;
            }
        }
    }

    return unless @matches;
    return Koha::Plugin::DFLiddle::SecurePublisherCredentials::Access->pick_most_restrictive(@matches);
}

sub best_url_for_credential {
    my ( $class, $biblionumber, $credential ) = @_;
    my $urls = $class->biblio_856_urls($biblionumber) || [];
    for my $url ( @{$urls} ) {
        my $rd = extract_registrable_domain($url);
        next unless $rd;
        if ( domains_match( $rd, $credential->domain_list ) ) {
            return $class->url_display_info($url);
        }
    }
    return;
}

1;
