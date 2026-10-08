---
title: Derby Bins — Flutter project state
date: 2026-10-06
---

# Derby Bins — Project State

Persistent handoff note. Read this first at the start of any session that touches this repo, so context does not have to be rediscovered.

**Current status: iOS TestFlight CI is written and committed but has never been built or run.** The three files are pushed to `main`; signing is not configured yet. The full manual checklist is in [[#Still Open — Manual Steps Required]].

---

## Project Facts

| Field | Value |
|---|---|
| App | Derby Bins — UK bin collection schedule |
| Framework | Flutter |
| Bundle ID | `uk.co.derbybins.app` |
| App Store Connect Apple ID | `6817374925` |
| Version | `1.0.0+1` |
| iOS deployment target | 13.0 |
| Branch | `main` |
| Most recent commit | `7b9754c` — *Add iOS TestFlight CI workflow and missing Podfile* |
| Platform folders | `ios/`, `android/`, `macos/`, plus generated `linux/`, `web/`, `windows/` |
| Vendored plugin | `third_party/add_2_calendar` |

Notes on the vendored plugin: its podspec declares `s.platform = :ios, '11.0'` (below the app's 13.0 floor) and it carries a `resource_bundles` entry for `PrivacyInfo.xcprivacy`. Both are handled in [[#ios/Podfile — New]].

Commit history before `7b9754c` is Android notification work: background alarms, exact alarm permissions, notification receivers.

---

## Working Tree — 3 Files Committed and Pushed

All three files went into a single commit on `main` and were pushed to `origin`.

| File | State | Lines |
|---|---|---|
| `codemagic.yaml` | Committed, modified | +52 / −0 |
| `ios/Runner/Info.plist` | Committed, modified | +8 / −0 |
| `ios/Podfile` | Committed, new | 90 lines |

Commit `7b9754c` — 3 files, 150 insertions. Fast-forward push `4ec78b7..7b9754c`: no force, no amend, no rebase.

The two existing Android workflows (`derby-bins`, `derby-bins-apk`) are byte-identical to HEAD. They were not touched.

### codemagic.yaml — new third workflow `derby-bins-ios`

| Setting | Value |
|---|---|
| `name` | `iOS TestFlight` |
| `max_build_duration` | 60 |
| `instance_type` | `mac_mini_m2` |
| `ios_signing.distribution_type` | `app_store` |
| `ios_signing.bundle_identifier` | `uk.co.derbybins.app` |
| `vars.APP_STORE_APPLE_ID` | `"6817374925"` |
| `flutter` | `stable` |
| `xcode` | `latest` |
| `cocoapods` | `default` |
| Triggering | **None — manual runs only, deliberately** |

Script order is fixed and intentional:

1. `xcode-project use-profiles`
2. `flutter pub get`
3. `cd ios && pod install`
4. `flutter build ipa --release --build-number=$N --export-options-plist=$HOME/export_options.plist`

Build number comes from `app-store-connect get-latest-testflight-build-number`, guarded by `${LATEST:-0}` because the command exits 0 with empty stdout when no builds exist.

Artifacts collected: `build/ios/ipa/*.ipa`, `/tmp/xcodebuild_logs/*.log`, `ios/Podfile.lock`.

Publishing: `submit_to_testflight: true`, `submit_to_app_store: false`, ASC credentials passed as `$VAR` references.

No `triggering:` block on purpose. The Android AAB workflow fires on push to main, and publishing every merge to TestFlight is not wanted.

### ios/Podfile — New

This file had **never existed on any branch in the repo's history** before this commit — `git log --all --oneline -- ios/Podfile` returned empty across all 75 refs. `7b9754c` is the commit that added it. It is the hard blocker for `flutter build ipa`, and it is the reason this is worth flagging loudly: Codemagic's documented `find . -name "Podfile" -execdir pod install \;` exits 0 when no Podfile is present, so a missing Podfile does not fail the build step — it surfaces late and confusingly at link time.

Contents:

- `platform :ios, '13.0'` plus a `DERBY_DEPLOYMENT_TARGET = '13.0'` constant, so the post_install clamp and the platform line cannot drift apart.
- `use_frameworks! :linkage => :static` — see [[#Key Decisions and Why]].
- `flutter_ios_podfile_setup` and `flutter_install_all_ios_pods`.
- Nested `RunnerTests` target with `inherit! :search_paths`.
- `post_install` that clamps every pod to `IPHONEOS_DEPLOYMENT_TARGET = '13.0'`, and sets `CODE_SIGNING_ALLOWED = NO` on `com.apple.product-type.bundle` pod targets so resource bundles are never code-signed.

### ios/Runner/Info.plist — +8 / −0

Added two keys:

- `BGTaskSchedulerPermittedIdentifiers = [com.transistorsoft.fetch]`
- `UIBackgroundModes = [fetch]`

No `.entitlements` file was needed — background modes are Info.plist keys, not capabilities.

---

## Key Decisions and Why

**Signing route A — the native `ios_signing` block, not the CLI `fetch-signing-files --create` path.** The account has exactly 3 Codemagic environment variables (`APP_STORE_CONNECT_PRIVATE_KEY`, `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_ISSUER_ID`). The CLI `--create` route additionally requires a 4th variable, `CERTIFICATE_PRIVATE_KEY`. Route A needs no fourth variable.

**The App Store Connect API does have certificate and profile endpoints.** These were added in API v1.1 — the initial 1.0 exposed only TestFlight, Users and Sales. So Codemagic can generate a certificate from a connected ASC key without a Mac.

**But Codemagic's UI only fetches provisioning profiles; it does not create them.** The App Store profile must already exist in the Apple Developer Portal.

**`use-profiles` must run before `pod install`.** `xcode-project use-profiles` globs `**/*.xcodeproj`. On a clean checkout `ios/Pods/Pods.xcodeproj` does not exist yet, so it structurally cannot stamp `PROVISIONING_PROFILE_SPECIFIER` onto the CocoaPods resource-bundle targets. Running it after `pod install` is the risky order.

**`pub get` must precede `pod install`.** The Podfile reads `ios/Flutter/Generated.xcconfig` for `FLUTTER_ROOT` and raises a clear error if that file is absent.

**No pbxproj edit was needed for signing.** `xcode-project use-profiles` writes `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE=Manual` and `PROVISIONING_PROFILE_SPECIFIER` at build time. The project's empty `DEVELOPMENT_TEAM` is not a problem.

**Build number queries TestFlight, not the App Store.** A review pass caught a real bug here: `get-latest-app-store-build-number` reads builds released to the App Store, but `submit_to_app_store` is `false` — so it would have returned empty forever, every build would have been numbered 1, and the second upload would have collided. Corrected to `get-latest-testflight-build-number`.

**`processing` was deliberately left out of `UIBackgroundModes`.** Grepping `lib/` found only `BackgroundFetch.configure` and `registerHeadlessTask`, never `scheduleTask`. `processing` exists only for `scheduleTask`, and declaring an unused background mode is an App Review rejection vector under Guideline 2.5.4.

**`xcode: latest` and `flutter: stable` are intentionally unpinned.** Nothing has been validated on macOS yet, and pinning to an unvalidated image risks an immediate hard failure. Pin both after the pipeline is green.

**`use_frameworks! :linkage => :static` kept despite uncertainty.** The project has Flutter's Swift Package Manager integration enabled — `project.pbxproj` references `FlutterGeneratedPluginSwiftPackage` — and `background_fetch 1.7.0` is SPM-capable. If SPM claims the plugin, the line is unnecessary. It is kept because removing it risks a hard `pod install` failure if the plugin resolves through CocoaPods, whereas leaving it when unnecessary is only a benign linking change.

---

## Still Open — Manual Steps Required

Nothing has been built or run. There is no macOS, Xcode, CocoaPods or Ruby on the development machine. The files are committed and pushed, but signing is still unconfigured. These block the first successful build:

- [ ] **Add the Apple Developer Portal key in Codemagic** — Team settings → Team integrations → Developer Portal → Manage keys. Add the ASC Issuer ID, Key ID and the `.p8` file.
- [ ] **Generate an Apple Distribution certificate in Codemagic** — not "Apple Development". It is downloadable only once, immediately after creation. Apple caps Distribution certificates at 3.
- [ ] **Create the App Store provisioning profile at developer.apple.com** for `uk.co.derbybins.app` (Distribution → App Store), then **Fetch profiles** in Codemagic and give it a reference name.
- [ ] **Run the first manual build**, then inspect the artifacts.

---

## Completed

- [x] **Commit the 3 files** — `codemagic.yaml`, `ios/Podfile` (new), `ios/Runner/Info.plist` in commit `7b9754c` on `main`, pushed to `origin`.

### Push Record — do not re-verify

| Field | Value |
|---|---|
| Commit SHA | `7b9754c8e6c65c189dc1911478264619aec2decb` |
| Subject | `Add iOS TestFlight CI workflow and missing Podfile` |
| Remote | `origin` → `https://github.com/sofelaisrael/derby.git` |
| Branch / upstream | `main` / `origin/main` |
| Push | fast-forward `4ec78b7..7b9754c` — no force, no amend, no rebase |
| Contents | `codemagic.yaml` (+52), `ios/Podfile` (new, 90 lines), `ios/Runner/Info.plist` (+8) — 3 files, 150 insertions |

The repo has `core.autocrlf=true` and no `.gitattributes`, so committing `codemagic.yaml` and `ios/Podfile` emitted `LF will be replaced by CRLF` warnings. Cosmetic — the committed content is unaffected.

---

## Repo Hygiene State

Current `git status --short`:

```
 M .opencode/ooda-log.md
?? "AI Memory/"
```

Both remain uncommitted deliberately:

- `.opencode/ooda-log.md` — agent-harness noise, unrelated to this work.
- `AI Memory/` — this note directory. Whether it should be committed, gitignored, or kept local is undecided.

---

## Open Questions and Unresolved

- **Is `use_frameworks! :linkage => :static` actually needed?** Settle after the first build with `grep background_fetch ios/Podfile.lock`. If the plugin is absent from the lockfile, SPM handled it and the line can be deleted from `ios/Podfile`.
- **Should `ios/Podfile.lock` be committed?** It is not covered by any `.gitignore`, so it is currently untracked noise. For an app, committing it is the normal choice. Defer until after a successful `pod install`.
- **Should `derby-bins-ios` get a push or tag `triggering:` block?** Only once signing is proven.
- **The Android AAB build from this push needs checking in Codemagic.** `derby-bins` has a push-to-main trigger, so pushing `7b9754c` did fire the Android workflow. The new `derby-bins-ios` workflow has no `triggering:` block, so it did **not** run from this push and will not run on future pushes until a trigger is added. Check the Android Play build result in Codemagic.
- **What should happen to `AI Memory/`?** Currently untracked. Undecided between committing it, adding it to `.gitignore`, or leaving it local-only.
- **Export method may need updating.** Newer Xcode may reject export method `app-store` in favour of `app-store-connect`. If export fails *after* a successful archive, append `xcode-project use-profiles --custom-export-options='{"method":"app-store-connect"}'`. Diagnose from the `/tmp/xcodebuild_logs/*.log` artifact.
- **First TestFlight upload takes 10–60 minutes of "Processing"** before it is installable. That is not a failure.
- **`.opencode/ooda-log.md` is dirty** (+234) from the agent harness. Pre-existing and unrelated to this work; undecided whether to commit or gitignore.
- **Line endings are inconsistent.** The repo has `core.autocrlf=true` and no `.gitattributes`. `Info.plist` is CRLF while `codemagic.yaml` and `Podfile` are LF. Cosmetic, but a `.gitattributes` would settle it.
- **Security note for future sessions.** The ASC key is Admin role, which is broader than needed — App Manager suffices for profile creation plus TestFlight upload, and Codemagic recommends App Manager. The credentials originated from a third party named "Notts"; worth confirming the Apple Developer account ownership is correct.

---

## Verification Performed

All checks below were run *before* the commit, against the working tree.

**45 of 45 automated static checks passed.** These covered: YAML parse and workflow count, the Android workflows being byte-identical to HEAD, script order, forbidden and absent strings, plist well-formedness via `plistlib`, key ordering, line endings, Podfile token balance, bundle ID and deployment target cross-file consistency, nothing staged, nothing committed, and `ios/Podfile` being committable.

**Could not be verified:**

- Ruby syntax — no interpreter available.
- Any real `pod install` or `xcodebuild` run.
- Codemagic server-side schema validation.
- Whether the certificate and profile are actually configured in Codemagic.
- Whether the bundle ID is provisioned in the Apple Developer portal.

---

## Static Website — Built, Untracked, Not Deployed

**Nothing here is live.** A 5-page static site was written into `hosting/public/` this session, plus a root `firebase.json`. Every one of those files is **untracked** in git, `firebase deploy` has never been run, and **no Firebase project is confirmed linked**. `https://derbybins.web.app` does not serve this content. Treat the site as a local draft only. If a later session finds it reachable, something outside this note changed it.

Ported from the sibling project at `C:\Users\PROGRESSIVE\Documents\Israel\mansfield\hosting\public\`. That is the source tree on disk, not a deployment of either site.

`styles.css` was ported **verbatim** from the sibling. The rest was rewritten for Derby Bins: 9 councils rather than 8, and 3 Derby-specific banned phrases in `app.js`.

### Files Created — all untracked

| File | Purpose |
|---|---|
| `hosting/public/index.html` | Home — hero, 3-step how-it-works, searchable 9-council grid |
| `hosting/public/sources.html` | Official Information Sources — per-council provenance |
| `hosting/public/privacy.html` | Privacy Policy (`noindex`) |
| `hosting/public/support.html` | Support FAQ |
| `hosting/public/404.html` | 404 (`noindex, follow`) |
| `hosting/public/styles.css` | Shared design system, ported verbatim |
| `hosting/public/app.js` | Nav toggle, council search, dev-gated assertions, drift check |
| `hosting/public/sitemap.xml` | 3 indexable URLs, hand-written |
| `hosting/public/assets/store_icon_512.png` | 512x512, generated from repo-root `logo.png` |
| `firebase.json` | Firebase Hosting config: CSP, security headers, 6 rewrites |

`hosting/` and `firebase.json` now add two further entries to `git status --short` beyond the two recorded in [[#Repo Hygiene State]]. They are uncommitted for the same reason that everything else is.

### Why It Matters — the in-app privacy link was dead

`lib/screens/settings_tab.dart:48` defines `_privacyPolicyUrl = 'https://derbybins.web.app/privacy'`, opened at line 875. **Before this work no such site existed, so that URL 404s** and the app's only route to its own privacy policy was broken.

The `{ "source": "/privacy", "destination": "/privacy.html" }` rewrite in `firebase.json` is what makes it resolve. That entry is load-bearing, not tidiness. The other 5 rewrites exist so the clean and `.html` spellings both reach the same single document, which is what lets `sitemap.xml` list only the clean form.

The site is also what Google Play reads for the privacy policy, so a listing submitted before a deploy points reviewers at a dead URL.

### Site Facts

| Field | Value |
|---|---|
| Brand | Derby Bins |
| Controller | Augustine Igharo, trading as Derby Bins |
| Contact email | contactxomo@gmail.com |
| Origin | `https://derbybins.web.app` |
| Play id | `uk.co.derbybins.app` — listing **not published**; the CTA ships anyway as a deliberate launch flag |
| Indexable URLs | 3 — home, sources, support |

9 councils, in this order: `derby`, `erewash`, `ambervalley`, `highpeak`, `derbyshiredales`, `bolsover`, `chesterfield`, `southderbyshire`, `northeastderbyshire`.

That order matches `COUNCILS[]` in `proxy/lib/drivers/index.js` and `_fallbackCouncils` in `lib/services/council_api.dart:61`, and it is asserted rather than eyeballed — see [[#How to Verify Site Changes]].

### Deployment State

**Not deployed.** `firebase.json` exists, but no `firebase deploy` has been run and no Firebase project is confirmed linked. Whether a project is linked was not checked, because this session had no shell. Everything is untracked in git.

---

## Load-Bearing Invariants — Breaking These Fails Silently

Each of these has a failure mode with **no visible error anywhere**, which is why they are written down rather than left as a convention.

1. **The inline no-JS script must stay byte-identical on all five pages.** `<script>document.documentElement.classList.remove('no-js')</script>`. Its base64 SHA-256 is `sha256-dFqnkix/KyuQ/tR3B/FYwRtcbWXrtRW7VdscV/VFsmc=`, pinned in the CSP in `firebase.json`. It is the hash of the text *between* the tags — not the whole tag, not hex. Reword it by one byte and the CSP blocks the script on that page, `no-js` survives, and the page degrades to: **open nav panel, no hamburger, and no council search field at all.** Re-derive with the recipe recorded in the `firebase.json` comment block above the header entry.

2. **The independence sentence must match `app.js`'s `DISCLAIMER` character-for-character** (whitespace-normalised) across **8** HTML occurrences:

   | Location | Files |
   |---|---|
   | `.disclaimer__text` asides — 2 | `index.html:339`, `sources.html:89` |
   | `.site-footer__disclaimer` — 5 | `index.html:352`, `sources.html:366`, `privacy.html:355`, `support.html:153`, `404.html:110` |
   | Support FAQ answer — 1 | `support.html:126` |

   The sentence: "Derby Bins is an independent utility app. It is not affiliated with, authorised by, sponsored by, or endorsed by any local council or government body."

3. **`app.js` holds 9 `EXPECTED_SLUGS` and 19 `BANNED_PHRASES`** — 16 generic plus 3 Derby-specific (`official bin app`, `official bins app`, `council app`). **A banned phrase may not appear even inside a denial**: the matcher is a bare `indexOf` over body text, so "Derby Bins is not an official app" trips the `official app` entry. Write "independent utility app" instead.

4. **`DESKTOP_MQ` (`'(min-width: 900px)'`) in `app.js` is hard-coupled to the 900px media query in `styles.css`.** Change one without the other and the desktop nav becomes permanently unreachable.

---

## How to Verify Site Changes

`app.js` carries its own assertions, and they are **dev-gated**: they run only on localhost or with `?dev=1`, they are **warn-only**, and they **never throw**.

Serve `hosting/public/` from any static server and load each of the five pages with `?dev=1`. Expect **zero `console.warn`**.

`index.html?driftcheck=1&dev=1` additionally cross-checks the homepage against `/sources.html` — slugs, display names, URLs and fragments — and must also be clean. This is what proves the three-way slug contract (`EXPECTED_SLUGS` ↔ `data-council` ↔ `data-source`).

Verified in headless Chrome via the `playwright-core` already present under `proxy/node_modules`.

---

## privacy.html — Three Placeholders Awaiting Owner Input

Three `<!-- NEEDS OWNER INPUT -->` markers, all in `privacy.html`:

- **Line 151** — the lawful basis for each processing category is not decided.
- **Line 300** — the report-submission retention period is not decided. This one has a second half: the chosen period must also be implemented in the Apps Script, so the published promise and the actual behaviour agree.
- **Line 329** — whether advance notice of material policy changes will be given is not decided.

The page currently ships with visible gaps at these points. Do not treat it as Play-submission-ready until they are answered.

---

## Pre-Existing App Bugs — Found While Researching the Site

**Neither bug was caused by the website work. Neither has been fixed.** Both surfaced from tracing the paths the app calls against the paths the server actually serves.

### Bug A — the report form posts to a path the server does not serve

| Where | What it says |
|---|---|
| `lib/services/report_service.dart:13` | `_endpoint = '/api/report'` |
| `lib/services/report_service.dart:29` | builds `'${CouncilApi.proxyBaseUrl}$_endpoint'` |
| `proxy/vercel.json:6` | `{ "src": "/report", "dest": "api/report.js" }` — **no `/api` prefix** |
| `lib/services/council_api.dart:179` | `Uri.parse('$proxyBaseUrl/bins')` — no prefix, and that path works |

So the report form POSTs to `<host>/api/report` while the server serves `<host>/report`. The submission likely fails silently: `report_service.dart` collapses every non-2xx and every exception into `ReportFailure` (lines 42–48), which the UI surfaces as a generic "Something went wrong" snackbar.

**Compounding this:** `proxy/api/report.js:99` returns HTTP 503 when `process.env.REPORT_SCRIPT_URL` is unset, and `.opencode/ooda-log.md` records it as unset at three separate points (lines 120, 176, 401). So reports may not be reaching the Google Sheet at all — which would mean the privacy policy's disclosure about report storage describes a system that is not currently running. Note the log frames the fix as setting the var "on Vercel", which inherits the wrong-host assumption corrected in [[#Correction — The Proxy Host Is Render, Not Vercel]].

Fix path: reconcile `_endpoint` with the served route, then confirm `REPORT_SCRIPT_URL` is set in the actual deployment.

### Bug B — South Derbyshire driver likely has a wrong-case URL path

`proxy/lib/drivers/southderbyshire.js:3-4` uses `https://maps.southderbyshire.gov.uk/ishareLIVE.Web/...` with a **lowercase L** in `ishareLIVE`. The live service uses `iShareLive.Web` with a capital L. ASP.NET paths are case-sensitive, so this would 404 — silently breaking South Derbyshire collection lookups, which fail the same defensive way `bins` calls do.

**Not verified against the live host this session** — no network request was made. Confirm before fixing, because the fix is only correct if the capital-L form is the live one.

---

## Correction — The Proxy Host Is Render, Not Vercel

A session note may elsewhere state the proxy is deployed to `derby-teal.vercel.app`. **The app does not use that.**

- `lib/services/council_api.dart:31` — `static String proxyBaseUrl = 'https://derby-d6e5.onrender.com'`. **Render, not Vercel.**
- The string `vercel` appears **nowhere** in `lib/`.
- `proxy/vercel.json` exists, but it is not what the app calls.

`privacy.html` section 6 therefore names **Render** as the host processor, which matches the code. **If the proxy is ever migrated to Vercel, that bullet and its adjacent comment must change in the same commit** — otherwise the published policy names a processor that no longer handles the data.