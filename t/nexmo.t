use Mojolicious::Lite;
use Test::More;
use Test::Mojo;

plugin 'Nexmo' => {api_key => 'key', api_secret => 'secret'};

get '/block' => sub {
    my $self = shift;
    $self->send_sms('x', from => 'from', to => 'to');
    $self->render(text => 'data');
};

get '/nonblock' => sub {
    my $self = shift;
    $self->send_sms('x', from => 'from', to => 'to', sub {
        $self->render(text => 'data');
    });
};

my $t = Test::Mojo->new;
$t->get_ok('/block')->status_is(200);
$t->get_ok('/nonblock')->status_is(200);

done_testing();
