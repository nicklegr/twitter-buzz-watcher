#!ruby -Ku

require 'pp'
require 'twitter'
require 'tweetstream'

class Worker
  def initialize
    TweetStream.configure do |config|
      config.consumer_key = ENV['CONSUMER_KEY']
      config.consumer_secret = ENV['CONSUMER_SECRET']
      config.oauth_token = ENV['OAUTH_TOKEN']
      config.oauth_token_secret = ENV['OAUTH_TOKEN_SECRET']
      config.auth_method = :oauth
    end
  end

  def start
    client = TweetStream::Client.new

    client.on_timeline_status do |status|
      on_new_status(status)
    end

    target_accounts = ENV['TARGET_ACCOUNTS'].split
    target_ids = target_accounts.map do |e| Twitter.user(e).id end
    client.follow(target_ids)
  end

  def on_new_status(status)
    begin
      # pp status

      if status.has_key?(:retweeted_status)
        retweeted = status.retweeted_status

        id = retweeted.id
        count = retweeted.retweet_count
        
        rt_time = Time.parse(status.created_at)

        puts "#{rt_time.getlocal}: #{retweeted.user.screen_name}'s #{id}: RT by #{status.user.screen_name}, count #{count}"
      end
    rescue => e
      # 不明なエラーのときも、とりあえず動き続ける
      puts "#{e} (#{e.class})"
      puts e.backtrace
    end
  end
end


$stdout.sync = true

loop do
  begin
    worker = Worker.new
    worker.start
  rescue => e
    # 不明なエラーのときも、とりあえず動き続ける
    puts "#{e} (#{e.class})"
    puts e.backtrace
  end

  # @todo logスリープ
  sleep 10
end
