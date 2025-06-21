/**
 * Screenshot Tweets using Puppeteer
 * 
 * Usage: node screenshot_tweets.js <tweets_json_file> <output_directory>
 * 
 * The tweets JSON file should contain an array of objects with the following structure:
 * [
 *   {
 *     "id": "tweet_id",
 *     "url": "tweet_url"
 *   }
 * ]
 */

const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

// Get command line arguments
const tweetsJsonFile = process.argv[2];
const outputDir = process.argv[3];

if (!tweetsJsonFile || !outputDir) {
  console.error('Usage: node screenshot_tweets.js <tweets_json_file> <output_directory>');
  process.exit(1);
}

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Read tweets data
let tweets;
try {
  const tweetsData = fs.readFileSync(tweetsJsonFile, 'utf8');
  tweets = JSON.parse(tweetsData);
} catch (error) {
  console.error(`Error reading tweets file: ${error.message}`);
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

// Take screenshots of tweets
async function takeScreenshots() {
  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    console.log(`Taking screenshots of ${tweets.length} tweets...`);
    
    for (let i = 0; i < tweets.length; i++) {
      const tweet = tweets[i];
      console.log(`Processing tweet ${i + 1}/${tweets.length}: ${tweet.id}`);
      
      const page = await browser.newPage();
      
      try {
        // Set viewport size
        await page.setViewport({ width: 600, height: 800 });
        
        // Navigate to tweet
        await page.goto(tweet.url, { waitUntil: 'networkidle2', timeout: 30000 });
        
        // Wait for tweet to load
        await page.waitForSelector('article[data-testid="tweet"]', { timeout: 10000 });
        
        // Get the tweet element
        const tweetElement = await page.$('article[data-testid="tweet"]');
        
        if (tweetElement) {
          // Take screenshot of just the tweet element
          const screenshotPath = path.join(outputDir, `${tweet.id}.png`);
          await tweetElement.screenshot({ path: screenshotPath });
          console.log(`Screenshot saved to ${screenshotPath}`);
        } else {
          console.error(`Could not find tweet element for ${tweet.id}`);
        }
      } catch (error) {
        console.error(`Error processing tweet ${tweet.id}: ${error.message}`);
      } finally {
        await page.close();
      }
    }
  } finally {
    await browser.close();
  }
}

// Run the screenshot function
takeScreenshots()
  .then(() => {
    console.log('All screenshots completed.');
  })
  .catch(error => {
    console.error(`Error taking screenshots: ${error.message}`);
    process.exit(1);
  });