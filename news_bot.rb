require './classes/news_bot'

bot = NewsBot.new
bot.tweet_all!
bot.reply!
