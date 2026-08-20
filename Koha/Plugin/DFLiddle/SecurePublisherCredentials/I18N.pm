package Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N;

use Modern::Perl;
use File::Basename qw(dirname);

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::I18N

Look up this plugin's C<po/*.po> catalog for the current Koha language.
Koha 24.11 does not install plugin PO files into core locales (Bug 37472),
so translations must be applied here.

This module must never throw: staff hooks and plugin install call it.

=cut

my %catalog_cache;

my %TEMPLATE_MSGIDS = (
    add_login        => 'Add login info',
    edit_login       => 'Edit login info',
    view_log         => 'View access log',
    access_log       => 'Publisher login access log',
    back_to_list     => 'Back to login list',
    publisher        => 'Publisher',
    publisher_name   => 'Publisher name:',
    domains          => 'Domains',
    domains_label    => 'Registrable domains (comma-separated):',
    accessible       => 'Accessible by',
    accessible_colon => 'Accessible by:',
    all_libraries    => 'All libraries:',
    library          => 'Library:',
    library_group    => 'Library group:',
    inactive         => 'None (inactive):',
    actions          => 'Actions',
    edit             => 'Edit',
    delete           => 'Delete',
    delete_confirm   => 'Delete this publisher login?',
    save             => 'Save',
    cancel           => 'Cancel',
    username         => 'Username:',
    password         => 'Password:',
    keep_password    => 'Leave blank to keep unchanged',
    patron_note      => 'Patron note:',
    staff_note       => 'Staff note:',
    config_required  => 'Configuration required:',
    when             => 'When',
    login_id         => 'Login ID',
    borrowernumber   => 'Borrowernumber',
    action           => 'Action',
    biblionumber     => 'Biblionumber',
);

sub translate {
    my ( $class, $msgid ) = @_;
    return $msgid unless defined $msgid && $msgid ne '';
    my $out = eval {
        my $catalog = $class->catalog;
        $catalog->{$msgid};
    };
    return ( defined $out && $out ne '' ) ? $out : $msgid;
}

sub catalog {
    my ($class) = @_;
    my $lang = eval { $class->language } || 'en';
    return $catalog_cache{$lang} if exists $catalog_cache{$lang};
    $catalog_cache{$lang} = eval { $class->_load_po($lang) } || {};
    return $catalog_cache{$lang};
}

sub template_labels {
    my ($class) = @_;
    my %out;
    for my $key ( keys %TEMPLATE_MSGIDS ) {
        $out{$key} = $class->translate( $TEMPLATE_MSGIDS{$key} );
        $out{$key} ||= $TEMPLATE_MSGIDS{$key};
    }
    return \%out;
}

sub english_template_labels {
    my ($class) = @_;
    return { map { $_ => $TEMPLATE_MSGIDS{$_} } keys %TEMPLATE_MSGIDS };
}

sub language {
    my ($class) = @_;

    # Cookie first: REST runs as interface=api and getlanguage() ignores KohaOpacLanguage.
    my $lang = eval { $class->_cookie_language };
    $lang ||= eval {
        require C4::Languages;
        require C4::Context;
        my $cgi = $class->_cgi;
        $cgi ? C4::Languages::getlanguage($cgi) : C4::Languages::getlanguage();
    };
    $lang = $class->_normalize_lang( $lang || 'en' );
    return $class->_validate_lang($lang) || 'en';
}

sub debug_info {
    my ($class) = @_;
    my $lang    = eval { $class->language } || 'en';
    my $path    = eval { $class->_po_path($lang) };
    my $catalog = eval { $class->catalog } || {};
    return {
        language     => $lang,
        po_path      => $path // '',
        po_entries   => scalar keys %$catalog,
        cookie_lang  => eval { $class->_cookie_language } // '',
        view_label   => $class->translate('View login info'),
        staff_langs  => [
            $class->_languages_from_pref('StaffInterfaceLanguages')
                || $class->_languages_from_pref('language')
                || []
        ],
        opac_langs   => [ $class->_languages_from_pref('OPACLanguages') || [] ],
        interface    => eval {
            require C4::Context;
            C4::Context->interface;
        } // '',
    };
}

sub _cgi {
    my ($class) = @_;
    return eval {
        require C4::Context;
        C4::Context->query;
    };
}

