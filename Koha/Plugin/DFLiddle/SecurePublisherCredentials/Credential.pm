package Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential;

use Modern::Perl;

use Koha::Encryption;

=head1 NAME

Koha::Plugin::DFLiddle::SecurePublisherCredentials::Credential - Credential row object

=cut

sub new {
    my ( $class, $row ) = @_;
    bless { row => $row }, $class;
}

sub id                  { shift->{row}->{id} }
sub publisher_name      { shift->{row}->{publisher_name} }
sub domains             { shift->{row}->{domains} }
sub username            { shift->{row}->{username} }
sub password_encrypted  { shift->{row}->{password_encrypted} }
sub access_scope_type   { shift->{row}->{access_scope_type} }
sub access_scope_code   { shift->{row}->{access_scope_code} }
sub staff_note          { shift->{row}->{staff_note} }
sub patron_note         { shift->{row}->{patron_note} }
sub date_created        { shift->{row}->{date_created} }
sub date_modified       { shift->{row}->{date_modified} }

sub domain_list {
    my ($self) = @_;
    my $d = $self->domains // '';
    return [ grep { length } map { s/^\s+|\s+$//gr } split /,/, $d ];
}

sub access_scope_label {
    my ( $self, $lib_names, $group_titles ) = @_;
    $lib_names    //= {};
    $group_titles //= {};

    my $type = $self->access_scope_type // '';
    if ( $type eq 'all' ) {
        return 'All libraries';
    }
    if ( $type eq 'inactive' ) {
        return 'None (inactive)';
    }
    if ( $type eq 'library' ) {
        my $code = $self->access_scope_code // '';
        return $code ne '' ? "Library ($code)" : 'Library';
    }
    if ( $type eq 'library_group' ) {
        my $id = $self->access_scope_code;
        my $title = $group_titles->{$id} // $group_titles->{ 0 + ( $id // 0 ) } // $id;
        return "Library group ($title)";
    }
    return $type;
}

sub decrypt_password {
    my ($self) = @_;
    my $crypt = Koha::Encryption->new;
    return $crypt->decrypt_hex( $self->password_encrypted );
}

sub to_staff_hash {
    my ($self) = @_;
    return {
        id                => $self->id,
        publisher_name    => $self->publisher_name,
        domains           => $self->domains,
        username          => $self->username,
        access_scope_type => $self->access_scope_type,
        access_scope_code => $self->access_scope_code,
        staff_note        => $self->staff_note,
        patron_note       => $self->patron_note,
        date_created      => $self->date_created,
        date_modified     => $self->date_modified,
    };
}

1;
