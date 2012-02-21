#!ruby -Ku

SHOW_TWEET_FROM = 24 * 3600 # 秒
TWEET_PER_BOT = 2
TWEET_SHOW_COUNT = 5

require 'pp'
require 'sinatra'
require 'haml'
require './db'
require './twitter_util'

# グラフ描画コードを生成
def create_draw_chart_code(status_ids, rows)
  ret = ""

  status_ids.each do |id|
    ret += <<-EOD
      // --------------------
      var data = new google.visualization.DataTable();
      data.addColumn('timeofday', 'time_offset');
      data.addColumn('number', 'RTs');
      data.addRows([
        #{rows[id]}
      ]);

      var options = {
        width: 400, height: 180,
        legend: {position: 'none'}
      };

      var chart = new google.visualization.AreaChart(document.getElementById('#{id}'));
      chart.draw(data, options);
    EOD
  end

  ret
end

get '/' do
  @status_ids = Array.new
  @embed_tweets = Hash.new
  @rows = Hash.new
  @rt_counts = Hash.new

  # 各botから均等に、最近の最もRTされたツイートを取得
  one_day_ago = Time.now - SHOW_TWEET_FROM
  user_ids = Tweet.all.distinct(:user_id)

  tweets = user_ids.map do |user_id|
    Tweet.where(:created_at.gt => one_day_ago).where(:user_id => user_id).desc(:retweet_count).limit(TWEET_PER_BOT)
  end

  tweets.flatten!.compact!
  tweets.sort! do |a, b| b.retweet_count <=> a.retweet_count end
  tweets = tweets[0, TWEET_SHOW_COUNT]

  # グラフ描画用のデータ生成
  tweets.each do |tweet|
    next if tweet.retweets.size == 0

    @status_ids << tweet.status_id
    @embed_tweets[ tweet.status_id ] = TwitterUtil.embed_tweet(tweet.status_id)

    rt_count_max = 0
    
    data = Array.new
    initial_rt_count = tweet.retweets.asc(:created_at).first.retweet_count

    tweet.retweets.asc(:created_at).each_with_index do |rt, index|
      time_offset = (rt.created_at - tweet.created_at).to_i
      h = time_offset / 3600
      m = (time_offset / 60) % 60
      s = time_offset % 60

      time_str = sprintf("[%d,%d,%d]", h, m, s)

      # retweet_countは変な値が返ってくることがあるので、適当に補正する
      rt_count = [rt.retweet_count, initial_rt_count + index].max

      rt_count_max = [rt_count, rt_count_max].max

      data << "[#{time_str},#{rt_count}]"
    end

    @rows[ tweet.status_id ] = data.join(",")
    @rt_counts[ tweet.status_id ] = rt_count_max
  end

  @draw_chart_code = create_draw_chart_code(@status_ids, @rows)

  haml :index
end
