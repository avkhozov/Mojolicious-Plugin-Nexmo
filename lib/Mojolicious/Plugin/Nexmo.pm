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

    my $base_url = Mojo::URL->new('https://rest.nexmo.com');

    # Required params
    for my $param (qw( api_key api_secret )) {
        die "Nexmo: param '$param' is required." unless $conf->{$param};
        $base_url->query->param($param => $conf->{$param});
    }

    # nexmo helper
    $app->helper(nexmo => sub {

        my $c = shift;
        my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
        my $args = {@_};
        my $url = $base_url->clone;

        # Mode (SMS / TTS)
        my $mode = lc ($args->{'mode'} || $conf->{'mode'} || '');
        if ($mode eq 'sms') {
            $url->path('/sms/json');
        } elsif ($mode eq 'tts') {
            $url->path('/tts/json');
        } else {
            die "Nexmo: no such mode ('${mode}'). Use 'TTS' or 'SMS'.";
        }

        # Params for request
        for my $param (keys %$args) {
            next if $param eq 'mode';
            my $value = $args->{$param};
            $url->query->param($param => $value) if defined $value;
        }
        for my $param (keys %$conf) {
            next if ( $param eq 'mode' || $param eq 'api_key' || $param eq 'api_secret' );
            next if exists $args->{$param}; # ability to disable global parameters
            my $value = $conf->{$param};
            $url->query->param($param => $value) if defined $value;
        }
        # Log HTTP request
        $c->app->log->debug( "Nexmo \U${mode}\E request:  " . $url ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};

        # Non blocking
        return $c->ua->get($url => sub {
            my ($ua, $tx) = @_;
            if ( my $res = $tx->success ) {
                # response code != 200
                if ( (my $code = $tx->res->code) != 200 ) {
                    $code ||= '';
                    $c->app->log->debug( "Nexmo \U${mode}\E request failed. Something strange: CODE[${code}]." )
                        if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
                    return $c->$cb( -1, "Something strange: CODE[${code}]" , {} );
                }
                #
                $c->app->log->debug( "Nexmo \U${mode}\E response: " . Dumper $res->json ) if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
                if ($mode eq 'tts') {
                    $c->$cb( $res->json('/status'), $res->json('/error-text'), $res->json );
                } elsif ($mode eq 'sms') {
                    # SMS can be divided into several parts
                    my $count = $res->json('/message-count') - 1;
                    for my $i (0..$count) {
                        return $c->$cb( $res->json("/messages/$i/status"), $res->json("/messages/$i/error-text"), $res->json )
                            if $res->json("/messages/$i/status") != 0;
                    }
                    #
                    $c->$cb( 0, "Success", $res->json );
                }
            } else {
                # network error
                my ($error, $code) = $tx->error;
                $error ||= '';
                $code ||= '';
                $c->app->log->debug( "Nexmo \U${mode}\E request failed. Network error: CODE[$code] MESSAGE[$error]." )
                    if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
                $c->$cb( -1, "Network error: CODE[$code] MESSAGE[$error]", {} );
                #
            }
        }) if $cb;

        # Blocking
        my $tx = $c->ua->get($url);
        if ( my $res = $tx->success ) {
            # response code != 200
            if ( (my $code = $res->code) != 200 ) {
                $code ||= '';
                $c->app->log->debug( "Nexmo \U${mode}\E request failed. Something strange: CODE[${code}]." )
                    if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
                return( -1, "Something strange: CODE[${code}]" , {} );
            }
            #
            $c->app->log->debug( "Nexmo \U${mode}\E response: " . Dumper $res->json )
                if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            if ($mode eq 'tts') {
                return( $res->json('/status'), $res->json('/error-text'), $res->json );
            } elsif ($mode eq 'sms') {
                # SMS can be divided into several parts
                my $count = $res->json('/message-count') - 1;
                for my $i (0..$count) {
                    return ( $res->json("/messages/$i/status"), $res->json("/messages/$i/error-text"), $res->json )
                        if $res->json("/messages/$i/status") != 0;
                }
                #
                return( 0, "Success", $res->json );
            }
        } else {
            # network error
            my ($error, $code) = $tx->error;
            $error ||= '';
            $code ||= '';
            $c->app->log->debug( "Nexmo \U${mode}\E request failed. Network error: CODE[$code] MESSAGE[$error]." )
                if $ENV{'MOJOLICIOUS_NEXMO_DEBUG'};
            return( -1, "Network error: CODE[$code] MESSAGE[$error]", {} );
            #
        }

    });

}

1;

__END__

=head1 NAME

Mojolicious::Plugin::Nexmo - Asynchronous (and synchronous) SMS and TTS (Text To Speech) sending
with L<Nexmo|https://www.nexmo.com/> provider.

=head1 VERSION

1.00

=head1 SYNOPSIS

    plugin 'Nexmo' => {
        api_key    => 'n3xm0rocks',
        api_secret => '12ab34cd',
        from       => 'YourCompanyName',   # This options are global, you don't need
        lg         => 'de-de'              # to declare them in every request
    };

=head2 Simple blocking example

    use Mojolicious::Lite

    plugin 'Nexmo' => {
        api_key    => 'n3xm0rocks',
        api_secret => '12ab34cd'
    };

    # /block ? mode=SMS & phone_number=447525856424 & message=Hello!
    get '/block' => sub {
        my $self = shift;
    
        my $mod = $self->param('mode');
        my $tel = $self->param('phone_number');
        my $mes = $self->param('message');
        
        $self->render(text => "$tel : $mes");
        
        my ($err, $err_mes, $info) = $self->nexmo(
            mode => $mod,
            to   => $tel,
            text => $mes
        );
    };

    app->start;

