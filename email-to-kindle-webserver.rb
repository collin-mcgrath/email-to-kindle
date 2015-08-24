# gem install gmail - https://github.com/dcparker/ruby-gmail
require 'gmail'
require 'sinatra'
require 'base64'

$gmail_login = ARGV[0]
$gmail_password = ARGV[1]
$gmail = Gmail.new $gmail_login, $gmail_password
$last_email_uid = nil

def fetch_last_email
  begin
    email = $gmail.inbox.emails.last
  rescue # error handling when connection is lost
    begin
      $gmail.logout
    ensure
      $gmail = Gmail.new $gmail_login, $gmail_password
      email = $gmail.inbox.emails.last    
    end
  end
  
  if email.uid == $last_email_uid
    return
  end
   
  $last_email_uid = email.uid
  $sender = Mail::Encodings.value_decode email.sender.first.name
  $subject = Mail::Encodings.value_decode email.subject
  $received_at = email.envelope.date
  $image = nil
  if email.attachments.size > 0 
    $image = convert_and_resize email.attachments.first.decoded
  end
end

ORIGINAL_IMAGE_PATH = '/tmp/email-to-kindle.original.jpg'
RESIZED_IMAGE_PATH = '/tmp/email-to-kindle.resized.jpg'

def convert_and_resize blob
  File.open(ORIGINAL_IMAGE_PATH, 'wb'){|f| f.write blob}
  cmd = "convert #{ORIGINAL_IMAGE_PATH} -resize 1024x1024 -auto-orient #{RESIZED_IMAGE_PATH}"
  `#{cmd}`
  File.read RESIZED_IMAGE_PATH
end

set :port, 1212

get '/email' do
  fetch_last_email
  
  <<STRING
<html>
  <head>
<style>
body {font-family: sans}
p {padding-top: 0; paddding-bottom: 0; margin-top: 0; margin-bottom: 0;}
</style>
</head>
  <body>
    <p  style="font-size: 120%"><b>#{$sender}</b>, #{$received_at}</p>
    <p style="font-size: 260%">#{$subject}</p>
    <img src="data:image/jpg;base64,#{Base64.encode64($image) if $image}" style="width:100%;">

    <script>
        function ajaxGetRequest(url, callback) { // https://gist.github.com/iwek/5599777
          var xhr;

          if(typeof XMLHttpRequest !== 'undefined') xhr = new XMLHttpRequest();
          else {
            var versions = ["MSXML2.XmlHttp.5.0", 
                "MSXML2.XmlHttp.4.0",
                "MSXML2.XmlHttp.3.0", 
                "MSXML2.XmlHttp.2.0",
                "Microsoft.XmlHttp"]

            for(var i = 0, len = versions.length; i < len; i++) {
            try {
              xhr = new ActiveXObject(versions[i]);
              break;
            }
              catch(e){}
            } // end for
          }

          xhr.onreadystatechange = ensureReadiness;

          function ensureReadiness() {
            if(xhr.readyState < 4) {
              return;
            }

            if(xhr.status !== 200) {
              return;
            }

            // all is well	
            if(xhr.readyState === 4) {
              callback(xhr);
            }			
          }

          xhr.open('GET', url, true);
          xhr.send('');
        }

        lastEmailChangedCheck = function(){
          ajaxGetRequest('should_we_reload?rendered_email_uid=#{$last_email_uid}', function(xhr) {	
            if(xhr.responseText == 'yes')
                location.reload();
          });
          setTimeout(lastEmailChangedCheck, 10000);
        }

        lastEmailChangedCheck();

    </script>
  </body>
</html>
STRING
end

get '/should_we_reload' do
  fetch_last_email
  (params['rendered_email_uid'].to_i == $last_email_uid) ? 'no' : 'yes'
end
