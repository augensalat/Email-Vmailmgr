=head1 NAME

Email::Vmailmgr::User - Vmailmgr virtual user methods

=head1 DESCRIPTION

The C<Email::Vmailmgr::User> class provides facilities for managing
virtual user data.

An C<Email::Vmailmgr::User> object is created by the
L<login_user() method|Email::Vmailmgr/login_user> of the
L<Email::Vmailmgr|Email::Vmailmgr> class.

=head2 Security notice

When using L<Email::Vmailmgr|Email::Vmailmgr> in a persistant web
application like mod_perl or FastCGI, make sure B<not to keep> the
L<Email::Vmailmgr::User object instance|Email::Vmailmgr::User> between
server calls! Only the L<Email::Vmailmgr|Email::Vmailmgr> object is
allowed to and should be persistant.

=cut

package Email::Vmailmgr::User;

use warnings;
use strict;

use base 'Class::Accessor';

use Carp;

use Email::Vmailmgr::Response;

use constant DOMAIN_ATTRIBUTES => {
    hard_quota => 3,
    soft_quota => 4,
    message_size_limit => 5,
    message_count_limit => 6,
    expiry_time => 7,
    mailbox_enabled => 8,
    personal_information => 9,
};

use constant USER_ATTRIBUTES => {
    mailbox_enabled => 8,
    personal_information => 9,
};

# the values that set VMailMgr attributes to "not defined"
use constant ATTR_UNDEF => [
    '',
    '',
    '',
    '-',
    '-',
    '-',
    '-',
    '-',
    '0',
    '',
];

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_ro_accessors(qw(
    vmailmgr
    domain
    user
    loginpw
    password_crypt
    lookup_time
    is_super
    creation_time
    mailbox
));

__PACKAGE__->mk_accessors(qw(
    personal_information
    hard_quota
    soft_quota
    message_size_limit
    message_count_limit
    expiry_time
    mailbox_enabled
));

sub _err_read () {
    local $Carp::CarpLevel = 1;
    croak __PACKAGE__, ": read outside of response buffer";
}

=head1 METHODS

Unless otherwise noted, all methods return an instance object of the
the L<Email::Vmailmgr::Response|Email::Vmailmgr::Response> class
where L<rc()|Email::Vmailmgr::Response/rc> and
L<message()|Email::Vmailmgr::Response/message> are set with a defined
value.

All methods starting with C<get_> never return objects, but either a
scalar, a list or undef. C<get_> methods die if they fail to retrieve
the requested data.

=head2 new

Never use this method. Use L<login_user()|Email::Vmailmgr/login_user>
of the L<Email::Vmailmgr|Email::Vmailmgr> class to create an
C<Email::Vmailmgr::User> object instance:

  $vu = $vmailmgr->login_user($domain, $user, $password)

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(shift);

    $self->{valid_attributes} =
	$self->{is_super} ? DOMAIN_ATTRIBUTES : USER_ATTRIBUTES;
    $self;
}

=head2 check

  $check = $vu->check;

Check login credentials by contacting the server. The result is an
L<Email::Vmailmgr::Response|Email::Vmailmgr::Response> object instance.
C<< $check->message >> is undefined for successful checks.

=cut

sub check {
    my $self = shift;
    Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(check => @$self{qw(domain user loginpw)})
    );
}

=head2 lookup

  $success = $vu->lookup;

Lookup user data of the authenticated virtual user.

This method is called in the first invocation of any C<get_XXX()> method
in this class, so it is not required to call C<lookup()> explicitely.
However calling lookup() might be useful, because all the C<get_XXX()>
methods C<die> if the implicit C<lookup()> call returns failure -
C<lookup()> on the other hand returns a status object in either case.

=cut

sub lookup {
    my $self = shift;
    my $r = Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(lookup => @$self{qw(domain user loginpw)})
    );
    $self->{lookup_time} = time;

    # Email::Vmailmgr::Response stores the first chunk from vmailmgrd's
    # answer into the message accessor. If the result indicates failure,
    # we return with the Email::Vmailmgr::Response here.
    return $r unless $r;

    # On success message contains the user data, so we fetch it from there and
    # then read the next chunk from vmailgrd, that actually contains the
    # success message.
    $self->_process_user_record($r->{message});
    $r->{message} = $r->_read_next_chunk;
    $r;
}

=head2 get_vmailmgr

  $vmailmgr = $vu->get_vmailmgr;

Get the vmailmgr object.

=head2 get_domain

  $domain = $vu->get_domain;

Get the domain name of the virtual user.

=head2 get_user

  $user = $vu->get_user;

Get the local part of virtual username.

=head2 get_loginpw

  $password = $vu->get_loginpw;

Get the password that was used for authentication - either for the
domain user or the virtual user.

