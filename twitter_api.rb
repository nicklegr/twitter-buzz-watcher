#!ruby -Ku

require 'net/https'
require 'json'

class TwitterAPI
  def initialize
    @https = Net::HTTP.new('api.twitter.com', 443)
    @https.use_ssl = true
    @https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @https.verify_depth = 5
  end

  def embed_tweet(status_id)
    path = "/1/statuses/oembed.json?id=#{status_id}&lang=ja&omit_script=true"
    response = @https.request_get(path)

    JSON.parse(response.body)['html']
  end
end
