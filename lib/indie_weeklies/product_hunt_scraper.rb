# frozen_string_literal: true

require "nokogiri"
require "faraday"
require "date"

module IndieWeeklies
  class ProductHuntScraper
    BASE_URL = "https://www.producthunt.com"
    
    # Get the current week's leaderboard URL
    def get_leaderboard_url
      year = Date.today.year
      week = Date.today.cweek
      "#{BASE_URL}/leaderboard/weekly/#{year}/#{week}"
    end
    
    # Scrape the weekly leaderboard and return the top 10 products
    def scrape_top_products(limit = 10)
      url = get_leaderboard_url
      puts "Scraping Product Hunt leaderboard: #{url}"
      
      begin
        response = Faraday.get(url)
        
        if response.status != 200
          puts "Error fetching Product Hunt leaderboard: #{response.status}"
          return []
        end
        
        html = response.body
        doc = Nokogiri::HTML(html)
        
        products = []
        
        # Find product elements - this selector might need to be updated if PH changes their markup
        product_elements = doc.css('div[data-test="product-item"]')
        
        product_elements.each_with_index do |element, index|
          break if index >= limit
          
          begin
            # Extract product name and URL
            name_element = element.css('h3').first
            link_element = element.css('a[data-test="product-name-link"]').first
            
            next unless name_element && link_element
            
            name = name_element.text.strip
            path = link_element['href']
            url = "#{BASE_URL}#{path}"
            
            products << {
              name: name,
              url: url,
              rank: index + 1
            }
          rescue StandardError => e
            puts "Error parsing product element: #{e.message}"
          end
        end
        
        if products.empty?
          puts "Warning: No products found on the leaderboard. The page structure might have changed."
        elsif products.size < limit
          puts "Warning: Only found #{products.size} products, expected #{limit}."
        end
        
        products
      rescue StandardError => e
        puts "Error scraping Product Hunt: #{e.message}"
        []
      end
    end
  end
end