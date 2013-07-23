package Mojolicious::Plugin::Nexmo;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::URL;
use Mojo::JSON;

use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;

our $VERSION = '0.01';

sub register {
    my ($self, $app, $conf) = @_;
    my $base_url = Mojo::URL->new('https://rest.nexmo.com/sms/json');

    # Required params
    for my $param (qw/api_key api_secret/) {
        return $app->log->error("Param '$param' is required for Nexmo") unless $conf->{$param};
        $base_url->query([$param => $conf->{$param}]);
    }

    $app->helper(send_sms => sub {
        my $c = shift;
        my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
        my $args = {@_};
        my $url = $base_url->clone;

        for my $param (qw/from to text/) {
            my $value = $args->{$param} // $conf->{$param};
            unless(defined $value && length $value > 0) {
                return &$cb("Param '$param' is required for Nexmo", undef) if defined $cb;
                die "Param '$param' is required for Nexmo";
            }
            $url->query([$param => $value]);
        }

        # Non blocking
        return $c->ua->get($url => sub {
            my ($ua, $tx) = @_;
            $c->app->log->debug('Nexmo response: ' . Dumper $tx->res->json) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            &$cb(undef, $tx->res->json);
        }) if $cb;
        my $tx = $c->ua->get($url);
        $c->app->log->debug('Nexmo response: ' . Dumper $tx->res->json) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
        return $tx->res->json;
    });

}


1;

__END__

=head1 NAME

Mojolicious::Plugin::Nexmo - Asynchronious send SMS from Nexmo provider.

=head1 SYNOPSIS

    use Mojolicious::Plugin::Nexmo;
    plugin Nexmo => {
        api_key => 'xxx',
        api_secret => 'qqq',
        from => 'test',
        to => 'asdf'
    }
    $c->send_sms(text => 'Message data!');
    $c->send_sms(text => 'Message data!', from => 'new from', to => 'qqqqqq');
    $c->send_sms(text => 'Message data!', to => 'new qqqqqq');

=head1 DESCRIPTION

Stub documentation for Mojolicious::Plugin::Nexmo, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

=head1 OPTIONS

L<Mojolicious::Plugin::Nexmo> supports the following options.

=head2 api_key

=head2 api_secret

=head2 from

=head2 to

    plugin Nexmo => {}

=head1 METHODS



=head1 SEE ALSO

=head1 AUTHOR

Andrey Khozov, E<lt>avkhozov@googlemail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by avkhozov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
