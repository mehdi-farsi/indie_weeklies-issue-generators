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
    
    // The order is typically: replies, retweets, likes
    if (metricElements.length >= 3) {
      metrics.replies = await page.evaluate(el => parseInt(el.textContent.trim().replace(/,/g, '')) || 0, metricElements[0]);
      metrics.retweets = await page.evaluate(el => parseInt(el.textContent.trim().replace(/,/g, '')) || 0, metricElements[1]);
      metrics.likes = await page.evaluate(el => parseInt(el.textContent.trim().replace(/,/g, '')) || 0, metricElements[2]);
    }
    
    return metrics;
  } catch (error) {
    console.error(`Error extracting engagement metrics: ${error.message}`);
    return { likes: 0, retweets: 0, replies: 0 };
  }
}

// Extract follower count from a user's profile
async function extractFollowerCount(page) {
  try {
    // Wait for the followers element to load
    await page.waitForSelector('[href$="/followers"]', { timeout: 5000 });
    
    // Get the follower count
    const followerElement = await page.$('[href$="/followers"]');
    if (!followerElement) return 0;
    
    const followerText = await page.evaluate(el => el.textContent.trim(), followerElement);
    const followerCount = parseInt(followerText.replace(/,/g, '').match(/\d+/)[0]) || 0;
    
    return followerCount;
  } catch (error) {
    console.error(`Error extracting follower count: ${error.message}`);
    return 0;
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
    
    // Extract follower count
    const followerCount = await extractFollowerCount(page);
    console.log(`@${username} has ${followerCount} followers.`);
    
    // Wait for tweets to load
    await page.waitForSelector('article[data-testid="tweet"]', { timeout: 10000 });
    
    // Get all tweets
    const tweetElements = await page.$$('article[data-testid="tweet"]');
    console.log(`Found ${tweetElements.length} tweets on @${username}'s profile.`);
    
    const tweets = [];
    
    // Process each tweet
    for (let i = 0; i < Math.min(10, tweetElements.length); i++) {
      const tweetElement = tweetElements[i];
      
      try {
        // Extract tweet ID
        const tweetId = await page.evaluate(el => {
          const linkElement = el.querySelector('a[href*="/status/"]');
          if (!linkElement) return null;
          
          const href = linkElement.getAttribute('href');
          const match = href.match(/\/status\/(\d+)/);
          return match ? match[1] : null;
        }, tweetElement);
        
        if (!tweetId) continue;
        
        // Extract tweet text
        const tweetText = await page.evaluate(el => {
          const textElement = el.querySelector('[data-testid="tweetText"]');
          return textElement ? textElement.textContent.trim() : '';
        }, tweetElement);
        
        // Extract tweet date
        const tweetDate = await page.evaluate(el => {
          const timeElement = el.querySelector('time');
          return timeElement ? timeElement.getAttribute('datetime') : null;
        }, tweetElement);
        
        // Skip tweets older than a week
        if (!isTweetFromPastWeek(tweetDate)) {
          console.log(`Skipping tweet from @${username} (older than a week).`);
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
          author_followers_count: followerCount,
          likes: metrics.likes,
          retweets: metrics.retweets,
          replies: metrics.replies
        };
        
        tweets.push(tweet);
      } catch (error) {
        console.error(`Error processing tweet from @${username}: ${error.message}`);
      }
    }
    
    console.log(`Scraped ${tweets.length} recent tweets from @${username}.`);
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
  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  try {
    console.log(`Scraping tweets from ${usernames.length} Twitter accounts...`);
    
    const allTweets = [];
    
    // Process each username
    for (let i = 0; i < usernames.length; i++) {
      const username = usernames[i];
      console.log(`Processing ${i + 1}/${usernames.length}: @${username}`);
      
      const userTweets = await scrapeTweetsFromUser(browser, username);
      allTweets.push(...userTweets);
      
      // Add a small delay between users to avoid rate limiting
      if (i < usernames.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    // Write tweets to output file
    fs.writeFileSync(outputFile, JSON.stringify(allTweets, null, 2));
    console.log(`Scraped ${allTweets.length} tweets total. Saved to ${outputFile}`);
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