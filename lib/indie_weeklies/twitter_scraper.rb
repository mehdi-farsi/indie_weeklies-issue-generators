# frozen_string_literal: true

require "nokogiri"
require "json"
require "fileutils"
require "date"

module IndieWeeklies
  class TwitterScraper
    FOLLOWING_HTML_PATH = File.expand_path("../../db/following.html", __dir__)
    TWEETS_SCRAPER_SCRIPT = File.expand_path("../js/scrape_tweets.js", __dir__)
    TEMP_DIR = File.expand_path("../../tmp", __dir__)
    
    def initialize
      FileUtils.mkdir_p(TEMP_DIR)
    end
    
    # Parse following.html to extract Twitter usernames
    def get_following_list
      puts "Parsing following.html to extract Twitter usernames..."
      
      html = File.read(FOLLOWING_HTML_PATH)
      doc = Nokogiri::HTML(html)
      
      # Look for Twitter usernames in the HTML
      # Twitter usernames are typically in the format @username or in href="/username"
      usernames = []
      
      # Find all links that might contain Twitter usernames
      doc.css('a').each do |link|
        href = link['href']
        next unless href
        
        # Extract username from Twitter profile links
        if href.start_with?('/')
          username = href.sub('/', '')
          usernames << username unless username.empty? || username.include?('/')
        end
      end
      
      # Also look for @username patterns in the text
      doc.text.scan(/@([a-zA-Z0-9_]+)/).flatten.each do |username|
        usernames << username
      end
      
      # Remove duplicates and filter out non-username strings
      usernames = usernames.uniq.select { |u| u.match?(/^[a-zA-Z0-9_]+$/) }
      
      puts "Found #{usernames.size} Twitter usernames."
      
      # Convert to the format expected by the rest of the application
      usernames.map do |username|
        {
          "id" => username,
          "username" => username,
          "public_metrics" => { "followers_count" => 0 } # Will be updated when scraping
        }
      end
    end
    
    # Get recent tweets from following list
    def get_recent_tweets(following)
      puts "Scraping tweets from #{following.size} Twitter accounts..."
      
      # Create a temporary JSON file with usernames
      usernames_data = following.map { |f| f["username"] }
      temp_file = File.join(TEMP_DIR, "usernames_to_scrape.json")
      File.write(temp_file, JSON.generate(usernames_data))
      
      # Run the Puppeteer script to scrape tweets
      output_file = File.join(TEMP_DIR, "scraped_tweets.json")
      result = system("node #{TWEETS_SCRAPER_SCRIPT} #{temp_file} #{output_file}")
      
      if result && File.exist?(output_file)
        puts "Tweets scraped successfully."
        tweets = JSON.parse(File.read(output_file))
        
        # Add author information to each tweet
        tweets.each do |tweet|
          username = tweet["username"]
          author = following.find { |f| f["username"] == username }
          
          if author
            # Update author's follower count if available
            if tweet["author_followers_count"]
              author["public_metrics"]["followers_count"] = tweet["author_followers_count"]
            end
            
            tweet["author"] = author
          end
        end
        
        puts "Scraped #{tweets.size} tweets."
        tweets
      else
        puts "Failed to scrape tweets."
        []
      end
    end
    
    # Calculate engagement for tweets (likes + reposts + replies)
    def calculate_engagement(tweets)
      tweets.each do |tweet|
        tweet["public_metrics"] ||= {}
        tweet["public_metrics"]["like_count"] = tweet["likes"] || 0
        tweet["public_metrics"]["retweet_count"] = tweet["retweets"] || 0
        tweet["public_metrics"]["reply_count"] = tweet["replies"] || 0
        
        tweet["engagement"] = tweet["likes"].to_i + tweet["retweets"].to_i + tweet["replies"].to_i
      end
      
      tweets
    end
    
    # Get top tweets per account (1-2 per account based on engagement)
    def get_top_tweets_per_account(tweets, max_per_account = 2)
      tweets_by_author = tweets.group_by { |t| t["username"] }
      
      top_tweets = []
      tweets_by_author.each do |_, author_tweets|
        # Sort by engagement and take top max_per_account
        sorted_tweets = author_tweets.sort_by { |t| -t["engagement"] }
        top_tweets.concat(sorted_tweets.take(max_per_account))
      end
      
      puts "Selected #{top_tweets.size} top tweets."
      top_tweets
    end
  end
end