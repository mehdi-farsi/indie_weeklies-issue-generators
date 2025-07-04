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
  console.log(`[PARSE] Reading tweets data from ${tweetsJsonFile}`);
  const tweetsData = fs.readFileSync(tweetsJsonFile, 'utf8');
  console.log(`[PARSE] File size: ${tweetsData.length} bytes`);

  tweets = JSON.parse(tweetsData);
  console.log(`[PARSE] Parsed ${tweets.length} tweets from JSON`);

  if (tweets.length > 0) {
    console.log(`[PARSE] Sample tweet (first in collection):`);
    console.log(`[PARSE] ${JSON.stringify(tweets[0], null, 2)}`);
  }
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
  console.log(`[PARSE] Starting screenshot process`);
  console.log(`[PARSE] Using Chrome executable: ${findChrome()}`);

  const startTime = new Date();
  console.log(`[PARSE] Start time: ${startTime.toISOString()}`);

  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  console.log(`[PARSE] Browser launched successfully`);

  try {
    console.log(`[PARSE] Taking screenshots of ${tweets.length} tweets...`);

    for (let i = 0; i < tweets.length; i++) {
      const tweet = tweets[i];
      const tweetStartTime = new Date();
      console.log(`[PARSE] Processing tweet ${i + 1}/${tweets.length}: ${tweet.id} (${((i/tweets.length)*100).toFixed(1)}% complete)`);
      console.log(`[PARSE] Tweet URL: ${tweet.url}`);

      const page = await browser.newPage();
      console.log(`[PARSE] New page created`);

      try {
        // Set viewport size
        await page.setViewport({ width: 600, height: 800 });
        console.log(`[PARSE] Viewport set to 600x800`);

        // Navigate to tweet
        console.log(`[PARSE] Navigating to tweet URL...`);
        await page.goto(tweet.url, { waitUntil: 'networkidle2', timeout: 30000 });
        console.log(`[PARSE] Navigation complete`);

        // Wait for any articles to load (more general selector)
        console.log(`[PARSE] Waiting for articles to load...`);
        await page.waitForSelector('article', { timeout: 10000 });
        console.log(`[PARSE] Articles loaded`);

        // Get all articles
        const articles = await page.$$('article');
        console.log(`[PARSE] Found ${articles.length} article elements on the page`);

        let tweetFound = false;

        // Check each article to see if it's a tweet
        console.log(`[PARSE] Checking each article to find the tweet...`);
        for (let j = 0; j < articles.length; j++) {
          const article = articles[j];
          console.log(`[PARSE] Checking article ${j + 1}/${articles.length}`);

          // Check if this article is a tweet by looking for tweet-specific elements
          const tweetElements = await page.evaluate(el => {
            const hasTweetText = el.querySelector('[data-testid="tweetText"]') !== null;
            const hasStatusLink = el.querySelector('a[href*="/status/"]') !== null;
            return { hasTweetText, hasStatusLink, isTweet: hasTweetText || hasStatusLink };
          }, article);

          console.log(`[PARSE] Article check: hasTweetText=${tweetElements.hasTweetText}, hasStatusLink=${tweetElements.hasStatusLink}`);

          if (tweetElements.isTweet) {
            console.log(`[PARSE] Found tweet element in article ${j + 1}`);

            // Take screenshot of just the tweet element
            const screenshotPath = path.join(outputDir, `${tweet.id}.png`);
            console.log(`[PARSE] Taking screenshot and saving to ${screenshotPath}...`);

            await article.screenshot({ path: screenshotPath });
            console.log(`[PARSE] Screenshot saved successfully`);

            // Get file size
            const stats = fs.statSync(screenshotPath);
            console.log(`[PARSE] Screenshot file size: ${stats.size} bytes`);

            tweetFound = true;
            break;
          }
        }

        if (!tweetFound) {
          console.error(`[PARSE] Could not find tweet element for ${tweet.id}`);
        }

        const tweetEndTime = new Date();
        const tweetDuration = (tweetEndTime - tweetStartTime) / 1000;
        console.log(`[PARSE] Finished processing tweet ${tweet.id} in ${tweetDuration.toFixed(1)} seconds`);
      } catch (error) {
        console.error(`[PARSE] Error processing tweet ${tweet.id}: ${error.message}`);
      } finally {
        await page.close();
        console.log(`[PARSE] Page closed`);
      }
    }

    const endTime = new Date();
    const totalDuration = (endTime - startTime) / 1000;
    console.log(`[PARSE] Total screenshot time: ${totalDuration.toFixed(1)} seconds`);
    console.log(`[PARSE] Average time per tweet: ${(totalDuration / tweets.length).toFixed(1)} seconds`);
  } finally {
    await browser.close();
    console.log(`[PARSE] Browser closed`);
  }
}

// Run the screenshot function
takeScreenshots()
  .then(() => {
    console.log('[PARSE] All screenshots completed successfully.');
    console.log('[PARSE] Summary:');
    console.log(`[PARSE] - Total tweets processed: ${tweets.length}`);
    console.log(`[PARSE] - Output directory: ${outputDir}`);

    // Count successful screenshots
    const screenshotFiles = fs.readdirSync(outputDir).filter(file => file.endsWith('.png'));
    console.log(`[PARSE] - Screenshots created: ${screenshotFiles.length}/${tweets.length}`);

    // Calculate total size of screenshots
    const totalSize = screenshotFiles.reduce((total, file) => {
      const stats = fs.statSync(path.join(outputDir, file));
      return total + stats.size;
    }, 0);
    console.log(`[PARSE] - Total size of screenshots: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);

    console.log('All screenshots completed.');
  })
  .catch(error => {
    console.error(`[PARSE] Fatal error in screenshot process: ${error.message}`);
    console.error(`[PARSE] Stack trace: ${error.stack}`);
    process.exit(1);
  });
