# Architecture Decisions

This document outlines the key architectural decisions made during the development of the Indie Weeklies Issue Generator.

## Overall Architecture

The application follows a modular design with each component responsible for a specific part of the workflow:

1. **TwitterScraper**: Scrapes tweets from Twitter without using the API
2. **TweetRanker**: Implements the ranking algorithm
3. **TweetSummarizer**: Handles OpenAI interactions for summarization
4. **ScreenshotGenerator**: Manages Puppeteer for screenshots
5. **ProductHuntScraper**: Scrapes Product Hunt leaderboard
6. **NewsletterComposer**: Generates the newsletter content, including the indie hacking glossary with shareable entries
7. **BeehiivUploader**: Uploads to Beehiiv API

This modular approach allows for easier testing, maintenance, and future enhancements.

## Key Decisions

### 1. Language and Framework Choices

- **Ruby**: Used for the main application due to its readability and suitability for scripting tasks.
- **Thor**: Used for the CLI interface due to its simplicity and built-in help generation.
- **Zeitwerk**: Used for code autoloading to avoid manual requires.
- **Node.js/Puppeteer**: Used for both Twitter scraping and screenshot functionality, providing a reliable way to interact with Twitter's web interface without using their API.
- **Nokogiri**: Used for HTML parsing, particularly for extracting usernames from the following.html file.

### 2. Twitter Data Collection

- We parse the following.html file to extract Twitter usernames.
- We use Puppeteer to visit each user's Twitter profile page.
- For each profile, we scrape up to 10 tweets from the past 7 days.
- We extract engagement metrics (likes, retweets, replies) and follower counts directly from the page.
- We calculate engagement as: likes + reposts + replies.
- We keep the top 1-2 tweets per account based on engagement.

### 3. Ranking Algorithm

- Composite score = engagement × 0.4 + author_followers × 0.6
- This balances the importance of the tweet's popularity with the author's influence.
- Tweets are sorted by this score in descending order.

### 4. Tweet Summarization

- We use OpenAI's Chat API to generate concise, plain-language summaries.
- The prompt explicitly requests 1-2 sentences without hashtags or emojis.
- We implement retry logic with exponential backoff for API failures.

### 5. Screenshot Generation

- We use Puppeteer through a Node.js script for reliable screenshots.
- The script is designed to work across platforms (macOS, Windows, Linux).
- We capture only the tweet element, not the entire page, for cleaner results.

### 6. Product Hunt Scraping

- We scrape the current week's leaderboard using Nokogiri.
- We extract the top 10 products with their names and URLs.
- We implement error handling for markup changes.

### 7. Newsletter Composition

- We use ERB templates for generating the HTML content.
- The template is stored in the lib/templates directory and created if it doesn't exist.
- We generate a tagline based on the top tweet's summary.
- We include a glossary of indie hacking terms with shareable entries.

### 8. Glossary Feature

- We maintain a curated list of 10 common indie hacking terms and their definitions.
- Each glossary entry has a unique ID that serves as an HTML anchor.
- We provide a "Share on X" button for each entry that generates a pre-populated tweet.
- The share URL includes an anchor that directs viewers to the specific glossary entry.
- We use Twitter's Web Intent API for sharing, which opens a new window with a pre-populated tweet.

### 9. Beehiiv Upload

- We upload the newsletter as a draft to Beehiiv.
- We store a record of published editions in a YAML file to avoid duplicates.
- We implement retry logic with respect for rate limiting.

## Edge Case Handling

### Missing/Removed Tweets
If a tweet is deleted or otherwise unavailable, we skip it and log the issue rather than failing the entire process.

### Product Hunt Markup Changes
We implement robust error handling in the scraper to handle potential markup changes. If the scraper fails to find products, it logs a warning and continues with an empty list.

### Beehiiv Rate Limiting
We respect the Retry-After header when encountering rate limits and implement exponential backoff for other errors.

### Duplicate Editions
We store a record of published editions and check this before uploading to avoid creating duplicate drafts if the script is run multiple times in the same week.

## Performance Considerations

- The application is designed to complete within 3 minutes on normal broadband.
- We limit the number of tweets scraped per user to improve performance.
- We add small delays between scraping user profiles to avoid rate limiting.
- We use headless Chrome to minimize resource usage during scraping.

## Future Enhancements

Potential areas for future improvement:

1. Add support for more social media platforms beyond Twitter.
2. Implement caching of scraped tweets to reduce scraping time on subsequent runs.
3. Add more customization options for the newsletter template.
4. Implement a web interface for previewing and editing before publishing.
5. Add analytics tracking for newsletter performance.
6. Improve error handling for Twitter's changing page structure.
7. Expand the glossary with more terms and allow users to contribute new entries.
8. Add analytics to track which glossary entries are shared most frequently.
