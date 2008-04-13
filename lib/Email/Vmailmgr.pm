=head1 NAME

Email::Vmailmgr - An OO interface for VMailMgr

=cut

package Email::Vmailmgr;

use warnings;
use strict;

use base 'Class::Data::Inheritable';

use Carp;
use Socket;
use IO::Handle;

use Email::Vmailmgr::User;
use Email::Vmailmgr::Domain;

our $VERSION = '0.01000';

=head1 SYNOPSIS

  use Email::Vmailmgr;

  $vmailmgr = Email::Vmailmgr->new();

  # Authenticate a virtual user.
  $vu = $vmailmgr->login_user("domain.tld", "user", $vuser_pw);

  # login_*() doesn't actually contact the vmailmgr daemon. Use check()
  # to verify login credentials before calling any "real" command.
  $r = $vu->check or die "$r\n";

  # mail forwards. set_forwards() overwrites previously set forwards!
  @f = $vu->get_forwards;
  $vu->set_forwards(@f, "mama.doe\@the-does.name");

  $vu->set_password($password);          # set password

  # Change personal information
  $vu->set_personal_information("Mailbox of John Doe");

  # Autoresponder
  print $vu->autoresponse('status')->message;
  $vau->autoresponse('enable');
  $vau->autoresponse('disable');
  print ($r = $vu->autoresponse('read')) ? $r->data : "not found\n";
  $vu->autoresponse(write => $text);
  $vu->autoresponse('delete');


  # Authenticate a real user = super user of all virtual users.
  $vd = $vmailmgr->login_domain("domain.tld", $unix_user_pw);

  $r = $vd->check or die "$r\n";        # validate login data

  # List all users in the domain:
  print $_->user, "\n" for $vd->list->datalist;

  # select a user of the domain
  $vu = $vd->select_user("john.doe");
  # now use methods as described above for a virtual user

  # Create a new user:
  $vd->add_user($username, $userpass, @forwards);

  # Create a forwarding alias (user without mailbox):
  $vd->add_alias($username, $userpass, @forwards);

  # Delete a user:
  $vd->delete_user($username);

=head1 DESCRIPTION

The C<Email::Vmailmgr> package is a bundle of OO classes to interact with
vmailmgrd, a server designed to handle managing email accounts in virtual
domains from a web or remote interface.

VMailMgr is an add-on for the C<qmail> MTA. For more information on
VMailMgr visit the web site C<http://vmailmgr.org/> .

=head2 Caution!

This initial release of the C<Email::Vmailmgr> package is 
B<Alpha Software>. It lacks testing. It also lacks support for C<vmailgrd>
as a TCP service.

=head1 VERSION

This document describes version 0.01000.

=cut

__PACKAGE__->mk_classdata(config_dir => '/etc/vmailmgr');
__PACKAGE__->mk_classdata(socket_file => '/tmp/.vmailmgrd');

=head1 METHODS

=head2 new

  $vmailmgr = Email::Vmailmgr->new(socket_file => $socket);

Object instance constructor. Several named arguments can be given:

=over 4

=item config_dir

To overwrite the default of C</etc/vmailmgr>.

=item socket_file

To overwrite the configuration default value.

=back

Always returns an C<Email::Vmailmgr> object instance. If the
C<socket_file> argument is not given, C<new()> reads the
default value from C<< Email::Vmailmgr->config_dir . '/socket-file' >>,
it dies with an error message, if this read fails.

=cut

sub new {
    my $class = shift;
    my %args = @_ ? %{$_[0]} : ();
    my $t;

    # TODO: support for vmailmgrd on TCP port
    my $self = bless { %args }, $class;
    unless ($args{socket_file}) {
	if (-f ($t = $self->config_dir . '/socket-file')) {
	    open F, $t or croak "Unable to open $t: $!";
	    $t = <F>;
	    chomp $t;
	    close F;
	    $self->socket_file($t);
	}
    }

    $self;
}

=head2 login_user

  $vu = $vmailmgr->login_user($domain, $vuser, $vuser_pw);

Obtain a handle to virtual user access methods of vmailmgr.
Arguments are the email domain name, the virtual user name and the
virtual user password.

Unlike the method name suggests no validation is made on the login
credentials. The method always returns an object instance of the
L<Email::Vmailmgr::User|Email::Vmailmgr::User> class. That object is the
virtual key to talk to the vmailmgr daemon as a virtual user and among
other methods provides the object method
L<check()|Email::Vmailmgr::User/check> for validating the
login credentials by contacting C<vmailmgrd>.

=cut

sub login_user {
    my ($self, $domain, $user, $password) = @_;

    Email::Vmailmgr::User->new({
	vmailmgr => $self, domain => $domain, user => $user, loginpw => $password
    });
}

=head2 login_domain

  $vd = $vmailmgr->login_domain($domain, $user_pw);

Obtain a handle to domain access methods of vmailmgr.
Arguments are the email domain name and the system user password.

Unlike the method name suggests no validation is made on the login
credentials. The method always returns an object instance of the
L<Email::Vmailmgr::Domain|Email::Vmailmgr::Domain> class. That object is
the virtual key to talk to the vmailmgr daemon as a system user
(= domain owner) and among other methods provides the object method
L<check()|Email::Vmailmgr::Domain/check> for validating the login
credentials by contacting C<vmailmgrd>.

=cut

sub login_domain {
    my ($self, $domain, $password) = @_;

    Email::Vmailmgr::Domain->new({
	vmailmgr => $self, domain => $domain, loginpw => $password
    });
}

=head2 query

  $vmailmgr->query($command, @args)

Send a command with arguments to the vmailmgr daemon and and return the
response verbatim.

There is no reason to use this method directly besides debuging.

=cut

sub query {
    my $self = shift;
    my $command = shift;
    my $buffer = pack('n', length($command)) . $command;
    my ($arg, $l);
    my $socket = IO::Handle->new;

    $socket->autoflush(1);

    # get credentials
    foreach (@_) {
	$buffer .= pack('n', length) . $_;
    }
    
    socket($socket, PF_UNIX, SOCK_STREAM, 0);
    connect($socket, sockaddr_un($self->socket_file))
	or croak 'Unable to bind to socket file "', $self->socket_file, '": ', $!;

    $buffer = sprintf "\002%s%c%s", pack('n', length($buffer) + 1), scalar(@_), $buffer;

    send($socket, $buffer, 0) == length($buffer)
	or croak "send() to vmailmgrd failed: $!";

    my $response;
    $response .= $buffer while read($socket, $buffer, 65535);

    croak "Invalid response from vmailmgr" if length($response) < 3;

    $response;
}

1;

__END__

=head1 SEE ALSO

L<Email::Vmailmgr::User|Email::Vmailmgr::User>,
L<Email::Vmailmgr::Domain|Email::Vmailmgr::Domain>,
L<Email::Vmailmgr::Response|Email::Vmailmgr::Response>.

=head1 AUTHOR

Bernhard Graf C<< <perl-email-vmailmgr at movingtarget.de> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-email-vmailmgr at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Email-Vmailmgr>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Bernhard Graf, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
