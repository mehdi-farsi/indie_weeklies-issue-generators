# Indie Weeklies Issue Generator

A local-first CLI tool that creates and uploads a Beehiiv draft containing the past week's best indie-hacking content from X/Twitter plus the weekly Product Hunt top-10.

## Features

- Scrapes tweets from accounts you follow on Twitter (no API needed)
- Ranks tweets by engagement and follower count
- Summarizes tweets using OpenAI
- Takes screenshots of tweets using Puppeteer
- Scrapes the Product Hunt weekly leaderboard
- Composes a newsletter with the content
- Uploads the newsletter as a draft to Beehiiv
- Saves a local HTML backup

## Requirements

- Ruby 3.4.x
- Node.js 20+
- Google Chrome (for Puppeteer screenshots and Twitter scraping)
- OpenAI API access
- Beehiiv API access
- Twitter following list saved as HTML in db/following.html

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/indie-weeklies.git
   cd indie-weeklies
   ```

2. Install Ruby dependencies:
   ```
   bundle install
   ```

3. Install Node.js dependencies:
   ```
   npm install
   ```

4. Create a `.env` file with your API keys (see `.env.example` for required variables):
   ```
   cp .env.example .env
   ```

5. Edit the `.env` file with your API keys:
   ```
   OPENAI_API_KEY=your_openai_api_key
   BEEHIIV_API_KEY=your_beehiiv_api_key
   BEEHIIV_PUBLICATION_ID=your_beehiiv_publication_id
   ```

6. Make the CLI script executable:
   ```
   chmod +x bin/generate_issue_of_the_current_week
   ```

## Usage

Run the CLI tool to generate and upload a newsletter:

```
bin/generate_issue_of_the_current_week
```

The tool will:
1. Collect tweets from accounts you follow
2. Rank them by engagement and follower count
3. Summarize them with OpenAI
4. Take screenshots of the tweets
5. Scrape the Product Hunt weekly leaderboard
6. Compose a newsletter with the content
7. Upload the newsletter as a draft to Beehiiv
8. Save a local HTML backup in the `tmp` directory

## Testing

Run the tests with:

```
bundle exec rspec
```

## Architecture

The project is organized into several components:

- `TwitterScraper`: Scrapes tweets from Twitter without using the API
- `TweetRanker`: Ranks tweets by engagement and follower count
- `TweetSummarizer`: Summarizes tweets using OpenAI
- `ScreenshotGenerator`: Takes screenshots of tweets using Puppeteer
- `ProductHuntScraper`: Scrapes the Product Hunt weekly leaderboard
- `NewsletterComposer`: Composes the newsletter content
- `BeehiivUploader`: Uploads the newsletter to Beehiiv

See `docs/decisions.md` for more details on the architecture and design decisions.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
