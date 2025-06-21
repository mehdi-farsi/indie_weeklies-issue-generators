# frozen_string_literal: true

require "faraday"
require "json"
require "yaml"

module IndieWeeklies
  class BeehiivUploader
    BEEHIIV_API_URL = "https://api.beehiiv.com/v2"
    LAST_EDITION_FILE = File.expand_path("../../tmp/last_edition.yml", __dir__)
    
    def initialize
      @api_key = ENV.fetch("BEEHIIV_API_KEY")
      @publication_id = ENV.fetch("BEEHIIV_PUBLICATION_ID")
      @connection = Faraday.new(url: BEEHIIV_API_URL) do |conn|
        conn.headers["Authorization"] = "Bearer #{@api_key}"
        conn.headers["Content-Type"] = "application/json"
      end
    end
    
    # Upload newsletter to Beehiiv as a draft
    def upload(newsletter_data)
      # Check if we've already created this edition
      week_number = Date.today.cweek
      year = Date.today.year
      edition_key = "#{year}-W#{week_number}"
      
      if already_published?(edition_key)
        puts "Warning: Edition #{edition_key} has already been published. Skipping upload."
        return nil
      end
      
      # Prepare the payload
      payload = {
        publication_id: @publication_id,
        title: newsletter_data[:title],
        subtitle: newsletter_data[:tagline],
        content: newsletter_data[:content],
        status: "draft"
      }
      
      # Upload to Beehiiv
      response = post_with_retries("posts", payload)
      
      if response && response["data"] && response["data"]["id"]
        post_id = response["data"]["id"]
        preview_url = "https://app.beehiiv.com/posts/#{post_id}"
        
        # Save this edition as published
        mark_as_published(edition_key)
        
        puts "Newsletter draft created successfully!"
        puts "Preview URL: #{preview_url}"
        
        {
          post_id: post_id,
          preview_url: preview_url
        }
      else
        puts "Failed to create newsletter draft."
        nil
      end
    end
    
    private
    
    # Check if an edition has already been published
    def already_published?(edition_key)
      return false unless File.exist?(LAST_EDITION_FILE)
      
      begin
        data = YAML.load_file(LAST_EDITION_FILE) || {}
        data["editions"] && data["editions"].include?(edition_key)
      rescue StandardError => e
        puts "Error checking publication history: #{e.message}"
        false
      end
    end
    
    # Mark an edition as published
    def mark_as_published(edition_key)
      begin
        data = File.exist?(LAST_EDITION_FILE) ? YAML.load_file(LAST_EDITION_FILE) || {} : {}
        data["editions"] ||= []
        data["editions"] << edition_key
        
        FileUtils.mkdir_p(File.dirname(LAST_EDITION_FILE))
        File.write(LAST_EDITION_FILE, data.to_yaml)
      rescue StandardError => e
        puts "Error updating publication history: #{e.message}"
      end
    end
    
    # Post to Beehiiv API with retries
    def post_with_retries(endpoint, payload, max_retries = 3)
      retries = 0
      
      begin
        response = @connection.post(endpoint) do |req|
          req.body = payload.to_json
        end
        
        if response.status == 429 # Rate limited
          retry_after = response.headers["retry-after"].to_i || 60
          puts "Rate limited by Beehiiv. Waiting for #{retry_after} seconds..."
          sleep retry_after
          raise "Rate limited"
        end
        
        if response.status != 200 && response.status != 201
          puts "Error from Beehiiv API: #{response.status} - #{response.body}"
          return nil
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
          nil
        end
      end
    end
  end
end