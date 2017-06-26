require 'twitter'
require 'mecab'
require 'pry'

class NewsBot
  OWNER = %w(kenta_s_dev)
  CATEGORIES = %w(その他 経済 スポーツ 芸能)
  CATEGORY_MAP = {
    others: 'その他',
    finance: '経済',
    sports: 'スポーツ',
    celebrity: '芸能'
  }
  VALID_CATEGORIES = %(その他 経済)

  def initialize
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['KENTA_S_NEWS_CONSUMER_KEY']
      config.consumer_secret     = ENV['KENTA_S_NEWS_CONSUMER_SECRET']
      config.access_token        = ENV['KENTA_S_NEWS_ACCESS_TOKEN']
      config.access_token_secret = ENV['KENTA_S_NEWS_ACCESS_TOKEN_SECRET']
    end
    @user = "@YahooNewsTopics"
  end

  def tweet_all!
    @client.user_timeline(@user).first(5).each do |tweet|
      tweet!(tweet)
    end
  end

  def tweet!(tweet)
    if valid_tweet?(tweet)
      File.open("tweeted.txt", "a") do |f|
        f.puts(tweet.id)
      end
      @client.update(tweet.text + " [ from #{@user} ]")
    end
  end

  def reply!
    resent_replies = @client.mentions_timeline.first(10)
    resent_replies.each do |tweet|
      user_name = tweet.user.screen_name
      next unless OWNER.include?(user_name)
      next unless valid_reply?(tweet.id)

      tweet.text
      tweet_category = nil
      CATEGORIES.each do |category|
        if tweet.text.match(category)
          tweet_category = $&
        else
          next
        end
      end

      if tweet_category.nil?
        text = "@#{user_name} 現在有効なカテゴリは「その他, 経済, スポーツ, 芸能」 です。"
      else
        text = "@#{user_name} #{tweet_category} ですね。\n学習しますた m9(^Д^)"
      end

      @client.update(text, in_reply_to_status_id: tweet.id)
      File.open("replied.txt", "a") do |f|
        f.puts(tweet.id)
      end
    end
  end

  private

  def valid_tweet?(tweet)
    tweet_id = tweet.id.to_s + "\n"

    file = File.open('tweeted.txt', 'r')
    resent_tweeted_ids = file.readlines.last(10)
    return false if resent_tweeted_ids.include?(tweet_id)
    return false unless VALID_CATEGORIES.include?(tweet_category(tweet))
    true
  end

  def valid_reply?(tweet_id)
    tweet_id = tweet_id.to_s + "\n"
    file = File.open('replied.txt', 'r')
    tweeted_ids = file.readlines.last(10)
    !tweeted_ids.include?(tweet_id)
  end

  def tweet_category(tweet)
    text = tweet.text
    exec_file = '../news_classifier/news_classifier.py'
    category = `python #{exec_file} '#{text}'`.chomp.to_sym
    CATEGORY_MAP[category]
  end
end

bot = NewsBot.new
bot.tweet_all!
bot.reply!