sub _cookie_language {
    my ($class) = @_;

    my $from_cgi = eval {
        my $cgi = $class->_cgi;
        $cgi ? scalar $cgi->cookie('KohaOpacLanguage') : undef;
    };
    if ( defined $from_cgi && $from_cgi ne '' ) {
        return $class->_normalize_lang( $from_cgi );
    }

    my $raw = $ENV{HTTP_COOKIE} // '';
    if ( $raw =~ /(?:^|;\s*)KohaOpacLanguage=([^;]+)/ ) {
        return $class->_normalize_lang($1);
    }
    return;
}

sub _normalize_lang {
    my ( $class, $lang ) = @_;
    return 'en' unless defined $lang && $lang ne '';
    $lang =~ s/_/-/g;
    $lang =~ s/[^a-zA-Z0-9-]//g;
    return length $lang ? $lang : 'en';
}

sub _validate_lang {
    my ( $class, $lang ) = @_;
    $lang = $class->_normalize_lang($lang);
    return 'en' if $lang =~ /^en/i;

    # KohaOpacLanguage is shared across staff and OPAC. If the user chose this
    # language (cookie) and we ship a PO file, use it even when StaffInterfaceLanguages
    # and OPACLanguages differ (common when testing OPAC before staff).
    my $cookie = eval { $class->_cookie_language };
    if ( defined $cookie && $cookie eq $lang && $class->_po_path($lang) ) {
        return $lang;
    }

    my $interface = eval {
        require C4::Context;
        C4::Context->interface;
    } || 'intranet';
    return $lang if $interface eq 'api';
    my @enabled = eval { $class->_enabled_languages };
    return $lang unless @enabled;
    return $lang if grep { $_ eq $lang } @enabled;
    return;
}

sub _enabled_languages {
    my ($class) = @_;
    require C4::Context;
    my $interface = eval { C4::Context->interface } || 'intranet';
    if ( $interface eq 'opac' ) {
        return $class->_languages_from_pref('OPACLanguages');
    }
    my @staff = $class->_languages_from_pref('StaffInterfaceLanguages')
        || $class->_languages_from_pref('language')
        || [];
    my @opac = $class->_languages_from_pref('OPACLanguages') || [];
    my %seen;
    return grep { !$seen{$_}++ } ( @staff, @opac );
}

sub _languages_from_pref {
    my ( $class, $pref ) = @_;
    my $value = C4::Context->preference($pref);
    return unless defined $value && $value ne '';
    return map { $class->_normalize_lang($_) } split /\s*,\s*/, $value;
}

sub _load_po {
    my ( $class, $lang ) = @_;
    return {} if $lang =~ /^en/i;
    my $path = $class->_po_path($lang);
    return {} unless $path && -f $path;
    return $class->_parse_po($path);
}

sub _po_path {
    my ( $class, $lang ) = @_;
    my $dir = dirname(__FILE__) . '/po';
    return unless -d $dir;

    my @try = ($lang);
    if ( $lang =~ /^([a-zA-Z]{2})-/ ) {
        push @try, $1;
    }
    elsif ( $lang =~ /^([a-zA-Z]{2})$/ ) {
        my $prefix = lc $1;
        if ( opendir my $dh, $dir ) {
            my @hits = grep { /^$prefix-/i && /\.po$/i } readdir $dh;
            closedir $dh;
            return "$dir/$hits[0]" if @hits;
        }
    }
    for my $cand (@try) {
        return "$dir/$cand.po" if -f "$dir/$cand.po";
    }
    return;
}

sub _parse_po {
    my ( $class, $path ) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or return {};
    my $text = do { local $/; <$fh> };
    close $fh;
    my %map;
    while ( $text =~ /msgid\s+"((?:\\.|[^"\\])*)"\s+msgstr\s+"((?:\\.|[^"\\])*)"/sg ) {
        my ( $id, $str ) = ( $1, $2 );
        next if $id eq '';
        $id  =~ s/\\n/\n/g;
        $id  =~ s/\\"/"/g;
        $str =~ s/\\n/\n/g;
        $str =~ s/\\"/"/g;
        $map{$id} = $str if $str ne '';
    }
    return \%map;
}

1;