=head2 Nonblocking example

    use Mojolicious::Lite;

    plugin 'Nexmo' => {
        api_key    => 'n3xm0rocks',
        api_secret => '12ab34cd'
    };

    # /nonblock ? mode=SMS & phone_number=447525856424 & message=Hello!
    get '/nonblock' => sub {
        my $self = shift;
        
        my $mod = $self->param('mode');
        my $tel = $self->param('phone_number');
        my $mes = $self->param('message');
        
        $self->render(text => "$tel : $mes");
        
        $self->nexmo(
            mode => $mod,
            to   => $tel,
            text => $mes,
            sub {
                my ($self, $err, $err_mes, $info) = @_;
                # ...
            }
        );
    };

    app->start;

=head2 Nice example with L<Mojo::IOLoop>

    use Mojolicious::Lite;
    use Mojo::IOLoo;

    plugin 'Nexmo' => {
        api_key    => 'n3xm0rocks',
        api_secret => '12ab34cd'
    };

    # /delay ? mode=SMS & phone_number=447525856424 & message=Hello!
    get '/delay' => sub {
        my $self = shift;
        
        my $mod = $self->param('mode');
        my $tel = $self->param('phone_number');
        my $mes = $self->param('message');
        
        Mojo::IOLoop->delay(
            sub {
                my $delay = shift;
                $self->nexmo(
                    mode => $mod,
                    to   => $tel,
                    text => $mes,
                    $delay->begin # CallBack
                );
                return $self->render(text => "$tel : $mes");
            },
            sub {
                my ($delay, $err, $err_mes, $info) = @_;
                # ...
            }
        );
    };

    app->start;

=head1 DESCRIPTION

This plugin provides an easy way to send SMS and TTS with Nexmo API.

=head1 OPTIONS

You can redefine global options:

    plugin 'Nexmo' => {
        api_key    => 'n3xm0rocks',
        api_secret => '12ab34cd',
        from       => 'YourCompanyName'  # Global option
    };

    # ...
        
        $self->nexmo(
            mode => $mod,
            to   => $tel,
            text => $mes,
            from => 'NewCompanyName'  # 'NewCompanyName' will be used in this response
        );

    # ...

Or you can disable global options by setting them in C<undef>:

    plugin 'Nexmo' => {
        api_key    => 'n3xm0rocks',
        api_secret => '12ab34cd',
        lg         => 'de-de'  # Global option
    };

    # ...
        
        $self->nexmo(
            mode => $mod,
            to   => $tel,
            text => $mes,
            lg   => undef   # lg will be missed in this response
        );

    # ...

L<Mojolicious::Plugin::Nexmo> supports the following options:

=over

=item api_key

=item api_secret

Your Nexmo API key & API secret. This two options are required, you should always declare it globally:

    plugin 'Nexmo' => {
        api_key    => '...',
        api_secret => '...'
        # ...
    }

=item mode

Can be 'SMS' or 'TTS'. Depending on mode there are different options:

=back

=head2 SMS options

See detailed description of SMS options at L<https://docs.nexmo.com/index.php/sms-api/send-message>.

    $self->nexmo(
        mode => 'SMS',
        # options
    );

=over

=item from

=item to

=item type

=item text

=item status-report-req

=item client-ref

=item network-code

=item vcard

=item vcal

=item ttl

=item message-class

=item body

=item udh

=back

=head2 TTS options

See detailed description of TTS options at L<https://docs.nexmo.com/index.php/voice-api/text-to-speech>.

    $self->nexmo(
        mode => 'TTS',
        # options
    );

=over

=item to

=item from

=item text

=item lg

=item voice

=item repeat

=item machine_detection

=item machine_timeout

=item callback

=item callback_method

=back

=head2 Asynchronous and synchronous modes

For B<asynchronous> mode you should pass a callback as last parameter:

    $self->nexmo(
        mode => 'SMS',
        # options
        sub {
            my ($self, $err, $err_mes, $info) = @_;
            # ...
        }
    );

If a callback is missed, plugin works in B<synchronous> mode:

    my ($err, $err_mes, $info) = $self->nexmo(
        mode => 'SMS',
        # options
    );

=head1 RETURN VALUES

=head2 Error code (C<$err>)

Values:

=over

=item B<0>

Success.

=item B<-1>

Network error.

=item B<1 - 99>

Nexmo error response codes.

See detailed description of SMS response codes at
L<https://docs.nexmo.com/index.php/sms-api/send-message#response_code>.

See detailed description of TTS response codes at
L<https://docs.nexmo.com/index.php/voice-api/text-to-speech#tts_response_code>.

=back

B<IT'S IMPORTANT:>
If you use 'SMS' mode, message can be divided into several parts.
If all parts were sent succesfully, then B<0> is returned.
Otherwise C<$err> will contain error code of first failed part.
If you need error codes of all parts, use C<$info> hash.

=head2 Error message (C<$err_mes>)

=head2 Additional information (C<$info>)

Hash that corresponds to the Nexmo JSON response.

=head1 DEBUG

Set C<MOJOLICIOUS_NEXMO_DEBUG> environment variable to turn Nexmo debug on.

    $ MOJOLICIOUS_NEXMO_DEBUG=1 morbo test

=head1 SEE ALSO

L<Mojolicious::Plugin::SMS>

L<Nexmo::SMS>

L<SMS::Send::Nexmo>

=head1 AUTHOR

Andrey Khozov, E<lt>avkhozov@googlemail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by avkhozov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
