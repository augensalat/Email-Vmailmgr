=head1 NAME

Email::Vmailmgr::Domain - VMailMgr domain methods

=head1 DESCRIPTION

The C<Email::Vmailmgr::Domain> class provides facilities for managing
domain data.

An C<Email::Vmailmgr::Domain> object is created by the
L<login_domain() method|Email::Vmailmgr/login_domain> of the
L<Email::Vmailmgr|Email::Vmailmgr> the class.

=head2 Security notice

When using L<Email::Vmailmgr|Email::Vmailmgr> in a persistant web
application like mod_perl or FastCGI, make sure B<not to keep> the
L<Email::Vmailmgr::Domain object instance|Email::Vmailmgr::Domain>
between server calls! Only the L<Email::Vmailmgr|Email::Vmailmgr> object
is allowed to and should be persistant.

=cut

package Email::Vmailmgr::Domain;

use warnings;
use strict;

use base 'Class::Accessor::Fast';

use Email::Vmailmgr::Response;

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_ro_accessors(qw(
    vmailmgr
    domain
    loginpw
));

=head1 METHODS

=head2 new

Never use this method. Use L<login_domain()|Email::Vmailmgr/login_domain>
of the L<Email::Vmailmgr|Email::Vmailmgr> class to create a
C<Email::Vmailmgr::Domain> object instance:

  $vd = $vmailmgr->login_domain($domain, $password)

=head2 check

  $check = $vd->check;

Check login credentials by contacting the server. The result is a
L<Email::Vmailmgr::Response|Email::Vmailmgr::Response> object instance.
C<< $check->message >> is undefined for successful checks.

=cut

sub check {
    my $self = shift;
    Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(check => $self->{domain}, '', $self->{loginpw})
    );
}

=head2 list

  @list = $vd->list->datalist;

Get a list of the domain's virtual users. Returns an object instance of
the L<Email::Vmailmgr::Response|Email::Vmailmgr::Response> class where
the user list is available as an array reference through the
L<data|Email::Vmailmgr::Response/data> accessor or as an array through
the L<datalist|Email::Vmailmgr::Response/datalist> accessor.

The L<message accessor|Email::Vmailmgr::Response/message> of the
L<response object|Email::Vmailmgr::Response> returns C<undef> if
operation was successful.

=cut

sub list {
    my $self = shift;

    my $r = Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(listdomain => $self->{domain}, $self->{loginpw})
    );
    return $r unless $r;    # error

    # If query was successful the first chunk is empty, then an arbitrary
    # number of chunks of user records follow until an empty chunk is read.
    my (@data, $user, $chunk);
    my $time = time;
    while ($chunk = $r->_read_next_chunk) {
	$user = Email::Vmailmgr::User->new({
	    vmailmgr    => $self->{vmailmgr},
	    domain      => $self->{domain},
	    loginpw     => $self->{loginpw},
	    is_super    => 1,
	    lookup_time => $time,
	});
	$user->_process_user_record($chunk, 1);
	push @data, $user;
    }
    $r->{data} = \@data;
    return $r;
}

=head2 select_user

  $vu = $vd->select_user($user);

Create an object instance of the
L<Email::Vmailmgr::User|Email::Vmailmgr::User> class for the given
virtual C<$user> of this domain. However the fact, that this object is
created by the super user is preserved in this object to grant certain
actions like setting quotas and message limits.

=cut

sub select_user {
    my $self = shift;

    Email::Vmailmgr::User->new({
	vmailmgr => $self->{vmailmgr},
	domain => $self->{domain},
	user => shift,
	loginpw => $self->{loginpw},
	is_super => 1,
    });
}

=head2 add_user

  $r = $vd->add_user($username, $password, @forwards)

Create a new user in the domain.

The result is a L<Email::Vmailmgr::Response|Email::Vmailmgr::Response>
object instance.

=cut

sub add_user {
    my $self = shift;
    my $user = shift;
    my $password = shift;

    Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(
	    adduser2 => $self->{domain}, $user, $self->{loginpw}, $password, $user, @_
	)
    );
}

=head2 add_alias

  $r = $vd->add_alias($username, $password, @forwards)

Create a new user alias = user without a mailbox.

The result is a L<Email::Vmailmgr::Response|Email::Vmailmgr::Response>
object instance.

=cut

sub add_alias {
    my $self = shift;
    my $user = shift;
    my $pass = shift;

    Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(
	    adduser2 => $self->{domain}, $user, $self->{loginpw}, $pass, '', @_
	)
    );
}

=head2 delete_user

  $r = $vd->delete_user($username)

Delete a user (including alias users).

The result is a
L<Email::Vmailmgr::Response::Status|Email::Vmailmgr::Response::Status>
object instance.

=cut

sub delete_user {
    my $self = shift;
    my $user = shift;

    Email::Vmailmgr::Response->new(
	status =>
	$self->{vmailmgr}->query(deluser => $self->{domain}, $user, $self->{loginpw})
    );
}

1;

__END__

=head1 SEE ALSO

L<Email::Vmailmgr|Email::Vmailmgr>,
L<Email::Vmailmgr::User|Email::Vmailmgr::User>,
L<Email::Vmailmgr::Response|Email::Vmailmgr::Response>.

=head1 AUTHOR

Bernhard Graf C<< <perl-email-vmailmgr at movingtarget.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Bernhard Graf, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
