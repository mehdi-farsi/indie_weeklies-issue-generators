# frozen_string_literal: true

require "faraday"
require "json"

module IndieWeeklies
  class TweetSummarizer
    OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
    
    def initialize
      @api_key = ENV.fetch("OPENAI_API_KEY")
      @connection = Faraday.new(url: OPENAI_API_URL) do |conn|
        conn.headers["Authorization"] = "Bearer #{@api_key}"
        conn.headers["Content-Type"] = "application/json"
      end
    end
    
    # Summarize a tweet into a 1-2 sentence plain-language blurb
    def summarize_tweet(tweet_text)
      prompt = <<~PROMPT
        Summarize the following tweet into 1-2 plain-language sentences. 
        Do not include hashtags, emojis, or special characters in your summary.
        Make it concise, informative, and easy to understand.
        
        Tweet: #{tweet_text}
      PROMPT
      
      response = query_openai(prompt)
      response.strip
    end
    
    # Summarize multiple tweets
    def summarize_tweets(tweets)
      tweets.each_with_index do |tweet, index|
        puts "Summarizing tweet #{index + 1}/#{tweets.size}..."
        
        begin
          tweet["summary"] = summarize_tweet(tweet["text"])
        rescue StandardError => e
          puts "Error summarizing tweet: #{e.message}"
          tweet["summary"] = "Failed to summarize this tweet."
        end
        
        # Add a small delay to avoid rate limiting
        sleep 0.5 unless index == tweets.size - 1
      end
      
      tweets
    end
    
    private
    
    def query_openai(prompt, max_retries = 3)
      retries = 0
      
      begin
        payload = {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: "You are a helpful assistant that summarizes tweets into concise, plain-language blurbs." },
            { role: "user", content: prompt }
          ],
          temperature: 0.7,
          max_tokens: 100
        }
        
        response = @connection.post do |req|
          req.body = payload.to_json
        end
        
        if response.status == 429 # Rate limited
          retry_after = response.headers["retry-after"].to_i || 60
          puts "Rate limited by OpenAI. Waiting for #{retry_after} seconds..."
          sleep retry_after
          raise "Rate limited"
        end
        
        if response.status != 200
          puts "Error from OpenAI API: #{response.status} - #{response.body}"
          return "Failed to generate summary."
        end
        
        result = JSON.parse(response.body)
        result.dig("choices", 0, "message", "content")
      rescue StandardError => e
        retries += 1
        if retries <= max_retries
          puts "Error: #{e.message}. Retrying (#{retries}/#{max_retries})..."
          sleep 2 ** retries # Exponential backoff
          retry
        else
          puts "Failed after #{max_retries} retries: #{e.message}"
          "Failed to generate summary."
        end
      end
    end
  end
end