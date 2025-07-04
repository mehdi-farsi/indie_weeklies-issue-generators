/**
 * Scrape Tweets using Puppeteer
 * 
 * Usage: node scrape_tweets.js <usernames_json_file> <output_file>
 * 
 * The usernames JSON file should contain an array of Twitter usernames:
 * ["username1", "username2", ...]
 */

const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

// Get command line arguments
const usernamesJsonFile = process.argv[2];
const outputFile = process.argv[3];

if (!usernamesJsonFile || !outputFile) {
  console.error('Usage: node scrape_tweets.js <usernames_json_file> <output_file>');
  process.exit(1);
}

// Read usernames data
let usernames;
try {
  const usernamesData = fs.readFileSync(usernamesJsonFile, 'utf8');
  usernames = JSON.parse(usernamesData);
} catch (error) {
  console.error(`Error reading usernames file: ${error.message}`);
  process.exit(1);
}

// Find Chrome executable based on platform
function findChrome() {
  const platform = process.platform;

  if (platform === 'darwin') { // macOS
    return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  } else if (platform === 'win32') { // Windows
    return 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  } else if (platform === 'linux') { // Linux
    return '/usr/bin/google-chrome';
  } else {
    throw new Error(`Unsupported platform: ${platform}`);
  }
}

// Get date from 7 days ago
function getOneWeekAgo() {
  const date = new Date();
  date.setDate(date.getDate() - 7);
  return date;
}

// Check if a tweet is from the past week
function isTweetFromPastWeek(tweetDateStr) {
  if (!tweetDateStr) return false;

  try {
    const tweetDate = new Date(tweetDateStr);
    const oneWeekAgo = getOneWeekAgo();
    return tweetDate >= oneWeekAgo;
  } catch (error) {
    console.error(`Error parsing date: ${error.message}`);
    return false;
  }
}

// Extract engagement metrics from a tweet
async function extractEngagementMetrics(page, tweetElement) {
  try {
    // Look for like, retweet, and reply counts
    const metrics = {
      likes: 0,
      retweets: 0,
      replies: 0
    };

    // Get all the metric elements
    const metricElements = await tweetElement.$$('[data-testid="app-text-transition-container"]');
    console.log(`[PARSE] Found ${metricElements.length} metric elements`);

    // The order is typically: replies, retweets, likes
    if (metricElements.length >= 3) {
      metrics.replies = await page.evaluate(el => parseInt(el.textContent.trim().replace(/,/g, '')) || 0, metricElements[0]);
      metrics.retweets = await page.evaluate(el => parseInt(el.textContent.trim().replace(/,/g, '')) || 0, metricElements[1]);
      metrics.likes = await page.evaluate(el => parseInt(el.textContent.trim().replace(/,/g, '')) || 0, metricElements[2]);
      console.log(`[PARSE] Extracted engagement metrics: ${JSON.stringify(metrics)}`);
    } else {
      console.log(`[PARSE] Not enough metric elements to extract engagement metrics`);
    }

    return metrics;
  } catch (error) {
    console.error(`Error extracting engagement metrics: ${error.message}`);
    return { likes: 0, retweets: 0, replies: 0 };
  }
}


