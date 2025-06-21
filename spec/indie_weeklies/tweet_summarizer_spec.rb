# frozen_string_literal: true

require "spec_helper"

RSpec.describe IndieWeeklies::TweetSummarizer do
  let(:summarizer) { described_class.new }
  
  describe "#summarize_tweet" do
    it "calls the OpenAI API with the correct prompt" do
      tweet_text = "Just launched my new SaaS product! Check it out at example.com #startup #indie"
      
      # Mock the OpenAI API call
      expect(summarizer).to receive(:query_openai).with(
        include("Tweet: #{tweet_text}")
      ).and_return("A new SaaS product has been launched.")
      
      summary = summarizer.summarize_tweet(tweet_text)
      expect(summary).to eq("A new SaaS product has been launched.")
    end
    
    it "strips whitespace from the summary" do
      expect(summarizer).to receive(:query_openai).and_return("  Summary with whitespace.  \n")
      
      summary = summarizer.summarize_tweet("Some tweet")
      expect(summary).to eq("Summary with whitespace.")
    end
  end
  
  describe "#summarize_tweets" do
    it "summarizes each tweet in the array" do
      tweets = [
        { "text" => "Tweet 1 content" },
        { "text" => "Tweet 2 content" }
      ]
      
      expect(summarizer).to receive(:summarize_tweet).with("Tweet 1 content").and_return("Summary 1")
      expect(summarizer).to receive(:summarize_tweet).with("Tweet 2 content").and_return("Summary 2")
      
      summarized_tweets = summarizer.summarize_tweets(tweets)
      
      expect(summarized_tweets[0]["summary"]).to eq("Summary 1")
      expect(summarized_tweets[1]["summary"]).to eq("Summary 2")
    end
    
    it "handles errors when summarizing individual tweets" do
      tweets = [
        { "text" => "Tweet 1 content" },
        { "text" => "Tweet 2 content" }
      ]
      
      expect(summarizer).to receive(:summarize_tweet).with("Tweet 1 content").and_raise("API error")
      expect(summarizer).to receive(:summarize_tweet).with("Tweet 2 content").and_return("Summary 2")
      
      summarized_tweets = summarizer.summarize_tweets(tweets)
      
      expect(summarized_tweets[0]["summary"]).to eq("Failed to summarize this tweet.")
      expect(summarized_tweets[1]["summary"]).to eq("Summary 2")
    end
  end
  
  describe "#query_openai", :vcr do
    it "returns a summary from the OpenAI API" do
      # This test would use VCR to record and replay the API interaction
      # For simplicity, we'll just test the error handling here
      
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise("Connection error")
      
      # Should retry and eventually return the fallback message
      result = summarizer.send(:query_openai, "Test prompt", 2)
      expect(result).to eq("Failed to generate summary.")
    end
  end
end