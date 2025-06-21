# frozen_string_literal: true

require "json"
require "fileutils"

module IndieWeeklies
  class ScreenshotGenerator
    SCREENSHOTS_DIR = File.expand_path("../../tmp/screenshots", __dir__)
    PUPPETEER_SCRIPT = File.expand_path("../js/screenshot_tweets.js", __dir__)

    def initialize
      FileUtils.mkdir_p(SCREENSHOTS_DIR)
    end

    # Generate screenshots for a list of tweets
    def generate_screenshots(tweets)
      # Create a temporary JSON file with tweet data
      tweet_data = tweets.map do |tweet|
        {
          id: tweet["id"],
          url: "https://twitter.com/#{tweet['username'] || tweet.dig('author', 'username')}/status/#{tweet['id']}"
        }
      end

      temp_file = File.join(SCREENSHOTS_DIR, "tweets_to_screenshot.json")
      File.write(temp_file, JSON.generate(tweet_data))

      # Run the Puppeteer script to take screenshots
      puts "Taking screenshots of #{tweets.size} tweets..."
      result = system("node #{PUPPETEER_SCRIPT} #{temp_file} #{SCREENSHOTS_DIR}")

      if result
        puts "Screenshots generated successfully."

        # Add screenshot paths to tweet objects
        tweets.each do |tweet|
          screenshot_path = File.join(SCREENSHOTS_DIR, "#{tweet['id']}.png")
          tweet["screenshot_path"] = screenshot_path if File.exist?(screenshot_path)
        end
      else
        puts "Failed to generate screenshots."
      end

      tweets
    end
  end
end
