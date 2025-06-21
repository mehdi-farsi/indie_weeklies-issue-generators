# frozen_string_literal: true

require "erb"
require "date"
require "fileutils"

module IndieWeeklies
  class NewsletterComposer
    TEMPLATE_DIR = File.expand_path("../templates", __dir__)
    OUTPUT_DIR = File.expand_path("../../tmp", __dir__)

    def initialize
      FileUtils.mkdir_p(OUTPUT_DIR)
      FileUtils.mkdir_p(TEMPLATE_DIR)
      create_template_if_not_exists
    end

    # Generate the newsletter content
    def compose(tweets, products)
      week_number = Date.today.cweek
      year = Date.today.year

      # Generate a tagline based on the top tweet
      tagline = generate_tagline(tweets.first) if tweets.any?

      # Render the template
      template = File.read(File.join(TEMPLATE_DIR, "newsletter_template.erb"))
      renderer = ERB.new(template)
      content = renderer.result(binding)

      # Save to file
      output_file = File.join(OUTPUT_DIR, "indie-weeklies-#{year}-W#{week_number}.html")
      File.write(output_file, content)

      {
        title: "Indie Weeklies – Edition #{week_number}",
        tagline: tagline,
        content: content,
        file_path: output_file
      }
    end

    private

    # Generate a tagline based on the top tweet
    def generate_tagline(top_tweet)
      if top_tweet && top_tweet["summary"]
        "The one where #{top_tweet["summary"].downcase.sub(/\.$/, '')}"
      else
        "The one with this week's best indie hacking content"
      end
    end

    # Create the template file if it doesn't exist
    def create_template_if_not_exists
      template_path = File.join(TEMPLATE_DIR, "newsletter_template.erb")
      week_number = Date.today.cweek

      unless File.exist?(template_path)
        template_content = <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title><%= "Indie Weeklies – Edition #{week_number}" %></title>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
              }
              h1, h2, h3 {
                color: #111;
              }
              .tagline {
                font-size: 1.2em;
                font-style: italic;
                color: #555;
                margin-bottom: 30px;
              }
              .tweet {
                margin-bottom: 40px;
                border-bottom: 1px solid #eee;
                padding-bottom: 20px;
              }
              .tweet-summary {
                font-size: 1.1em;
                margin: 15px 0;
              }
              .tweet-image {
                max-width: 100%;
                border: 1px solid #ddd;
                border-radius: 8px;
              }
              .product-hunt {
                margin-top: 50px;
              }
              .product {
                margin-bottom: 15px;
              }
              .product-rank {
                display: inline-block;
                width: 25px;
                height: 25px;
                background-color: #da552f;
                color: white;
                text-align: center;
                border-radius: 50%;
                margin-right: 10px;
              }
              a {
                color: #da552f;
                text-decoration: none;
              }
              a:hover {
                text-decoration: underline;
              }
              footer {
                margin-top: 50px;
                font-size: 0.9em;
                color: #777;
                text-align: center;
              }
            </style>
          </head>
          <body>
            <h1><%= "Indie Weeklies – Edition #{week_number}" %></h1>

            <% if tagline %>
              <div class="tagline"><%= tagline %></div>
            <% end %>

            <h2>💡 Indie Hacks of the Week</h2>

            <% if tweets.any? %>
              <% tweets.each do |tweet| %>
                <div class="tweet">
                  <div class="tweet-summary">
                    <%= tweet["summary"] %>
                  </div>
                  <% if tweet["screenshot_path"] && File.exist?(tweet["screenshot_path"]) %>
                    <img class="tweet-image" src="<%= tweet["screenshot_path"] %>" alt="Tweet by <%= tweet.dig("author", "username") %>">
                  <% end %>
                </div>
              <% end %>
            <% else %>
              <p>No tweets found this week.</p>
            <% end %>

            <div class="product-hunt">
              <h2>🚀 Product Hunt Top 10</h2>

              <% if products.any? %>
                <% products.each do |product| %>
                  <div class="product">
                    <span class="product-rank"><%= product[:rank] %></span>
                    <a href="<%= product[:url] %>" target="_blank"><%= product[:name] %></a>
                  </div>
                <% end %>
              <% else %>
                <p>No Product Hunt items found this week.</p>
              <% end %>
            </div>

            <footer>
              <p>Indie Weeklies – Edition <%= week_number %> | <%= Date.today.strftime("%B %d, %Y") %></p>
            </footer>
          </body>
          </html>
        HTML

        FileUtils.mkdir_p(TEMPLATE_DIR)
        File.write(template_path, template_content)
      end
    end
  end
end
