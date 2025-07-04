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
      puts "[PARSE] Reading following.html from #{FOLLOWING_HTML_PATH}"

      html = File.read(FOLLOWING_HTML_PATH)
      doc = Nokogiri::HTML(html)
      puts "[PARSE] HTML parsed successfully, document size: #{html.size} bytes"

      # Extract Twitter handles from the HTML table
      # The handles are in the second column (td) of each row, in the format @username
      usernames = []

      # Find all table rows except the header row
      table_rows = doc.css('table tr')
      puts "[PARSE] Found #{table_rows.size} rows in the table"

      table_rows.each_with_index do |row, index|
        # Skip the header row
        next if index == 0

        # Get the handle from the second column
        handle_cell = row.css('td')[1]
        next unless handle_cell

        handle = handle_cell.text.strip
        puts "[PARSE] Row #{index}: Found handle '#{handle}'"

        # Extract username by removing the @ prefix
        if handle.start_with?('@')
          username = handle[1..-1] # Remove the @ prefix
          puts "[PARSE] Extracted username: #{username}"
          usernames << username unless username.empty?
        else
          puts "[PARSE] Handle doesn't start with @, skipping"
        end
      end

      puts "[PARSE] Found #{usernames.size} Twitter usernames."
      puts "[PARSE] First 5 usernames: #{usernames.take(5).join(', ')}" if usernames.any?

      # Convert to the format expected by the rest of the application
      formatted_usernames = usernames.map do |username|
        {
          "id" => username,
          "username" => username,
          "public_metrics" => { "followers_count" => 0 } # Will be updated when scraping
        }
      end

      puts "[PARSE] Converted usernames to expected format"
      formatted_usernames
    end

    # Get recent tweets from following list
    def get_recent_tweets(following)
      puts "Scraping tweets from #{following.size} Twitter accounts..."

      # Create a temporary JSON file with usernames
      usernames_data = following.map { |f| f["username"] }
      puts "[PARSE] Extracted #{usernames_data.size} usernames for scraping"
      puts "[PARSE] First 5 usernames: #{usernames_data.take(5).join(', ')}" if usernames_data.any?

      temp_file = File.join(TEMP_DIR, "usernames_to_scrape.json")
      File.write(temp_file, JSON.generate(usernames_data))
      puts "[PARSE] Wrote usernames to temporary file: #{temp_file}"

      # Run the Puppeteer script to scrape tweets
      output_file = File.join(TEMP_DIR, "scraped_tweets.json")
      puts "[PARSE] Running Puppeteer script: node #{TWEETS_SCRAPER_SCRIPT} #{temp_file} #{output_file}"
      start_time = Time.now
      result = system("node #{TWEETS_SCRAPER_SCRIPT} #{temp_file} #{output_file}")
      end_time = Time.now
      duration = (end_time - start_time).to_i
      puts "[PARSE] Puppeteer script completed in #{duration} seconds with result: #{result}"

      if result && File.exist?(output_file)
        puts "Tweets scraped successfully."
        puts "[PARSE] Reading tweets from output file: #{output_file}"

        file_size = File.size(output_file)
        puts "[PARSE] Output file size: #{file_size} bytes"

        tweets = JSON.parse(File.read(output_file))
        puts "[PARSE] Parsed #{tweets.size} tweets from JSON"

        if tweets.any?
          puts "[PARSE] Sample tweet (first in collection):"
          puts "[PARSE] #{tweets.first.inspect}"
        end

        # Add author information to each tweet
        puts "[PARSE] Adding author information to tweets..."
        tweets.each_with_index do |tweet, index|
          username = tweet["username"]
          puts "[PARSE] Processing tweet #{index + 1}/#{tweets.size} from @#{username}"

          author = following.find { |f| f["username"] == username }

          if author
            puts "[PARSE] Found author information for @#{username}"


            tweet["author"] = author
          else
            puts "[PARSE] No author information found for @#{username}"
          end
        end

        puts "[PARSE] Scraped #{tweets.size} tweets."
        tweets
      else
        puts "Failed to scrape tweets."
        puts "[PARSE] Puppeteer script failed or output file not found: #{output_file}"
        []
      end
    end

    # Calculate engagement for tweets (likes + reposts + replies)
    def calculate_engagement(tweets)
      puts "[PARSE] Calculating engagement metrics for #{tweets.size} tweets..."

      tweets.each_with_index do |tweet, index|
        tweet_id = tweet["id"]
        username = tweet["username"]
        puts "[PARSE] Processing tweet #{index + 1}/#{tweets.size} (ID: #{tweet_id}) from @#{username}"

        tweet["public_metrics"] ||= {}

        likes = tweet["likes"] || 0
        retweets = tweet["retweets"] || 0
        replies = tweet["replies"] || 0

        tweet["public_metrics"]["like_count"] = likes
        tweet["public_metrics"]["retweet_count"] = retweets
        tweet["public_metrics"]["reply_count"] = replies

        engagement = likes.to_i + retweets.to_i + replies.to_i
        tweet["engagement"] = engagement

        puts "[PARSE] Engagement metrics for tweet #{tweet_id}: likes=#{likes}, retweets=#{retweets}, replies=#{replies}, total=#{engagement}"
      end

      # Log some statistics
      if tweets.any?
        avg_engagement = tweets.sum { |t| t["engagement"] } / tweets.size.to_f
        max_engagement = tweets.map { |t| t["engagement"] }.max
        min_engagement = tweets.map { |t| t["engagement"] }.min

        puts "[PARSE] Engagement statistics: avg=#{avg_engagement.round(2)}, max=#{max_engagement}, min=#{min_engagement}"
      end

      tweets
    end

    # Get top tweets per account (1-2 per account based on engagement)
    def get_top_tweets_per_account(tweets, max_per_account = 2)
      puts "[PARSE] Grouping #{tweets.size} tweets by author..."

      tweets_by_author = tweets.group_by { |t| t["username"] }
      puts "[PARSE] Found tweets from #{tweets_by_author.size} unique authors"

      top_tweets = []
      tweets_by_author.each do |username, author_tweets|
        puts "[PARSE] Processing #{author_tweets.size} tweets from @#{username}"

        # Sort by engagement and take top max_per_account
        sorted_tweets = author_tweets.sort_by { |t| -t["engagement"] }

        # Log the engagement scores for this author's tweets
        engagement_scores = sorted_tweets.map { |t| t["engagement"] }
        puts "[PARSE] Engagement scores for @#{username}'s tweets: #{engagement_scores.join(', ')}"

        selected_tweets = sorted_tweets.take(max_per_account)
        puts "[PARSE] Selected #{selected_tweets.size} top tweets from @#{username} with engagement scores: #{selected_tweets.map { |t| t["engagement"] }.join(', ')}"

        top_tweets.concat(selected_tweets)
      end

      puts "[PARSE] Selected #{top_tweets.size} top tweets in total from #{tweets_by_author.size} authors"

      # Log some statistics about the selected tweets
      if top_tweets.any?
        avg_engagement = top_tweets.sum { |t| t["engagement"] } / top_tweets.size.to_f
        max_engagement = top_tweets.map { |t| t["engagement"] }.max
        min_engagement = top_tweets.map { |t| t["engagement"] }.min

        puts "[PARSE] Selected tweets engagement statistics: avg=#{avg_engagement.round(2)}, max=#{max_engagement}, min=#{min_engagement}"
      end

      puts "Selected #{top_tweets.size} top tweets."
      top_tweets
    end
  end
end
