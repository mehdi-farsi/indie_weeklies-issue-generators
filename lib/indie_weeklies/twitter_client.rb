# frozen_string_literal: true

require "faraday"
require "json"
require "date"

module IndieWeeklies
  class TwitterClient
    BASE_URL = "https://api.twitter.com/2"
    
    def initialize
      @bearer_token = ENV.fetch("TWITTER_BEARER_TOKEN")
      @username = ENV.fetch("TWITTER_USERNAME")
      @connection = Faraday.new(url: BASE_URL) do |conn|
        conn.headers["Authorization"] = "Bearer #{@bearer_token}"
        conn.headers["Content-Type"] = "application/json"
      end
    end
    
    # Step 1: Get user ID from username
    def get_user_id
      response = query_with_retries("users/by/username/#{@username}")
      response.dig("data", "id")
    end
    
    # Step 2: Get following list (accounts the user follows)
    def get_following_list
      user_id = get_user_id
      following = []
      pagination_token = nil
      
      loop do
        params = {
          "max_results" => 1000,
          "user.fields" => "public_metrics"
        }
        params["pagination_token"] = pagination_token if pagination_token
        
        response = query_with_retries("users/#{user_id}/following", params)
        
        break unless response["data"]
        
        following.concat(response["data"])
        
        pagination_token = response.dig("meta", "next_token")
        break unless pagination_token
      end
      
      following
    end
    
    # Step 3: Get tweets from following list for the past 7 days
    def get_recent_tweets(following_ids)
      start_time = (Date.today - 7).strftime("%Y-%m-%dT00:00:00Z")
      end_time = Date.today.strftime("%Y-%m-%dT23:59:59Z")
      
      all_tweets = []
      
      following_ids.each_slice(100) do |user_ids_batch|
        tweets_for_batch = get_tweets_for_users(user_ids_batch, start_time, end_time)
        all_tweets.concat(tweets_for_batch)
      end
      
      all_tweets
    end
    
    # Get tweets for a batch of users
    def get_tweets_for_users(user_ids, start_time, end_time)
      tweets = []
      
      user_ids.each do |user_id|
        params = {
          "max_results" => 100,
          "tweet.fields" => "public_metrics,created_at",
          "expansions" => "author_id",
          "user.fields" => "public_metrics",
          "start_time" => start_time,
          "end_time" => end_time
        }
        
        response = query_with_retries("users/#{user_id}/tweets", params)
        
        next unless response["data"]
        
        # Add author information to each tweet
        author = response.dig("includes", "users")&.find { |u| u["id"] == user_id }
        
        response["data"].each do |tweet|
          tweet["author"] = author
          tweets << tweet
        end
      end
      
      tweets
    end
    
    # Calculate engagement for tweets (likes + reposts + replies)
    def calculate_engagement(tweets)
      tweets.each do |tweet|
        metrics = tweet.dig("public_metrics")
        tweet["engagement"] = metrics["like_count"] + metrics["retweet_count"] + metrics["reply_count"]
      end
    end
    
    # Get top tweets per account (1-2 per account based on engagement)
    def get_top_tweets_per_account(tweets, max_per_account = 2)
      tweets_by_author = tweets.group_by { |t| t.dig("author", "id") }
      
      top_tweets = []
      tweets_by_author.each do |_, author_tweets|
        # Sort by engagement and take top max_per_account
        sorted_tweets = author_tweets.sort_by { |t| -t["engagement"] }
        top_tweets.concat(sorted_tweets.take(max_per_account))
      end
      
      top_tweets
    end
    
    private
    
    def query_with_retries(endpoint, params = {}, max_retries = 3)
      retries = 0
      
      begin
        response = @connection.get(endpoint, params)
        
        if response.status == 429 # Rate limited
          retry_after = response.headers["retry-after"].to_i || 60
          puts "Rate limited. Waiting for #{retry_after} seconds..."
          sleep retry_after
          raise "Rate limited"
        end
        
        if response.status != 200
          puts "Error: #{response.status} - #{response.body}"
          return {}
        end
        
        JSON.parse(response.body)
      rescue StandardError => e
        retries += 1
        if retries <= max_retries
          puts "Error: #{e.message}. Retrying (#{retries}/#{max_retries})..."
          sleep 2 ** retries # Exponential backoff
          retry
        else
          puts "Failed after #{max_retries} retries: #{e.message}"
          {}
        end
      end
    end
  end
end