// Scrape tweets from a user's profile
async function scrapeTweetsFromUser(browser, username) {
  console.log(`Scraping tweets from @${username}...`);
  const page = await browser.newPage();

  try {
    // Set viewport size
    await page.setViewport({ width: 1280, height: 800 });

    // Navigate to user's profile
    await page.goto(`https://twitter.com/${username}`, { waitUntil: 'networkidle2', timeout: 30000 });
    console.log(`[PARSE] Navigated to @${username}'s profile`);

    // Wait for any articles to load (more general selector)
    console.log(`[PARSE] Waiting for articles to load...`);

    const tweets = []; // Define tweets array outside try block

    try {
      await page.waitForSelector('article', { timeout: 20000 });

      // Get all article elements
      const articleElements = await page.$$('article');
      console.log(`[PARSE] Found ${articleElements.length} article elements on the page`);

      // Filter to only include tweet articles
      const tweetElements = [];
      for (const article of articleElements) {
        // Check if this article is a tweet by looking for tweet-specific elements
        const isTweet = await page.evaluate(el => {
          // Check for common tweet elements
          const hasTweetText = el.querySelector('[data-testid="tweetText"]') !== null;
          const hasStatusLink = el.querySelector('a[href*="/status/"]') !== null;
          return { hasTweetText, hasStatusLink, isTweet: hasTweetText || hasStatusLink };
        }, article);

        console.log(`[PARSE] Article element check: hasTweetText=${isTweet.hasTweetText}, hasStatusLink=${isTweet.hasStatusLink}`);

        if (isTweet.isTweet) {
          tweetElements.push(article);
        }
      }
      console.log(`[PARSE] Found ${tweetElements.length} tweets on @${username}'s profile.`);

      // Process each tweet
      for (let i = 0; i < Math.min(10, tweetElements.length); i++) {
        const tweetElement = tweetElements[i];
        console.log(`[PARSE] Processing tweet ${i + 1}/${Math.min(10, tweetElements.length)}`);

        try {
          // Extract tweet ID
          const tweetId = await page.evaluate(el => {
            const linkElement = el.querySelector('a[href*="/status/"]');
            if (!linkElement) return null;

            const href = linkElement.getAttribute('href');
            const match = href.match(/\/status\/(\d+)/);
            return match ? match[1] : null;
          }, tweetElement);

          if (!tweetId) {
            console.log(`[PARSE] Could not extract tweet ID, skipping`);
            continue;
          }
          console.log(`[PARSE] Extracted tweet ID: ${tweetId}`);

          // Extract tweet text
          const tweetText = await page.evaluate(el => {
            const textElement = el.querySelector('[data-testid="tweetText"]');
            return textElement ? textElement.textContent.trim() : '';
          }, tweetElement);
          console.log(`[PARSE] Extracted tweet text: "${tweetText.substring(0, 50)}${tweetText.length > 50 ? '...' : ''}"`);

          // Extract tweet date
          const tweetDate = await page.evaluate(el => {
            const timeElement = el.querySelector('time');
            return timeElement ? timeElement.getAttribute('datetime') : null;
          }, tweetElement);
          console.log(`[PARSE] Extracted tweet date: ${tweetDate}`);

          // Skip tweets older than a week
          if (!isTweetFromPastWeek(tweetDate)) {
            console.log(`[PARSE] Skipping tweet from @${username} (older than a week).`);
            continue;
          }

          // Extract engagement metrics
          const metrics = await extractEngagementMetrics(page, tweetElement);

          // Create tweet object
          const tweet = {
            id: tweetId,
            text: tweetText,
            created_at: tweetDate,
            username: username,
            likes: metrics.likes,
            retweets: metrics.retweets,
            replies: metrics.replies
          };

          console.log(`[PARSE] Created tweet object: ${JSON.stringify(tweet, null, 2)}`);
          tweets.push(tweet);
        } catch (error) {
          console.error(`[PARSE] Error processing tweet from @${username}: ${error.message}`);
        }
      }
    } catch (error) {
      console.log(`[PARSE] No articles found on the page: ${error.message}`);
      console.log(`[PARSE] Continuing without articles, will try to find tweets another way`);
      // No need to return here, we'll return the empty tweets array at the end
    }

    console.log(`[PARSE] Scraped ${tweets.length} recent tweets from @${username}.`);
    return tweets;
  } catch (error) {
    console.error(`Error scraping tweets from @${username}: ${error.message}`);
    return [];
  } finally {
    await page.close();
  }
}

// Main function to scrape tweets from all users
async function scrapeTweets() {
  console.log(`[PARSE] Starting tweet scraping process`);
  console.log(`[PARSE] Using Chrome executable: ${findChrome()}`);

  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  console.log(`[PARSE] Browser launched successfully`);

  try {
    console.log(`[PARSE] Scraping tweets from ${usernames.length} Twitter accounts...`);
    console.log(`[PARSE] Usernames to process: ${usernames.join(', ')}`);

    const allTweets = [];
    const startTime = new Date();
    console.log(`[PARSE] Start time: ${startTime.toISOString()}`);

    // Process each username
    for (let i = 0; i < usernames.length; i++) {
      const username = usernames[i];
      const userStartTime = new Date();
      console.log(`[PARSE] Processing ${i + 1}/${usernames.length}: @${username} (${((i/usernames.length)*100).toFixed(1)}% complete)`);

      const userTweets = await scrapeTweetsFromUser(browser, username);
      allTweets.push(...userTweets);

      const userEndTime = new Date();
      const userDuration = (userEndTime - userStartTime) / 1000;
      console.log(`[PARSE] Finished processing @${username} in ${userDuration.toFixed(1)} seconds`);
      console.log(`[PARSE] Collected ${userTweets.length} tweets from @${username}`);
      console.log(`[PARSE] Running total: ${allTweets.length} tweets from ${i + 1} users`);

      // Add a small delay between users to avoid rate limiting
      if (i < usernames.length - 1) {
        console.log(`[PARSE] Adding delay before next user...`);
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }

    const endTime = new Date();
    const totalDuration = (endTime - startTime) / 1000;
    console.log(`[PARSE] Total scraping time: ${totalDuration.toFixed(1)} seconds`);
    console.log(`[PARSE] Average time per user: ${(totalDuration / usernames.length).toFixed(1)} seconds`);

    // Write tweets to output file
    console.log(`[PARSE] Writing ${allTweets.length} tweets to output file: ${outputFile}`);
    fs.writeFileSync(outputFile, JSON.stringify(allTweets, null, 2));
    console.log(`[PARSE] File write complete. Scraped ${allTweets.length} tweets total.`);

    // Log a sample tweet for verification
    if (allTweets.length > 0) {
      console.log(`[PARSE] Sample tweet (first in collection):`);
      console.log(JSON.stringify(allTweets[0], null, 2));
    }
  } finally {
    await browser.close();
  }
}

// Run the scraping function
scrapeTweets()
  .then(() => {
    console.log('Tweet scraping completed.');
  })
  .catch(error => {
    console.error(`Error scraping tweets: ${error.message}`);
    process.exit(1);
  });
