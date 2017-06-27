require 'minitest/autorun'
require_relative '../classes/news_bot'

class TestNewsBot < Minitest::Test
  def setup
    @news_bot = NewsBot.new
  end

  def test_category_text
    assert_equal "スポーツ", @news_bot.send(:category_text, "これはスポーツを文字列に含むテストです")
    assert_equal "芸能", @news_bot.send(:category_text, "これは芸能を文字列に含むテストです")
    assert_equal "その他", @news_bot.send(:category_text, "これはその他を文字列に含むテストです")
  end
end
