package Mojolicious::Plugin::Nexmo;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::URL;
use Mojo::JSON;

use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;

our $VERSION = '0.02';

sub register {

    my ($self, $app, $conf) = @_;

    my $base_url = Mojo::URL->new('https://rest.nexmo.com');
    my @sms_params = qw ( from to type text status-report-req client-ref network-code vcard vcal ttl message-class body udh );
    my @tts_params = qw ( to from text lg voice repeat drop_if_machine callback callback_method );

    # Required params
    for my $param (qw/api_key api_secret/) {
        return $app->log->error("Param '$param' is required for Nexmo") unless $conf->{$param};
        $base_url->query([$param => $conf->{$param}]);
    }

    # nexmo helper
    $app->helper(nexmo => sub {

        my $c = shift;
        my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
        my $args = {@_};
        my $url = $base_url->clone;
        my $params;

        # Mode (SMS / TTS)
        my $mode = lc ($args->{'mode'} // $conf->{'mode'});
        if ($mode eq 'sms') {
            $url->path('/sms/json');
            $params = \ @sms_params;
        } elsif ($mode eq 'tts') {
            $params = \ @tts_params;
            $url->path('/tts/json');
        } else {
            $c->app->log->debug( "No such mode: '${mode}'. Use 'tts' or 'sms'" ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            return $c->$cb( -1, "No such mode: '${mode}'. Use 'tts' or 'sms'", undef ) if defined $cb;
            return ( -1, "No such mode: '${mode}'. Use 'tts' or 'sms'", undef );
        }

        # Params for request
        for my $param (@$params) {
            my $value = $args->{$param} // $conf->{$param};
            $url->query([$param => $value]);
        }

        # Non blocking
        return $c->ua->get($url => sub {
            my ($ua, $tx) = @_;
            if ( my $res = $tx->success ) {
                # if ( (my $code = $tx->res->code) != 200 ) {
                #     $c->app->log->debug( "Nexmo \U${mode}\E response strange: CODE[${code}]" ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
                #     return $c->$cb( $code, 'Something strange', undef );
                # }
                $c->app->log->debug( "Nexmo \U${mode}\E response: " . Dumper $res->json ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
                if ($mode eq 'tts') {
                    $c->$cb( $res->json('/status'), $res->json('/error-text'), $res->json );
                } elsif ($mode eq 'sms') {
                    # SMS can be divided into several parts
                    my $count = $res->json('/message-count') - 1;
                    for my $i (0..$count) {
                        return $c->$cb( $res->json("/messages/$i/status"), $res->json("/messages/$i/error-text"), $res->json ) if $res->json("/messages/$i/status") != 0;
                    }
                    $c->$cb( 0, undef, $res->json );
                }
            } else {
                my ($error, $code) = $tx->error;
                $c->app->log->debug( "Nexmo \U${mode}\E request failed: CODE[${code}] ERROR[${error}]" ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
                $c->$cb( $code, $error, undef );
            }
        }) if $cb;

        # Blocking
        my $tx = $c->ua->get($url);
        if ( my $res = $tx->success ) {
            # if ( (my $code = $res->code) != 200 ) {
            #     $c->app->log->debug( "Nexmo \U${mode}\E response strange: CODE[${code}]" ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            #     return ( $code, 'Something strange', undef );
            # }
            $c->app->log->debug( "Nexmo \U${mode}\E response: " . Dumper $res->json ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            if ($mode eq 'tts') {
                return ( $res->json('/status'), $res->json('/error-text'), $res->json );
            } elsif ($mode eq 'sms') {
                # SMS can be divided into several parts
                my $count = $res->json('/message-count') - 1;
                for my $i (0..$count) {
                    return ( $res->json("/messages/$i/status"), $res->json("/messages/$i/error-text"), $res->json ) if $res->json("/messages/$i/status") != 0;
                }
                return ( 0, undef, $res->json );
            }
        } else {
            my ($error, $code) = $tx->error;
            $c->app->log->debug( "Nexmo \U${mode}\E request failed: CODE[${code}] ERROR[${error}]" ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            return ( $code, $error, undef );
        }

    });

}

1;

__END__

=head1 NAME

Mojolicious::Plugin::Nexmo - Asynchronous (and Synchronous) SMS and TTS (Text To Speech) sending from Nexmo provider

=head1 SYNOPSIS

    use Mojolicious::Lite;

    plugin Nexmo => {
        api_key => 'n3xm0rocks',
        api_secret => '12ab34cd',
        from => 'YourCompanyName', # Required parameter for SMS sending
        lg => 'de-de' # Language for TTS messages
    }
    
    # /block ? phone_number=447525856424 & message=Guten Tag
    get '/block' => sub {
    
    }

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
