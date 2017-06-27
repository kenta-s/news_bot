require 'twitter'
require 'natto'
require 'yaml'
require 'pry'

class NewsBot
  OWNER = %w(kenta_s_dev).freeze
  CATEGORIES = %w(その他 経済 スポーツ 芸能).freeze
  CATEGORY_TRANSLATION = {
    others: 'その他',
    finance: '経済',
    sports: 'スポーツ',
    celebrity: '芸能'
  }.freeze
  CATEGORY_MAP = {
    'その他': '0',
    '芸能': '1',
    'スポーツ': '2',
    '経済': '3'
  }.freeze
  VALID_CATEGORIES = %(その他 経済).freeze

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

      tweet_category = category_text(tweet.text)

      if tweet_category.nil?
        text = "@#{user_name} 現在有効なカテゴリは「その他, 経済, スポーツ, 芸能」 です。"
      else
        label_update!(tweet, tweet_category)
        text = "@#{user_name} #{tweet_category} ですね。\n学習しておきます。"
      end

      @client.update(text, in_reply_to_status_id: tweet.id)
      File.open("replied.txt", "a") do |f|
        f.puts(tweet.id)
      end
    end
  end

  private

  def category_text(text)
    natto = Natto::MeCab.new
    words = []
    natto.parse(text) do |n|
      words << n.surface
    end
    (CATEGORIES & words).first
  end

  def label_update!(tweet, category)
    filename = config['news_json']
    json = open(filename) do |f|
      JSON.load(f)
    end

    target_tweet = @client.status(tweet.in_reply_to_status_id)
    train_data = {content: target_tweet.text, label: CATEGORY_MAP[category.to_sym]}
    json["YahooNews"][target_tweet.id] = train_data

    open(filename, 'w') do |f|
      JSON.dump(json, f)
    end
  end

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
    exec_file = config['exec_file']
    category = `python #{exec_file} '#{text}'`.chomp.to_sym
    CATEGORY_TRANSLATION[category]
  end

  def config
    @config ||= open('config.yml') do |f|
      YAML.load(f)
    end
  end
end
