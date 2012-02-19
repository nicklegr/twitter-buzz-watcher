#!ruby -Ku

SAVE_TWEET_PAST_DAYS = 7

require 'pp'
require 'twitter'
require 'tweetstream'
require 'mongoid'

class Tweet
  include Mongoid::Document

  field :status_id, type: Integer
  field :text, type: String

  field :user_id, type: Integer
  field :screen_name, type: String
  field :profile_image_url, type: String
  
  field :retweet_count, type: Integer
  field :created_at, type: DateTime # Twitterから取得した時刻。not レコード作成時刻

  embeds_many :retweets, :class_name => "Tweet", :cyclic => true
  embedded_in :original_tweet, :class_name => "Tweet", :cyclic => true

  validates_uniqueness_of :status_id
end

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
        # RTされた
        retweeted = status.retweeted_status

        # あまり古いものは無視
        return if Time.parse(retweeted.created_at) < Time.now - (SAVE_TWEET_PAST_DAYS * 24 * 3600)

        # オリジナルを作成 or 探す
        original = Tweet.find_or_initialize_by(status_id: retweeted.id)
        if original.new?
          original.status_id = retweeted.id
          original.text = retweeted.text
          original.user_id = retweeted.user.id
          original.screen_name = retweeted.user.screen_name
          original.profile_image_url = retweeted.user.profile_image_url
          # RT数は毎回更新
          original.created_at = retweeted.created_at
        end

        # RT数は毎回更新
        original.retweet_count = retweeted.retweet_count

        original.retweets.find_or_initialize_by(status_id: status.id) do |record|
          if record.new?
            record.status_id = status.id
            # textは容量の無駄なので保存しない
            record.user_id = status.user.id
            record.screen_name = status.user.screen_name
            record.profile_image_url = status.user.profile_image_url
            record.retweet_count = status.retweet_count
            record.created_at = status.created_at
          end
        end

        original.save!

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

Mongoid.configure do |conf|
  # uri: ENV['MONGOHQ_URL'],
  conf.master = Mongo::Connection.new.db('buzz_watcher')
end

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