=head2 set_password

  $success = $vu->set_password($newpass);

Set virtual user's password.

=cut

sub set_password {
    my $self = shift;
    my $pass = shift;
    push @_, '' unless @_;
    my $r = Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(chattr => @$self{qw(domain user loginpw)}, 1 => shift)
    )
	and not $self->{is_super} and $self->{loginpw} = $pass;

    $r;
}

=head2 get_forwards

  @addresses = $vu->get_forwards;

Get the virtual user's forwarding address(es).

Returns a list of forwarding email addresses.

=cut

sub get_forwards { @{shift->get('forwards')} }

=head2 set_forwards

  $success = $vu->set_forwards(@recipients);

Set virtual user's  forwarding address(es). The argument list replaces
any existing forwarding addresses.

=cut

sub set_forwards {
    my $self = shift;

    push @_, '' unless @_;
    Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(chattr => @$self{qw(domain user loginpw)}, 2 => @_)
    );
}

=head2 get_mailbox

  $path = $vu->get_mailbox;

Get path to virtual user's mailbox (Maildir) relative to the system
user's home directory.

=head2 get_creation_time

  $expire = $vu->get_creation_time;

Get the virtual user's creation time as a UNIX time (seconds since
1970-1-1) or C<0> if unknown.

=head2 get_hard_quota

  $bytes = $vu->get_hard_quota;

Get the virtual user's total size hard quota in bytes, or C<undef> if
not applicable.

=head2 set_hard_quota

  $success = $vu->set_hard_quota($bytes);

Set the virtual user's total size hard quota in bytes, or C<undef>
for unlimited.

This method is only available for the super user.

=head2 get_soft_quota

  $bytes = $vu->get_soft_quota;

Get the virtual user's total size soft quota in bytes, or C<undef> if
not applicable.

=head2 set_soft_quota

  $success = $vu->set_soft_quota($bytes);

Set the virtual user's total size soft quota in bytes, or C<undef>
for unlimited.

This method is only available for the super user.

=head2 get_message_size_limit

  $bytes = $vu->get_message_size_limit;

Get the virtual user's message size limit in bytes, or C<undef> if
not applicable.

=head2 set_message_size_limit

  $success = $vu->set_message_size_limit($bytes);

Set the virtual user's message size limit in bytes, or C<undef>
for unlimited.

This method is only available for the super user.

=head2 get_message_count_limit

  $n = $vu->get_message_count_limit;

Get the virtual user's message count limit, or C<undef> if not
applicable.

=head2 set_message_count_limit

Set the virtual user's message count limit, or C<undef> for unlimited.

This method is only available for the super user.

=head2 get_expiry_time

  $expire = $vu->get_expiry_time;

Get user expiry time as a UNIX time (seconds since 1970-1-1).
Returns C<undef> if no such time is set.

=head2 set_expiry_time

  $success = $vu->set_expiry_time(time + 365*24*60*60);

Set user's expiry time as a UNIX time (seconds since 1970-1-1).

This method is only available for the super user.

=head2 get_personal_information

   $info = $vu->get_personal_information;

Get whatever is stored in under the virtual user's personal information.
Returns C<undef> when there is no personal information.

=head2 set_personal_information

  $success = $vu->set_personal_information("dumb user");

Set virtual user's personal information. An empty or C<undef>ined
argument clears the personal information.

=head2 get_mailbox_enabled

  print $vu->get_mailbox_enabled ? "enabled" : "disabled";

Check if virtual user's mailbox is enabled.

=head2 set_mailbox_enabled

  $success = $vu->set_mailbox_enabled(1);
  $success = $vu->set_mailbox_enabled(0);

Enable or disable the virtual user's mailbox;

=head2 has_mailbox

  print $vu->get_mailbox if $vu->has_mailbox;

Check if the virtual user has a mailbox.

=cut

sub has_mailbox { shift->{has_mailbox} }

=head2 autoresponse

  $status = $vu->autoresponse('status');
  $vu->autoresponse('enable');
  $vu->autoresponse('disable');
  $text = $vu->autoresponse('read');
  $vu->autoresponse(write => $text);
  $vu->autoresponse('delete');

Operations for autoresponders.

The first argument is the autoresponse command and can be one of:

=over 4

=item status

Returns an object instance of the
L<Email::Vmailmgr::Response|Email::Vmailmgr::Response> class where the
result of the autoresponder is contained in the
L<message|Email::Vmailmgr::Response/message> accessor and is one of
"enabled", "disabled", "missing message file" and "nonexistant".

=item enable

Enable autoresponder.

=item disable

Disable autoresponder.

=item read

