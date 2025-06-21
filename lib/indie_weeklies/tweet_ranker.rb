# frozen_string_literal: true

module IndieWeeklies
  class TweetRanker
    # Calculate composite score for each tweet
    # score = engagement × 0.4 + author_followers × 0.6
    def rank_tweets(tweets)
      tweets.each do |tweet|
        engagement = tweet["engagement"] || 0
        author_followers = tweet.dig("author", "public_metrics", "followers_count") || 0
        
        tweet["score"] = (engagement * 0.4) + (author_followers * 0.6)
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