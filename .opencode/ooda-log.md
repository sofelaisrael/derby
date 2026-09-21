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

## Research complete for remaining councils
- Amber Valley: GET info.ambervalley.gov.uk/WebServices/AVBCFeeds/WasteCollectionJSON.asmx/GetCollectionDetailsByUPRN?uprn=... - parse JSON
- High Peak: Bartec portal at bins.highpeak.gov.uk/PublicDashboard - POST with token
- Derbyshire Dales: Firmstep form at selfserve.derbyshiredales.gov.uk/renderform - POST with hidden inputs
