use Mojolicious::Lite;
use Test::More;
use Test::Mojo;

# to run
# TEST_KEY=key TEST_SECRET=secret prove -I lib/ t/

plan skip_all => 'set TEST_KEY and TEST_SECRET to enable this test' unless $ENV{TEST_KEY} && $ENV{TEST_SECRET};

plugin 'Nexmo' => {api_key => $ENV{TEST_KEY}, api_secret => $ENV{TEST_SECRET}};

get '/block' => sub {
    my $self = shift;
    my $from = $self->param('from');
    my $to = $self->param('to');
    my $text = $self->param('text');
    my $ans = $self->send_sms(from => $from, to => $to, text => $text);
    $self->render(json => $ans);
};

get '/nonblock' => sub {
    my $self = shift;
    my $from = $self->param('from');
    my $to = $self->param('to');
    my $text = $self->param('text');
    $self->send_sms(text => $text, from => $from, to => $to, sub {
    	my ($err, $res) = @_;
        $self->render(json => $res);
    });
};

my $t = Test::Mojo->new;

my $to = '44123456789';

eval { app->send_sms(from => 'test', to => $to) };
like($@, qr/is required for Nexmo/, 'test params');

eval { app->send_sms(from => 'test', text => 'qwe') };
like($@, qr/is required for Nexmo/, 'test params');

eval { app->send_sms(text => 'test', to => $to) };
like($@, qr/is required for Nexmo/, 'test params');

app->send_sms(from => 'test', to => $to, sub {
	my ($err, $res) = @_;
	like($err, qr/is required for Nexmo/, 'test params');
});

app->send_sms(from => 'test', text => 'qwe', sub {
	my ($err, $res) = @_;
	like($err, qr/is required for Nexmo/, 'test params');
});

app->send_sms(text => 'test', to => $to, sub {
	my ($err, $res) = @_;
	like($err, qr/is required for Nexmo/, 'test params');
});

# app->send_sms(text => 'this is test', to => $to, from => 'test', sub {
# 	my ($err, $res) = @_;
# 	is($err, undef, 'test undef err');
# 	my $p = Mojo::JSON::Pointer->new;
# 	$p->get($res, '/messages/0/status');
# });

my $url_bt = Mojo::URL->new('/block')->query(from => 'test', to => $to, text => 'test');
$t->get_ok($url_bt)->status_is(200)->json_is('/message-count' => '1')->
 				json_is('/messages/0/status' => '0')->json_has('/messages/0/message-id');


my $url_nbt = Mojo::URL->new('/nonblock')->query(from => 'test', to => $to, text => 'test');
$t->get_ok($url_nbt)->status_is(200)->json_is('/message-count' => '1')->
 				json_is('/messages/0/status' => '0')->json_has('/messages/0/message-id');

done_testing();
