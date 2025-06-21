# frozen_string_literal: true

require "spec_helper"

RSpec.describe IndieWeeklies::TweetRanker do
  let(:ranker) { described_class.new }
  
  describe "#rank_tweets" do
    it "calculates the correct score for each tweet" do
      tweets = [
        {
          "engagement" => 100,
          "author" => {
            "public_metrics" => {
              "followers_count" => 1000
            }
          }
        },
        {
          "engagement" => 200,
          "author" => {
            "public_metrics" => {
              "followers_count" => 500
            }
          }
        }
      ]
      
      ranked_tweets = ranker.rank_tweets(tweets)
      
      # First tweet score: 100 * 0.4 + 1000 * 0.6 = 40 + 600 = 640
      # Second tweet score: 200 * 0.4 + 500 * 0.6 = 80 + 300 = 380
      
      expect(ranked_tweets[0]["score"]).to eq(640)
      expect(ranked_tweets[1]["score"]).to eq(380)
    end
    
    it "sorts tweets by score in descending order" do
      tweets = [
        {
          "engagement" => 50,
          "author" => {
            "public_metrics" => {
              "followers_count" => 200
            }
          }
        },
        {
          "engagement" => 100,
          "author" => {
            "public_metrics" => {
              "followers_count" => 1000
            }
          }
        },
        {
          "engagement" => 200,
          "author" => {
            "public_metrics" => {
              "followers_count" => 500
            }
          }
        }
      ]
      
      ranked_tweets = ranker.rank_tweets(tweets)
      
      # Expected scores:
      # Tweet 1: 50 * 0.4 + 200 * 0.6 = 20 + 120 = 140
      # Tweet 2: 100 * 0.4 + 1000 * 0.6 = 40 + 600 = 640
      # Tweet 3: 200 * 0.4 + 500 * 0.6 = 80 + 300 = 380
      
      expect(ranked_tweets.map { |t| t["score"] }).to eq([640, 380, 140])
    end
    
    it "handles missing data gracefully" do
      tweets = [
        { "engagement" => nil },
        { "author" => nil },
        { "author" => { "public_metrics" => nil } },
        { "author" => { "public_metrics" => { "followers_count" => nil } } },
        {}
      ]
      
      ranked_tweets = ranker.rank_tweets(tweets)
      
      # All scores should be 0 due to missing data
      expect(ranked_tweets.all? { |t| t["score"] == 0 }).to be true
    end
  end
  
  describe "#get_top_tweets" do
    it "returns the top N tweets by score" do
      tweets = [
        { "engagement" => 50, "author" => { "public_metrics" => { "followers_count" => 200 } } },
        { "engagement" => 100, "author" => { "public_metrics" => { "followers_count" => 1000 } } },
        { "engagement" => 200, "author" => { "public_metrics" => { "followers_count" => 500 } } },
        { "engagement" => 150, "author" => { "public_metrics" => { "followers_count" => 300 } } }
      ]
      
      top_tweets = ranker.get_top_tweets(tweets, 2)
      
      expect(top_tweets.size).to eq(2)
      expect(top_tweets[0]["score"]).to eq(640) # Highest score
      expect(top_tweets[1]["score"]).to eq(380) # Second highest score
    end
  end
end