use Mojolicious::Lite;
use Test::More;
use Test::Mojo;

# to run
# TEST_KEY=key TEST_SECRET=secret TEST_NUMBER=44123456789 prove -I lib/ t/



unless ( $ENV{TEST_KEY} && $ENV{TEST_SECRET} && $ENV{TEST_NUMBER} ) {
    plan skip_all => 'Set TEST_KEY, TEST_SECRET and TEST_NUMBER to enable this test. Use real phone number as TEST_NUMBER.' 
}



plugin 'Nexmo' => {api_key => $ENV{TEST_KEY}, api_secret => $ENV{TEST_SECRET}};



get '/sms-block' => sub {
    my $self = shift;
    my $from = $self->param('from');
    my $to = $self->param('to');
    my $text = $self->param('text');
    my $res = $self->send_sms(from => $from, to => $to, text => $text);
    $self->render(json => $res);
};

get '/sms-nonblock' => sub {
    my $self = shift;
    my $from = $self->param('from');
    my $to = $self->param('to');
    my $text = $self->param('text');
    $self->render_later;
    $self->send_sms(from => $from, to => $to, text => $text, sub {
    	my ($self, $err, $res) = @_;
        $self->render(json => $res);
    });
};



get '/tts-block' => sub {
    my $self = shift;
    my $to = $self->param('to');
    my $text = $self->param('text');
    my $res = $self->send_tts(to => $to, text => $text);
    $self->render(json => $res);
};

get '/tts-nonblock' => sub {
    my $self = shift;
    my $to = $self->param('to');
    my $text = $self->param('text');
    $self->render_later;
    $self->send_tts(to => $to, text => $text, sub {
        my ($self, $err, $res) = @_;
        $self->render(json => $res);
    });
};



my $t = Test::Mojo->new;

my $to = $ENV{TEST_NUMBER};



eval { app->send_sms(from => 'test', to => $to) };
like($@, qr/is required for Nexmo/, 'BLOCK: SMS TEST PARAMS ("text" missed)');

eval { app->send_sms(from => 'test', text => 'qwe') };
like($@, qr/is required for Nexmo/, 'BLOCK: SMS TEST PARAMS ("to" missed)');

eval { app->send_sms(text => 'test', to => $to) };
like($@, qr/is required for Nexmo/, 'BLOCK: SMS TEST PARAMS ("from" missed)');



eval { app->send_tts(to => $to) };
like($@, qr/is required for Nexmo/, 'BLOCK: TTS TEST PARAMS ("text" missed)');

eval { app->send_tts(text => 'qwe') };
like($@, qr/is required for Nexmo/, 'BLOCK: TTS TEST PARAMS ("to" missed)');



app->send_sms(from => 'test', to => $to, sub {
	my ($self, $err, $res) = @_;
    like($err, qr/is required for Nexmo/, 'NONBLOCK: SMS TEST PARAMS ("text" missed)');
});

app->send_sms(from => 'test', text => 'qwe', sub {
	my ($self, $err, $res) = @_;
	like($err, qr/is required for Nexmo/, 'NONBLOCK: SMS TEST PARAMS ("to" missed)');
});

app->send_sms(text => 'test', to => $to, sub {
	my ($self, $err, $res) = @_;
	like($err, qr/is required for Nexmo/, 'NONBLOCK: SMS TEST PARAMS ("from" missed)');
});



app->send_tts(to => $to, sub {
    my ($self, $err, $res) = @_;
    like($err, qr/is required for Nexmo/, 'NONBLOCK: TTS TEST PARAMS ("text" missed)');
});

app->send_tts(text => 'test', sub {
    my ($self, $err, $res) = @_;
    like($err, qr/is required for Nexmo/, 'NONBLOCK: TTS TEST PARAMS ("to" missed)');
});



my $url_b_sms = Mojo::URL->new('/sms-block')->query(from => 'test', to => $to, text => 'test');
$t->
    get_ok($url_b_sms)->
    status_is(200)->
    json_is('/message-count' => '1')->
 	json_is('/messages/0/status' => '0')->
    json_has('/messages/0/message-id');

my $url_nb_sms = Mojo::URL->new('/sms-nonblock')->query(from => 'test', to => $to, text => 'test');
$t->
    get_ok($url_nb_sms)->
    status_is(200)->
    json_is('/message-count' => '1')->
 	json_is('/messages/0/status' => '0')->
    json_has('/messages/0/message-id');



my $url_b_tts = Mojo::URL->new('/tts-block')->query(to => $to, text => 'test');
$t->
    get_ok($url_b_tts)->
    status_is(200)->
    json_is('/status' => '0')->
    json_has('/call-id');

my $url_nb_tts = Mojo::URL->new('/tts-nonblock')->query(to => $to, text => 'test');
$t->
    get_ok($url_nb_tts)->
    status_is(200)->
    json_is('/status' => '0')->
    json_has('/call-id');


done_testing();
