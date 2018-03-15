use strict;
#!/bin/perl -w
use strict;
use warnings;
use 5.10.0;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::JSON qw(encode_json);
use MIME::Base64 qw(decode_base64);
use Email::Valid qw(address);
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();
use Data::Dumper;


##### BEGIN CHANGE: variable declarations, set your options here
# Set webadm hostname, user credentials (edit this according to taste) - see https://www.rcdevs.com/docs/howtos/api/api/#1-manager-api
my $webadm = {  'host' => 'localhost',
                'username' => 'cn=admin,o=root',
                'password' => 'somepassword'
};

# Set some mail parameters (edit this according to taste)
my $mail = {    'to' => 'user@example.org',
                'from' => 'noreply@example.org',
                'subject' => 'Information about accessing your applications',
                'html_body' => 'Please scan the following file attachment with Google Authenticator or other OTP tool for your OTP pass code.',
                'transport' => Email::Sender::Transport::SMTP->new(host => 'localhost')
};

# request parameters hashes for each api call, some with constants (edit this according to taste)
my $api1 = {'domain' => 'yourdomain'};  # for getting username dn, setting domain here, you can also prompt for domain, see api call #1 comments below
my $api2 = {'attrs' => ['mail']};  # for getting email address
my $api3 = {};  # for getting username base64 gr code

##### END CHANGE: No need to really change things below this line

##### disable SSL verification of webadm site for Mojolicious user agent, from https://stackoverflow.com/questions/35197010/mojouseragent-certificate-verify-failed
IO::Socket::SSL::set_defaults( SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE);

# instantiate Mojolicious user agent and url modules, prep api connection string for sending request to webadm API
my $ua = Mojo::UserAgent->new;
$ua = $ua->max_redirects(3);
my $url = Mojo::URL->new('https://' . $webadm->{'host'} . '/manag')->userinfo($webadm->{'username'} . ':' . $webadm->{'password'});
my $request = {'jsonrpc' => "2.0",'method' => '','params' => '','id' => 0};


##### api call #1 - get cli input for name of user and domain to obtain, RETURN = dn string
print "Enter user CN found in webadm to obtain QRCode for: ";
$api1->{'username'} = <STDIN>;
chomp $api1->{'username'};
#print "Enter webadm DOMAIN of the user: ";
#my $api1->{'domain'} = <STDIN>;
#chomp $api1->{'domain'};
my $retapi1 = &execAPI('Get_User_DN', $api1);


##### api call #2 - get user email address from webadm and validate returned value RETURN = ARRAY Object
$api2->{'dn'} = $retapi1;
my $retapi2 = &execAPI('Get_User_attrs', $api2);
die("did not receive any email address") unless ($retapi2->{'mail'});  # making sure a email address hash element returns
my $address = Email::Valid->address($retapi2->{'mail'}->{'0'});  # WebAdm does not validate email addresses, doing that here
die("did not receive a valid email address") unless (defined $address);


###### api call #3 get the Base64 QR Code from the first api call, decode to GIF RETURN = base64 string
$api3->{'dn'} = $retapi1;  # return of api1 is dn for api2 call
$api3->{'name'} = $api1->{'username'};  # using username for name of QR Code
my $retapi3 = &execAPI('OpenOTP.Token_QRCode', $api3);
my $decoded = decode_base64($retapi3);


##### Send out Email with QRCode attached
my $result = &execMail($decoded);
if ($result) { say "Email is sent successfully"; }
else { say "Email did not send for some reason";}


##### FUNCTIONS
sub execAPI {
        $request->{'method'} = shift;
        $request->{'params'} = shift;
        my $r = $ua->post( $url => { 'Content-Type' => 'application/json' } => encode_json($request))->res->json;

        ## end script if something unexpected happens...
        die ("There was an error executing, error is: " . Dumper($r->{'error'})) if $r->{'error'};
        die ("There was no result from the api call user " . $request->{'method'}) if (length($r->{'result'}) == 0);
        return $r->{'result'};
}

sub execMail {
        my $attachment = shift;
        my $email = Email::Stuffer->new($mail);

        $email->attach($attachment, 'encoding' => 'base64', 'content-type' => 'image/gif', 'filename' => 'image.gif', 'disposition' => 'attachment');
        return $email->send;
}