Read the autoresponder email message text. Return an object instance of
the L<Email::Vmailmgr::Response|Email::Vmailmgr::Response> class where
the autoresponse text is available as a raw RFC-2822 compliant email
through the L<data|Email::Vmailmgr::Response/data> accessor.

=item write

Set the autoresponder email message. Must be an RFC-2822 compliant email,
no further modifying is done with it.

=item delete

Delete autoresponder message.

=back

=cut

sub autoresponse {
    my $self = shift;
    my $cmd = shift;

    if ($cmd eq 'status' or $cmd eq 'enable' or $cmd eq 'disable' or $cmd eq 'delete') {
	Email::Vmailmgr::Response->new(
	    status =>
	    $self->{vmailmgr}->query(autoresponse => @$self{qw(domain user loginpw)}, $cmd)
	);
    }
    elsif ($cmd eq 'read') {
	Email::Vmailmgr::Response->new(
	    data =>
	    $self->{vmailmgr}->query(autoresponse => @$self{qw(domain user loginpw)}, $cmd)
	);
    }
    elsif ($cmd eq 'write') {
	Email::Vmailmgr::Response->new(
	    status =>
	    $self->{vmailmgr}->query(autoresponse => @$self{qw(domain user loginpw)}, $cmd => shift)
	);
    }
    else {
	croak __PACKAGE__, qq{::autoresponse: invalid command "$cmd"}
    }
}

=head2 get

  $value = $vu->get($key);

Generic user attribute get method.

Except for the L<get_forwards() method|/get_forwards> C<< $vu->get_XXX >>
is virtually equal to C<< $vu->get("XXX") >>.

On the first invocation L</lookup> is called and if that fails the
method dies with the error message from the vmailgr daemon.

=cut

sub get {
    my $self = shift;

    unless (defined $self->{lookup_time}) {
	my $r = $self->lookup;
	croak $r->message unless $r;
    }
    $self->SUPER::get(@_);
}

=head2 set

  $vu->get($key => $value);

Generic user attribute set method.

Except for the L<set_password() method|/set_password> and the
L<set_forwards() method|/get_forwards> C<< $vu->set_XXX($value) >>
is virtually equal to C<< $vu->set(XXX => $value) >>.

=cut

sub set {
    my $self = shift;
    my ($k, $v) = @_;
    my $id = $self->{valid_attributes}->{$k}
	or croak __PACKAGE__, qq{: can not set_$k(...)};

    my $r = Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(chattr => @$self{qw(domain user loginpw)}, _vmtr($id => $v))
    );
    $self->SUPER::set(@_) if $r;
    $r;
}

#== private ============================================================

# Translate an undefined attribute value into that what vmailmgr takes as
# "undef" for this particular attribute. Return a key-value-pair.
sub _vmtr {
    my ($k, $v) = @_;

    ($k, defined($v) ? $v : ATTR_UNDEF->[$k]);
}

sub _process_user_record {
    my ($self, $buffer, $fetch_user) = @_;

    my $bl = length $buffer;
    my ($p, $k, $t);
    my (@token, @forwards);

    # user name
    if ($fetch_user) {	# fetch username from buffer
	($p = index($buffer, "\0")) > 0
	    or _err_read;
	$self->{user} = substr($buffer, 0, $p);
	++$p;
    }
    else {		# don't fetch username from buffer
	$p = 0;		    
    }
    _err_read if $p >= $bl;
    croak __PACKAGE__, ": unsupported record version $t"
	if ($t = ord(substr($buffer, $p++, 1))) != 2;
    # flags
    while ($k = ord(substr($buffer, $p++, 1))) {
	$t = ord(substr($buffer, $p++, 1));
	if ($k == 8) {
	    $self->{mailbox_enabled} = $t == 1;
	}
	elsif ($k == 10) {
	    $self->{has_mailbox} = $t == 1;
	}
	_err_read if $p >= $bl;
    }

    # the rest can be splitted at the \0 boundaries
    @token = split "\0", substr($buffer, $p);
    $self->{password_crypt} = length($t = shift @token) ? $t : undef;
    $self->{mailbox} = length($t = shift @token) ? $t : undef;
    push @forwards, $t while length($t = shift @token);
    $self->{forwards} = \@forwards;
    $self->{personal_information} = $t if length($t = shift @token);
    @$self{qw(
	hard_quota soft_quota
	message_size_limit message_count_limit
	creation_time expiry_time
    )} =
	map { length and $_ ne '-' ? $_ : undef } @token;
}

1;

__END__

=head1 SEE ALSO

L<Email::Vmailmgr|Email::Vmailmgr>,
L<Email::Vmailmgr::Response|Email::Vmailmgr::Response>.

=head1 AUTHOR

Bernhard Graf C<< <perl-email-vmailmgr at movingtarget.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Bernhard Graf, all rights reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
