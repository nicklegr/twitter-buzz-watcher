#!ruby -Ku

require './db'
require './twitter_api'

class EmbedTweet
  include Mongoid::Document

  field :status_id, type: Integer
  field :html, type: String

  validates_uniqueness_of :status_id
end

class TwitterUtil
  def TwitterUtil.embed_tweet(status_id)
    cache = EmbedTweet.find_or_initialize_by(status_id: status_id)
    if cache.new?
      cache.html = TwitterAPI.new.embed_tweet(status_id)
      
      # @todo Rate limitなどで取得できなかったら保存しないほうがいい
      # しかし、それが繰り返されると高頻度にAPIコールしてしまう
      # キャッシュに寿命を設定？
      cache.save!
    end
    
    cache.html
  end
end
