# frozen_string_literal: true

require_relative "account_popularity"

module IndieWeeklies
  class TweetRanker
    # Calculate composite score for each tweet
    # score = engagement × 0.4 + account_popularity × 0.6
    def initialize
      @account_popularity = AccountPopularity.new
    end

    def rank_tweets(tweets)
      tweets.each do |tweet|
        engagement = tweet["engagement"] || 0
        username = tweet.dig("author", "username") || tweet["username"]
        popularity = username ? @account_popularity.get_score(username) : 0

        tweet["score"] = (engagement * 0.4) + (popularity * 0.6)
      end

      # Sort tweets by score in descending order
      tweets.sort_by { |tweet| -tweet["score"] }
    end

    # Get top N tweets
    def get_top_tweets(tweets, limit = 30)
      rank_tweets(tweets).take(limit)
    end
  end
end
