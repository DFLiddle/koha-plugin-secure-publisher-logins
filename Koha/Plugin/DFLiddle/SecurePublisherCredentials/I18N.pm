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

    # Prefer the language cookie: REST runs as interface=api, where
    # C4::Languages::getlanguage() may not see the OPAC/staff UI language.
    my $lang = eval { $class->_cookie_language };
    $lang ||= eval {
        require C4::Languages;
        C4::Languages::getlanguage();
    };
    $lang ||= 'en';
    $lang =~ s/_/-/g;
    $lang =~ s/[^a-zA-Z0-9-]//g;
    $lang = 'en' unless length $lang;
    return $lang;
}

sub _cookie_language {
    my $raw = $ENV{HTTP_COOKIE} // '';
    if ( $raw =~ /(?:^|;\s*)KohaOpacLanguage=([^;]+)/ ) {
        my $v = $1;
        $v =~ s/[^a-zA-Z0-9_-]//g;
        return $v if $v ne '';
    }
    my $from_cgi = eval {
        require CGI;
        scalar CGI->new->cookie('KohaOpacLanguage');
    };
    return unless defined $from_cgi && $from_cgi ne '';
    $from_cgi =~ s/[^a-zA-Z0-9_-]//g;
    return $from_cgi;
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
