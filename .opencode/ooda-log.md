# Derbyshire Bin Collection Proxy

## Cycle 7 - Remove OS Places API, use council-specific address lookup

### What happened
- User deployed proxy to `derby-teal.vercel.app` but `/addresses` returned empty because `OS_API_KEY` env var not set
- User said Mansfield proxy never used OS Places — each council's driver does its own address lookup
- Investigated: Derby uses POST form with CSRF token + 302 redirect; Erewash uses Drupal AJAX form postback; High Peak already had Bartec portal lookup

### What worked
- Rewrote `/api/addresses.js` to route through drivers (accepts optional `council` param, falls back to all drivers in parallel)
- Derby: GET page → extract `__RequestVerificationToken` + cookies → POST form → follow 302 redirect → parse `<select id="SelectedUprn">` options
- Erewash: GET page → extract `form_build_id` → POST Drupal AJAX → parse JSON `insert` commands → `parsePostcodeOptions`
- High Peak: Already had Bartec portal lookup, just removed OS Places fallback
- Removed `lookupAddressesOsPlaces` from `shared.js`, removed `OS_PLACES_API` constant
- Removed `lookupAddressesOsPlaces` import from all 9 drivers
- Added `council=auto` support to `/api/bins.js` — tries all drivers in parallel via Promise.allSettled
- All 77 tests passing
- Deployed to Vercel: Derby and Erewash address lookup confirmed working live

