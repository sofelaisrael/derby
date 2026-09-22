const { chromium } = require('playwright-core');

(async () => {
  const browser = await chromium.launch({
    executablePath: 'C:\\Users\\PROGRE~1\\.agent-browser\\browsers\\chrome-153.0.8010.52\\chrome.exe',
    headless: true,
    args: ['--disable-blink-features=AutomationControlled'],
  });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
  });
  const page = await context.newPage();

  const apiCalls = [];
  page.on('response', async res => {
    const u = res.url();
    if (u.includes('apibroker') && (u.includes('runLookup') || u.includes('form'))) {
      try {
        const body = await res.text();
        console.log('\n=== API RESPONSE ===');
        console.log('URL:', u);
        console.log('Body:', body.substring(0, 3000));
      } catch (e) {}
    }
  });

  console.log('Loading page with real user agent...');
  await page.goto('https://myselfservice.ne-derbyshire.gov.uk/service/Check_your_Bin_Day', { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(5000);
  
  const frames = page.frames();
  console.log('Frames:', frames.length);
  for (const f of frames) {
    console.log('  -', f.url().substring(0, 120));
  }
  
  const fillFrame = frames.find(f => f.url().includes('fillform'));
  if (fillFrame) {
    console.log('\nFOUND FILLFORM!');
    await fillFrame.waitForSelector('input[name="postcode_search"]', { timeout: 15000 });
    console.log('Typing postcode...');
    await fillFrame.fill('input[name="postcode_search"]', 'DE1 2QH');
    
    // Trigger keyup event
    await fillFrame.evaluate(() => {
      const input = document.querySelector('input[name="postcode_search"]');
      if (input) {
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        for (let i = 0; i < 5; i++) {
          input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
        }
      }
    });
    
    console.log('Waiting for results...');
    await page.waitForTimeout(10000);
    
    const options = await fillFrame.evaluate(() => {
      const sel = document.querySelector('select[name="selAddress"]');
      if (!sel) return 'No select found';
      return Array.from(sel.options).map(o => ({ value: o.value, text: o.text }));
    });
    console.log('\nOPTIONS:', JSON.stringify(options, null, 2));
  } else {
    console.log('No fillform frame found');
    // Check for errors in console
    const html = await page.content();
    const iframeMatch = html.match(/iframe[^>]*src="([^"]*)"/gi);
    console.log('Iframe src in HTML:', iframeMatch);
  }

  await browser.close();
})();
