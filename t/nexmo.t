use Mojolicious::Lite;
use Test::More;
use Test::Mojo;

# to run
# TEST_KEY=key TEST_SECRET=secret TEST_NUMBER=44123456789 prove -I lib/ t/

unless ($ENV{TEST_KEY} && $ENV{TEST_SECRET} && $ENV{TEST_NUMBER}) {
  plan skip_all =>
'Set TEST_KEY, TEST_SECRET and TEST_NUMBER to enable this test. Use real phone number as TEST_NUMBER.';
}

# Required Nexmo parameters
eval { plugin 'Nexmo' => {api_key => $ENV{TEST_KEY}}; };
like($@, qr/Nexmo.*is required/i, 'api_secret missed');
#
eval { plugin 'Nexmo' => {api_secret => $ENV{TEST_SECRET}}; };
like($@, qr/Nexmo.*is required/i, 'api_key missed');

plugin 'Nexmo' => {api_key => $ENV{TEST_KEY}, api_secret => $ENV{TEST_SECRET}};

# No such mode
eval { app->nexmo(mode => 'qwe'); };
like($@, qr/no such mode/i, 'no such mode');


get '/block' => sub {
  my $self = shift;
  my $mode = $self->param('mode');
  my $from = $self->param('from');
  my $to   = $self->param('to');
  my $text = $self->param('text');
  my ($err, $err_msg, $info) = $self->nexmo(mode => $mode, from => $from, to => $to, text => $text);
  $self->render(json => $info);
};

get '/nonblock' => sub {
  my $self = shift;
  my $mode = $self->param('mode');
  my $from = $self->param('from');
  my $to   = $self->param('to');
  my $text = $self->param('text');

  # $self->render_later;
  my ($err, $err_msg, $info) = $self->nexmo(
    mode => $mode,
    from => $from,
    to   => $to,
    text => $text,
    sub {
      my ($self, $err, $err_msg, $info) = @_;
      $self->render(json => $info);
    });
};


my $t = Test::Mojo->new;

my $to = $ENV{TEST_NUMBER};
my $url;

for my $path (qw( /block /nonblock )) {

  # Required parameters
  $url = Mojo::URL->new($path)->query(mode => 'SMS', to => $to, text => 'test');
  $t->get_ok($url)->status_is(200)->json_is('/message-count' => '1')
    ->json_is('/messages/0/status' => '2');
  $url = Mojo::URL->new($path)->query(mode => 'SMS', from => 'test', text => 'test');
  $t->get_ok($url)->status_is(200)->json_is('/message-count' => '1')
    ->json_is('/messages/0/status' => '2');
  $url = Mojo::URL->new($path)->query(mode => 'SMS', from => 'test', to => $to);
  $t->get_ok($url)->status_is(200)->json_is('/message-count' => '1')
    ->json_is('/messages/0/status' => '2');

  $url = Mojo::URL->new($path)->query(mode => 'TTS', to => $to);
  $t->get_ok($url)->status_is(200)->json_is('/status' => '2');

  $url = Mojo::URL->new($path)->query(mode => 'TTS', text => 'test');
  $t->get_ok($url)->status_is(200)->json_is('/status' => '2');

  # Normal responses
  $url = Mojo::URL->new($path)->query(mode => 'SMS', text => 'test', to => $to, from => 'test');
  $t->get_ok($url)->status_is(200)->json_is('/messages/0/status' => '0')
    ->json_has('/messages/0/message-id');

  $url = Mojo::URL->new($path)->query(mode => 'TTS', text => 'test', to => $to);
  $t->get_ok($url)->status_is(200)->json_is('/status' => '0')->json_has('/call-id');
}

done_testing();