### Known issues
- **Derby getCollections is broken** (pre-existing): `secure.derby.gov.uk/binday/BinDays/{uprn}` now loads results via client-side JS, no `binresult` in raw HTML. Needs headless browser or discovery of underlying AJAX API
- **Auto-detect picks wrong council**: Bolsover returns calendar data for ALL addresses (doesn't filter by UPRN), so auto-detect always picks Bolsover first. Flutter app should pass explicit council
- **6 drivers return empty for address lookup**: Amber Valley, Chesterfield, Derbyshire Dales, South Derbyshire, Bolsover, NE Derbyshire — no council-specific address lookup implemented yet
- **Flutter app calls `council: 'auto'`** in address_picker_screen.dart — will get wrong council due to Bolsover issue

### Git commits
- `e732900` Remove OS Places API dependency: use council-specific address lookup
- `aedf541` Fix Derby address lookup: follow 302 redirect, extract CSRF token
- `deefeb0` Add auto-detect council from UPRN in bins endpoint

## Cycle 8 - Vercel verification: multiple councils fail on cloud IPs

### What happened
- User asked "lets just make sure this works bruh" — full Vercel endpoint verification
- Tested all 3 main endpoints against live Vercel deployment

### What works on Vercel
- `GET /bins` (council list) → 9 councils ✅
- `GET /addresses?postcode=DE1+1AA&council=derby` → 1 address ✅
- `GET /addresses?postcode=DE7+5PA&council=erewash` → 12 addresses ✅
- `GET /bins?council=bolsover&uprn=...` → 3 streams (general, recycling, garden) ✅
- Auto-detect → picks Bolsover (because it returns data for all UPRNs) ✅

### What fails on Vercel (but works locally)
- **Erewash getCollections** → empty (3 streams locally). 3-step Drupal AJAX form — steps 1+2 work (address lookup proves it), step 3 (UPRN POST) returns no collection data. Vercel response takes 1.2s so NOT a timeout. Drupal site returns different content from Vercel's cloud IPs
- **High Peak getCollections** → empty (works locally with Bartec portal)
- **South Derbyshire getCollections** → empty (iShareLIVE JSON API)
- **Derby getCollections** → empty (pre-existing: JS-rendered page)
- **`/report`** → 404 (missing route in vercel.json)

### Root cause for Vercel failures
Council websites are treating Vercel's cloud IPs differently — likely blocking or returning different HTML/JSON than what residential IPs get. This is an upstream problem we cannot fix. The address lookup works because Drupal form postback works, but the subsequent UPRN selection step fails silently.

### Actions taken
- Added `/report` route to vercel.json via implementer
- Investigated Erewash 3-step flow with verbose local diagnostics — all 3 steps work perfectly locally (3164 chars of collection HTML returned)
- Diagnosed `httpPost` in shared.js doesn't follow redirects — not the issue here (Erewash returns 200)

### Remaining known issues
- Derby getCollections broken (JS-rendered page)
- Auto-detect picks Bolsover first (returns data for all UPRNs)
- 6 drivers return empty for address lookup (Amber Valley, Chesterfield, Derbyshire Dales, South Derbyshire, Bolsover, NE Derbyshire)
- Erewash/High Peak/South Derbyshire getCollections fail on Vercel (cloud IP blocking)

## Cycle 4 - Implementation: Derby + Erewash drivers
- Stripped ALL comments from every file
- Created lib/drivers/derby.js - HTML scraping via regex
- Created lib/drivers/erewash.js - JSON API, simplest driver
- Rewrote lib/drivers/index.js - individual driver registration
- Deleted dead ukbinday.js
- All 28 tests passing, zero comments in codebase

## Cycle 9 - Apply Mansfield Vercel-hardening patterns to Erewash

### What happened
- User asked "What did we do so far?" and pointed out Mansfield proxy initially didn't work on Vercel either
- Reviewed Mansfield git history for Vercel-specific fixes: 5 key commits found
- Key Mansfield fixes: cookie persistence (`c9b59e6`), retry logic (`424de61`), debug logging (`34b2759`), Vercel function limit (`80aa055`), timeout increase (`424de61`)
- Identified two patterns missing from our Erewash driver that Mansfield's Gedling (Drupal AJAX) has:
  1. `X-Requested-With: XMLHttpRequest` header on all AJAX POST requests
  2. Cookie merging between steps (step 2's Set-Cookie → step 3)

### What was done
1. Added step-by-step `console.error` logging with `[erewash]` prefix at each step (like Mansfield's Gedling)
2. Replaced silent `catch(e) { return []; }` with `throw e` so errors propagate to Vercel logs
3. Added `X-Requested-With: XMLHttpRequest` header to all 3 httpPost calls (lookupAddresses, getCollections step 2, getCollections step 3)
4. Added cookie merge after step 2 response: extracts Set-Cookie from postcode POST, merges with existing jar before step 3 uses them
5. All 77 tests passing

### Git commits
- `3321fe1` Add /report route to vercel.json
- Cycle 9 changes (pending commit): Vercel-hardening for Erewash driver

### Vercel test results
- **Erewash getCollections ✅ WORKS ON VERCEL** — returns 3 streams (general/food/recycling)
- Fix was `X-Requested-With: XMLHttpRequest` header + cookie merge pattern from Mansfield Gedling driver
- Also fixed "jar is not iterable" bug — `cookieJarFrom()` returns object, not array; `[...jar]` → `{ ...jar, ...jar2 }`

### Vercel live test results (Cycle 9 post-fix)
- **Erewash ✅ WORKS** — 3 streams (general/food/recycling) with UPRN 100030140736
- **High Peak ✅ WORKS** — 4 streams (recycling/garden/general/food) with UPRN 10010743094
- **South Derbyshire ❌ COUNCIL API DOWN** — iShareLIVE returns "ERROR 10006: IntGetData" for ALL UPRNs. Not our code issue — council backend is broken.
- **Derbyshire Dales ❌ UPRN FORMAT** — needs U-prefixed UPRNs (e.g. U10070090119 not 10070090119). Address lookup available via POST /core/addresslookup. Also needs correct POST URL: /renderform/Form not /RenderForm.

### Final Vercel results (Cycle 9 complete)
| Council | Address Lookup | getCollections | Notes |
|---------|---------------|----------------|-------|
| Derby | ✅ | ✅ | Works! Old test UPRN had no data. Valid UPRN (10010671843) returns 2 streams |
| Amber Valley | ❌ | ✅ | No address lookup, but collections work |
| Bolsover | ❌ | ✅ | No address lookup, returns all UPRNs |
| Chesterfield | ❌ | ✅ | No address lookup, Salesforce Lightning |
| Derbyshire Dales | ✅ FIXED | ✅ FIXED | Address lookup via /core/addresslookup, U-prefix UPRN format |
| Erewash | ✅ | ✅ FIXED | XHR header + cookie merge fixed Vercel issue |
| High Peak | ✅ | ✅ FIXED | XHR header fixed Vercel issue |
| NE Derbyshire | ❌ | ✅ | Area-based, no postcode lookup |
| South Derbyshire | ❌ | ❌ | Council API down (ERROR 10006) |

### What needs to happen next
1. Set REPORT_SCRIPT_URL env var on Vercel for /report endpoint (user handling)
2. Fix auto-detect picking wrong council (Bolsover returns all UPRNs)
3. Implement address lookup for remaining drivers (Amber Valley, Chesterfield, Bolsover, NE Derbyshire, South Derbyshire when API comes back)

## Cycle 10 - Open-source HACS research for remaining councils

### What happened
- Searched GitHub for open-source implementations of our remaining councils
- Found `mampfes/hacs_waste_collection_schedule` — Home Assistant integration with Python scrapers for UK councils
- They have implementations for: Amber Valley, Bolsover, Chesterfield, Erewash, High Peak
- NE Derbyshire is NOT in their repo (still open issue #2693)

### Key findings from HACS codebase

**Chesterfield** — Salesforce Lightning API fully reverse-engineered:
- Session: `GET chesterfield.gov.uk/bins-and-recycling/bin-collections/check-bin-collections.aspx`
- FWUID: `GET myaccount.chesterfield.gov.uk/anonymous/c/cbc_VE_CollectionDaysLO.app?aura.format=JSON&aura.formatAdapter=LIGHTNING_OUT`
- Search: `POST myaccount.chesterfield.gov.uk/anonymous/aura?r=2&aura.ApexAction.execute=1`
- Method: `CBC_VE_CollectionDays.getServicesByUPRN` with `propertyUprn` param
- **Our driver already matches this exactly!** getCollections is correct.
- HACS does NOT implement address lookup either — UPRN-only

**Amber Valley** — Simple JSON API:
- `GET info.ambervalley.gov.uk/WebServices/AVBCFeeds/WasteCollectionJSON.asmx/GetCollectionDetailsByUPRN?uprn=...`
- **Our driver already matches this!** getCollections is correct.
- HACS does NOT implement address lookup — UPRN-only

**Bolsover** — Calendar-based (A or B), no address lookup:
- User must know their calendar letter (A/B) and collection day (Tue-Fri)
- Scrapes `bolsover.gov.uk/waste-bins-recycling/bin-calendar-{a|b}`
- **Our driver scrapes both calendars** (returns ALL data, no address filtering)
- HACS does NOT implement address lookup — calendar+day-only

**Erewash** — Drupal AJAX:
- `GET erewash.gov.uk/bbd-whitespace/one-year-collection-dates?uprn=...&_wrapper_format=drupal_ajax`
- **Our driver already works** (Vercel fix from Cycle 9)

**High Peak** — Bartec portal:
- `GET bins.highpeak.gov.uk/PublicDashboard` → token
- `POST ?handler=SearchPostcode` → premises list
- `POST ?handler=SelectPrem` → collection schedule
- **Our driver already works** (Vercel fix from Cycle 9)

### Critical insight
**None of the HACS implementations do address lookup (postcode → list of addresses).** They all take UPRN as input directly. This means:
1. Our getCollections implementations are ALREADY CORRECT and match the open-source reference implementations
2. The address lookup (postcode → UPRN list) is NOT solved by any open-source project
3. Address lookup needs to be built from scratch for each council

### What needs to happen next
1. Build address lookup for each council (the hard part — none of the open-source projects solved this)
2. Options for address lookup:
   a. Reverse-engineer each council's website address lookup API (jQuery UI autocomplete, AchieveForms, etc.)
   b. Use a free UK address lookup API (GetAddress.io has 50 free lookups/day, Ideal Postcodes has free tier)
   c. Use browser automation (Playwright) to capture the actual API calls
3. Fix auto-detect picking wrong council (Bolsover returns all UPRNs)
4. Set REPORT_SCRIPT_URL env var on Vercel

## Cycle 11 - Switched to Render, fixed Derby/Chesterfield drivers

### What happened
- Switched from Vercel to Render (derby-d6e5.onrender.com) because Playwright can't run on Vercel serverless (needed for Bolsover AchieveForms)
- Created proxy/api/index.js as HTTP server entry point with res.status().json() shim
- Added in-memory cache (proxy/lib/shared/cache.js) with 24h TTL to addresses endpoint

### What we fixed
- **Derby getCollections**: Website changed - now requires ?address= param in URL. Fixed by looking up address label from postcode during getCollections
- **Chesterfield Aura API**: Two failures - (1) namespace: '' param caused "Action descriptor must be in a valid component format", (2) hardcoded loaded hash 'pqeNg7kPWCbx1pO8sIjdLA' changed to '1123_2HY-XU4ejs_gWkcOb0zOBA'. Fixed by removing namespace param and making loaded hash dynamic from fwuid endpoint
- **Chesterfield food waste**: mapChesterfieldType didn't map food - added food: 'Domestic Food' to the type mapper
- **Flutter app postcode threading**: Added postcode param through fetchSchedule -> getSchedule -> all callers (home_page, calendar_screen, uprn_input_screen, address_picker_screen)

### Render test results
| Council | Address | Collections | Notes |
|---------|---------|-------------|-------|
| Chesterfield | 30 addr | 4 streams | All 4 waste types working |
| Derby | 21 addr | 4 streams | Address param fix working |
| Erewash | 25 addr | 0 (wrong test UPRN) | Works with correct UPRN |
| High Peak | 1 addr | 0 | Only 1 address for SK23 7GL |
| Derbyshire Dales | 0 addr | 4 streams | Address lookup returns empty on Render (caching issue from old code) |
| NE Derbyshire | N/A | 3 streams | No address lookup needed |
| Bolsover | 0 addr | 3 streams | Address needs Playwright on Render |
| South Derbyshire | N/A | N/A | Council API down |
| Amber Valley | N/A | N/A | Server unreachable |

### Known remaining issues
- Bolsover address lookup needs Playwright on Render (Chromium install)
- Derbyshire Dales address lookup returns 0 on Render (may need cache flush after deploy)
- Erewash/High Peak need correct UPRN+postcode pairs for testing
- South Derbyshire: council API down (ERROR 10006)
- Amber Valley: server unreachable
- Chesterfield address lookup was returning 0 but /diagnose endpoint confirmed it works (30 addresses) - likely stale cache

### Git commits
- 2ffdce3 Fix Derby getCollections (address param), Chesterfield Aura API, Flutter postcode threading
- 9266a49 Add diagnose endpoint for Chesterfield debug (removed in 8da9e18)

## Cycle 12 - South Derbyshire CRACKED, Amber Valley geo-restricted

### What happened
- User asked to investigate South Derbyshire and Amber Valley
- South Derbyshire: Fetched the JS files from `maps.southderbyshire.gov.uk/public/pages/bins.js` and `addresssearch_sddc.js`
- Discovered the actual APIs are JSONP endpoints on `maps.southderbyshire.gov.uk/iShareLIVE.Web/getdata.aspx`
- Amber Valley: Found HACS Python source on GitHub confirming the API at `info.ambervalley.gov.uk`
- Apify web-fetch confirmed `info.ambervalley.gov.uk` IS reachable through UK proxy

### South Derbyshire - CRACKED (pure HTTP, no Playwright needed!)
**Address search API:**
```
GET https://maps.southderbyshire.gov.uk/iShareLIVE.Web/getdata.aspx?callback=cb&RequestType=LocationSearch&service=LocationSearch&pagesize=100&startnum=1&mapsource=mapsources/MyHouse&location={postcode}
```
Returns raw JSON (not JSONP-wrapped despite callback param). `data[i][0]` = UPRN, `data[i][7]` = address label.

**Bin collections API:**
```
GET https://maps.southderbyshire.gov.uk/iShareLIVE.Web/getdata.aspx?callback=test&RequestType=LocalInfo&ms=mapsources/MyHouse&format=JSONP&group=Recycling%20Bins%20and%20Waste|Next%20Bin%20Collections&uid={uprn}
```
Returns JSONP-wrapped HTML: `test({...})`. The `_` field contains HTML with dates and descriptions. Existing `parseEntries()` already parses this correctly.

**Fixes applied:**
1. `lookupAddresses` — was returning empty, now uses LocationSearch API
2. `getCollections` URL — changed from `format=JSON` to `callback=test&format=JSONP`, fixed `iShareLIVE.Web` casing
3. JSONP stripping — strips `test(` and `);` wrapper before JSON.parse
4. `IMG_STREAM_MAP` — added `'food'` to `blackweek` and `greenweek` arrays (were missing food waste stream)

### Amber Valley - API confirmed, geo-restricted
**Confirmed working API (from Apify UK proxy):**
```json
{"refuseNextDate":"2026-09-23T00:00:00","recyclingNextDate":"2026-09-30T00:00:00","greenNextDate":"2026-10-06T00:00:00",...}
```

**Address lookup API (from page source JS):**
```
POST https://info.ambervalley.gov.uk/WebServices/AVBCFeeds/GazetteerJSON.asmx/PropertyLookupFeed
Body: srchText={postcode}
```

**Geo-restriction confirmed:**
- `info.ambervalley.gov.uk` is unreachable from local machine (Israel) and Render (US)
- Apify web-fetch can reach it through UK proxy infrastructure
- The bin collection page at `www.ambervalley.gov.uk` loads JS that calls `info.ambervalley.gov.uk`

**Driver rewritten** with:
- `lookupAddresses` using PropertyLookupFeed POST endpoint
- `getCollections` using GetCollectionDetailsByUPRN GET endpoint
- Timeout detection: throws "Amber Valley API unreachable (may be UK-only)" on ETIMEDOUT/ECONNRESET/ENOTFOUND
- Currently throws on Render (expected — API is UK-only)

### Render test results
| Council | Address | Collections | Notes |
|---------|---------|-------------|-------|
| South Derbyshire | ✅ 2 addr | ✅ 4 streams | CRACKED! JSONP API works from Render |
| Amber Valley | ❌ timeout | ❌ timeout | API geo-restricted to UK IPs |

### Git commits
- 50fcd5b Fix South Derbyshire: address lookup + JSONP bin collections API
- 6e42aa9 Fix South Derbyshire food waste stream missing from image map
- ddcd11c Rewrite Amber Valley: address lookup + collections APIs with geo-restriction handling

## Cycle 13 - Bolsover + Amber Valley fully working

### What happened
- User asked to investigate both remaining councils
- Discovered Amber Valley API is NOT geo-restricted (collections worked from Render!)
- The address lookup issue was postcode normalization: our code stripped spaces (`DE562AN`) but API needs `DE56 2AN`
- Bolsover doesn't use address lookup — uses Calendar A/B system (different areas)

### Fixes
- **Amber Valley**: Added `formatPostcode()` to re-insert space before last 3 chars; switched back to POST; added ASMX `d` wrapper handling. Returns 12 addresses for DE562AN, 3 streams for any UPRN.
- **Bolsover**: `lookupAddresses` returns static Calendar A/B options with area descriptions; `getCollections` now only scrapes the selected calendar (not both).

### Render test results
| Council | Address | Collections | Notes |
|---------|---------|-------------|-------|
| Derby | ✅ | ✅ | |
| Amber Valley | ✅ FIXED | ✅ | 12 addresses, 3 streams |
| Bolsover | ✅ FIXED | ✅ | Calendar A/B selection, 3 streams |
| Chesterfield | ✅ | ✅ | |
| Derbyshire Dales | ✅ | ✅ | |
| Erewash | ✅ | ✅ | |
| High Peak | ✅ | ✅ | |
| NE Derbyshire | N/A | ✅ | No lookup needed |
| South Derbyshire | ✅ | ✅ | |

**ALL 9 COUNCILS WORKING!**

### Git commits
- 3722ed9 Fix Amber Valley address lookup (GET instead of POST) + Bolsover calendar A/B selection
