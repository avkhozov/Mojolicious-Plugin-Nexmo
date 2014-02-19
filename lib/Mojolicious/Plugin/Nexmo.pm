package Mojolicious::Plugin::Nexmo;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::URL;
use Mojo::JSON;

use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;

our $VERSION = '0.02.01';

sub register {
    my ($self, $app, $conf) = @_;

    my $base_url_sms = Mojo::URL->new('https://rest.nexmo.com/sms/json');
    my $base_url_tts = Mojo::URL->new('https://rest.nexmo.com/tts/json');

    # Required params
    for my $param (qw/api_key api_secret/) {
        return $app->log->error("Param '$param' is required for Nexmo") unless $conf->{$param};
        $base_url_sms->query([$param => $conf->{$param}]);
        $base_url_tts->query([$param => $conf->{$param}]);
    }

    # SMS
    $app->helper(send_sms => sub {
        my $c = shift;
        my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
        my $args = {@_};
        my $url = $base_url_sms->clone;

        for my $param (qw/from to text/) {
            my $value = $args->{$param} // $conf->{$param};
            unless(defined $value && length $value > 0) {
                return $c->$cb("Param '$param' is required for Nexmo SMS", undef) if defined $cb;
                die "Param '$param' is required for Nexmo SMS";
            }
            $url->query([$param => $value]);
        }

        # Non blocking
        return $c->ua->get($url => sub {
            my ($ua, $tx) = @_;
            $c->app->log->debug('Nexmo SMS response: ' . Dumper $tx->res->json) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            $c->$cb(undef, $tx->res->json);
        }) if $cb;

        # Blocking
        my $tx = $c->ua->get($url);
        $c->app->log->debug('Nexmo SMS response: ' . Dumper $tx->res->json) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
        return $tx->res->json;
    });

    # TTS - Text To Speech
    $app->helper(send_tts => sub {
        my $c = shift;
        my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
        my $args = {@_};
        my $url = $base_url_tts->clone;

        for my $param (qw/to text/) {
            my $value = $args->{$param} // $conf->{$param};
            unless (defined $value && length $value > 0) {
                return $c->$cb("Param '$param' is required for Nexmo TTS", undef) if defined $cb;
                die "Param '$param' is required for Nexmo TTS";
            }
            $url->query([$param => $value]);
        }
        my $value = $args->{'lg'} // $conf->{'lg'};
        $url->query(['lg' => $value]) if (defined $value && length $value > 0);

        # Non blocking
        return $c->ua->get($url => sub {
            my ($ua, $tx) = @_;
            $c->app->log->debug('Nexmo TTS response: ' . Dumper $tx->res->json) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            $c->$cb(undef, $tx->res->json);
        }) if $cb;

        # Blocking
        my $tx = $c->ua->get($url);
        $c->app->log->debug('Nexmo TTS response: ' . Dumper $tx->res->json) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
        return $tx->res->json;
    });

}


1;

__END__

=head1 NAME

Mojolicious::Plugin::Nexmo - Asynchronous (and Synchronous) SMS and TTS (Text To Speech) sending from Nexmo provider

=head1 SYNOPSIS

    use Mojolicious::Plugin::Nexmo;

    plugin Nexmo => {
        api_key => 'n3xm0rocks',
        api_secret => '12ab34cd',
        from => 'test',
        to => '44123456789'
        lg => 'ru-ru' # Language for TTS messages
    }

    $c->send_sms(text => 'Message data!');

    $c->send_sms(
    	text => 'Message data!',
    	from => 'CompanyName',
    	to => '44987654321'
    );

    $c->send_sms(
    	text => 'Message data!',
    	to => '44987654321'
    );

=head1 DESCRIPTION

Stub documentation for Mojolicious::Plugin::Nexmo, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited. // TODO

=head1 OPTIONS

L<Mojolicious::Plugin::Nexmo> supports the following options.

=head2 api_key

Your Nexmo API key

=head2 api_secret

Your Nexmo API secret

=head2 from

=head2 to

=head2 lg

=head1 METHODS

=head1 SEE ALSO

L<Mojolicious::Plugin::SMS>
L<Nexmo::SMS>
L<SMS::Send::Nexmo>

=head1 AUTHOR

Andrey Khozov, E<lt>avkhozov@googlemail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by avkhozov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
