=head1 NAME

Email::Vmailmgr::Response - Vmailmgr response class

=head1 DESCRIPTION

Except for all C<get_XXX> methods nearly all methods of the
L<Email::Vmailmgr|Email::Vmailmgr> packages return
C<Email::Vmailmgr::Response> object instances.

=cut

package Email::Vmailmgr::Response;

use warnings;
use strict;

use base qw(Class::Accessor::Fast);

use Carp;

=head1 OVERLOADING

For convenience C<Email::Vmailmgr::Response> objects are overloaded for the
following contexts. The examples assume that C<$r> contains an
C<Email::Vmailmgr::Response> object.

=head2 Text Context

  print "$r\n";

Value of L<$r-E<gt>message|/message>.

=head2 Numerical Context

  warn "Error in format or syntax\n" if $r == 1;

Value of L<$r-E<gt>rc|/rc>.

=head2 Boolean Context

  die "Uuh, oh: $r\n" unless $r;

L<$r-E<gt>rc|/rc> == 0.

=cut

use overload
    '""' => sub { shift->message },
    '0+' => sub { shift->rc },
    bool => sub { shift->rc == 0 },
    fallback => 1;



sub _err_read () {
    local $Carp::CarpLevel = 1;
    croak __PACKAGE__, ': read outside of response buffer';
}

=head1 METHODS

=head2 new

Only internally used, so no need to give further details.

=cut

sub new {
    my $class = shift;
    my $type = shift;
    my $self = bless {_buffer => shift, _buffer_pos => 0}, $class;
    my $chunk = $self->_read_next_chunk;

    if ($type eq 'status' or $self->rc) {	# return simple status
	$self->{message} = $chunk;
	return $self;
    }

    if ($type eq 'data') {
	$self->{data} = $chunk;
	$self->{message} = $self->_read_next_chunk;
	return $self;
    }

    croak __PACKAGE__, qq{::new: invalid type "$type"};
}

=head2 rc

  $result_code = $r->rc;

Get vmailmgr return code. C<0> means "OK - operation succeeded", C<1> means
"Bad - error in format or syntax" and C<2> means "Error - operation failed".

=head2 message

  print $r->message, "\n";

In most cases the mailmgr daemon returns a printable message in its
response that can be accessed using the C<message> accessor. The are
two cases where C<message> is not defined:

=over 3

=item *

A successful call of L<list()|Email::Vmailmgr::Domain/list> of the
L<Email::Vmailmgr::Domain|Email::Vmailmgr::Domain> class.

=item *

A successful call of L<check()|Email::Vmailmgr::User/check> of the
L<Email::Vmailmgr::User|Email::Vmailmgr::User> class or
L<check()|Email::Vmailmgr::Domain/check> of the
L<Email::Vmailmgr::Domain|Email::Vmailmgr::Domain> class.

=back

=head2 data

To hold arbitrary response data besides the normal response message.

=cut

__PACKAGE__->mk_ro_accessors(qw(
    rc
    message
    data
));

=head2 datalist

Same as L<data()|/data>, but returns contents of data as an array if
L<data()|/data> would return it as an array reference.

=cut

sub datalist {
    my $data = shift->data;

    ref($data) eq 'ARRAY' ? @$data : $data;
}


#== private ============================================================

sub _read_next_chunk {
    my $self = shift;
    my $buffer = $self->{_buffer};
    my $pos = $self->{_buffer_pos};
    my $bl = length $buffer;

    _err_read if $bl < $pos + 3;

    my $rc = ord(substr($buffer, $pos, 1));

    # first byte holds result code if this is the first chunk in the buffer
    $self->{rc} = $rc if $pos == 0;

    my $l = unpack('n', substr($buffer, $pos + 1, 2));

    _err_read if $bl < ($self->{_buffer_pos} = $pos + 3 + $l);

    $l ? substr ($buffer, $pos + 3, $l) : undef;
}

1;

__END__

=head1 SEE ALSO

L<Email::Vmailmgr|Email::Vmailmgr>,
L<Email::Vmailmgr::User|Email::Vmailmgr::User>,
L<Email::Vmailmgr::Domain|Email::Vmailmgr::Domain>.

=head1 AUTHOR

Bernhard Graf C<< <perl-email-vmailmgr at movingtarget.de> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Bernhard Graf, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
