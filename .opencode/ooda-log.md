# Derbyshire Bin Collection Proxy

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
