#!ruby -Ku

require 'mongoid'

class Tweet
  include Mongoid::Document

  field :status_id, type: Integer
  field :text, type: String

  field :user_id, type: Integer
  field :screen_name, type: String
  field :profile_image_url, type: String
  
  field :retweet_count, type: Integer
  field :created_at, type: Time # Twitterから取得した時刻。not レコード作成時刻

  embeds_many :retweets, :class_name => "Tweet", :cyclic => true
  embedded_in :original_tweet, :class_name => "Tweet", :cyclic => true

  validates_uniqueness_of :status_id
end

Mongoid.configure do |conf|
  # uri: ENV['MONGOHQ_URL'],
  conf.master = Mongo::Connection.new.db('buzz_watcher')
end
