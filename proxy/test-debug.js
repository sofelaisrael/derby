const { httpGet, httpPost, cookieJarFrom, cookieHeader } = require('./lib/drivers/shared');

(async () => {
  const pageRes = await httpGet('https://secure.derby.gov.uk/binday');
  console.log('Page status:', pageRes.status);
  const hasToken = /name="__RequestVerificationToken"/.test(pageRes.body);
  console.log('Has token:', hasToken);
  const tokenMatch = pageRes.body.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/i);
  if (tokenMatch) console.log('Token prefix:', tokenMatch[1].substring(0, 30));
  else console.log('NO TOKEN FOUND');

  const jar = cookieJarFrom(pageRes.headers);
  console.log('Cookies:', Object.keys(jar).length);
  const cookies = cookieHeader(jar);

  const body = 'Postcode=' + encodeURIComponent('DE11AA') + '&__RequestVerificationToken=' + encodeURIComponent(tokenMatch ? tokenMatch[1] : '');
  const result = await httpPost('https://secure.derby.gov.uk/binday', body, { 'Cookie': cookies });
  console.log('POST status:', result.status);
  console.log('Has select:', result.body.includes('SelectedUprn'));
  console.log('Body length:', result.body.length);
  if (result.body.length > 0) console.log('Snippet:', result.body.substring(0, 500));
})();
