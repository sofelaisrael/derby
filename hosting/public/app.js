/* =============================================================================
   Derby Bins — public site behaviour

   Vanilla JS. No build step, no modules, no dependencies, no third-party code.
   Every initialiser is null-safe: a page missing the nav toggle, the council
   grid or the search region simply skips that feature instead of throwing.
   404.html loads this file and has none of them.

   Verbatim port of the proven sibling site's behaviour file. Zero logic changes:
   the nav toggle, the council search, the drift check, the dev assertions and
   the boot sequence are the sibling's, line for line. The only edits are LOG,
   the DISCLAIMER, EXPECTED_SLUGS (9 Derby slugs, not the sibling's 8), and
   three Derby-specific BANNED_PHRASES entries.
   ========================================================================== */
(function () {
  'use strict';

  var LOG = '[db]';
  var STATUS_MS = 400;          /* trailing debounce for the spoken status only */
  var DESKTOP_MQ = '(min-width: 900px)';
  var SOURCES_PATH = '/sources.html';

  /* The canonical non-affiliation sentence. Every .disclaimer AND every
     .site-footer__disclaimer on the site must read exactly this,
     whitespace-normalised. Change it here and nowhere else.

     It is asserted on BOTH selectors because the footer's repeat is not a
     .disclaimer block: counting only .disclaimer made the homepage minimum
     unsatisfiable by the markup the site actually ships (one aside + one
     footer). Do not "simplify" this back to a single selector.

     Longer than the sentence it replaced ("Derby Bins is not affiliated with
     or endorsed by any council."), and deliberately so: it
     names independence, and lists authorised / sponsored / endorsed and
     "government body", which is what Google Play asks an unaffiliated app to
     disclose. It must NOT be tightened to "no connection to any council":
     the app genuinely does read Derby City Council's data, so a blanket
     "no connection" claim would be false. "any local council" already covers
     Derby City Council. 404.html carries it too -- if you change it here,
     change it there or 404 starts warning. */
  var DISCLAIMER =
    'Derby Bins is an independent utility app. It is not affiliated with, authorised by, sponsored by, or endorsed by any local council or government body.';

  /* =============================================================================
     THE SLUG CONTRACT -- three places, one list. Read this before editing.

These nine values are the `CouncilInfo.slug` keys from the app itself:
     lib/services/council_api.dart, `_fallbackCouncils` (lines 61-83) and the
     `_councilWebsites` map (lines 106-116). The same order is the order of
     `COUNCILS[]` in proxy/lib/drivers/index.js. They are NOT invented for the
     web site and must never be re-derived from a design convention -- an
     earlier version of the sibling site's file used five hyphenated
     `-district`/`-city` slugs, none of which appear anywhere in this app.
     A Play reviewer cross-referencing this
     site against the app's code would find no match and could reasonably
     conclude the provenance mapping was fabricated.

       All three of these must agree, and `?driftcheck=1` is what proves it:

         1. this array                       -- app.js
         2. data-council="..."               -- each <li> on the homepage
         3. data-source="..."               -- each .source-item on the sources page

The same value is also the URL fragment, so a council card links to
     /sources.html#derby and that element carries id="derby" on the sources
     page. Full display names ("Derby City Council") are link
     TEXT only -- never the identifier, because the fragment has to match.

       A council card may also carry data-search="..." for extra search haystack
       (aliases, bin-scheme wording). It is optional and never asserted on.
     ========================================================================== */
  var EXPECTED_SLUGS = Object.freeze([
    'derby',
    'erewash',
    'ambervalley',
    'highpeak',
    'derbyshiredales',
    'bolsover',
    'chesterfield',
    'southderbyshire',
    'northeastderbyshire'
  ]);

  /* Nineteen entries. The first sixteen are brand-neutral and came across from
     the sibling site unchanged. The last three are Derby-specific; read the
     note below before adding to this list. */
  var BANNED_PHRASES = Object.freeze([
    'council-approved', 'council-backed', 'council-endorsed', 'council-operated',
    'council-managed', 'government-backed', 'government-endorsed',
    'government-approved', 'government-operated', 'government service',
    'official app', 'official service', 'accredited by', 'certified by',
    'as an official', 'we are a government',
    /* Derby additions. The brand contains a constituent authority's name, so the
       plausible bad edit is "the official Derby bin app" / "the council app",
       and none of those contain the phrases above as substrings. */
    'official bin app', 'official bins app', 'council app'
  ]);

  /* A banned phrase may not appear EVEN INSIDE A DENIAL. The matcher is a bare
     indexOf over body text, so "Derby Bins is not an official app" trips the
     `official app` entry and warns. Never write a denial that contains one of
     these literals; say "independent utility app" instead, which is what the
     canonical DISCLAIMER does. */

  /* ------------------------------------------------------------------ utils */

  function warn(msg) {
    if (window.console && typeof window.console.warn === 'function') {
      window.console.warn(LOG + ' ' + msg);
    }
  }

  function norm(text) {
    return String(text == null ? '' : text).replace(/\s+/g, ' ').trim();
  }

  /* An anchor's VISIBLE text: text nodes, minus anything inside a
     .visually-hidden element, minus the inline <svg> (which contributes no
     text anyway). plainTextContent cannot be used -- the new-tab hint is a
     real text node in the DOM and would make every comparison fail. */
  function visibleText(el) {
    var out = '', n;
    for (n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 3) out += n.nodeValue;
      else if (n.nodeType === 1 && !n.classList.contains('visually-hidden')) out += visibleText(n);
    }
    return norm(out);
  }

  /* True when an anchor's visible text IS an address rather than prose: a full
     https:// URL, or a bare hostname. Both shapes appear on this site and both
     are load-bearing for a reviewer:
       - sources.html .source-item__url  -> the full https:// URL, spelled out
       - index.html   .council-item     -> the bare hostname (www.council.gov.uk)
     Anchored at both ends on purpose: "GOV.UK council profile" starts with
     something hostname-shaped but is prose after it, and must not match. */
  var URL_TEXT = /^(?:https?:\/\/\S+|(?:[\w-]+\.)+[a-z]{2,}(?:\/\S*)?)$/;
  function isUrlText(el) {
    return URL_TEXT.test(visibleText(el).toLowerCase());
  }

  function uniq(list) {
    var out = [], i;
    for (i = 0; i < list.length; i++) if (out.indexOf(list[i]) < 0) out.push(list[i]);
    return out;
  }

  function pageKind() {
    var p = String(window.location.pathname || '').toLowerCase();
    if (p === '/' || /\/index\.html?$/.test(p)) return 'home';
    if (/\/sources(\.html?)?$/.test(p)) return 'sources';
    return 'other';
  }

  /* ---------------------------------------------------------------- (a) no-js

   Belt-and-braces only. Each page already removes the class from an inline
   script in <head>, before the nav is parsed -- see the note in styles.css
   section 4. That inline script is what makes the no-flash guarantee hold;
   this line is a fallback for any page whose <head> script is missing. Keep it
   even though it should never be the thing that runs. */
  var root = document.documentElement;
  if (root && root.classList) root.classList.remove('no-js');

  /* ------------------------------------------------------- (b) mobile nav */

  function initNav() {
    var toggle = document.querySelector('.nav-toggle');
    var panel = document.getElementById('site-menu');
    if (!toggle || !panel) return;                 /* null-safe: 404 has no nav */

    var mq = window.matchMedia ? window.matchMedia(DESKTOP_MQ) : null;

    function isDesktop() { return !!(mq && mq.matches); }
    function isOpen() { return !panel.hasAttribute('hidden'); }

    function setOpen(open) {
      if (open) panel.removeAttribute('hidden');
      else panel.setAttribute('hidden', '');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    }

    /* The panel ships COLLAPSED (`hidden` is in the HTML) so JS users get no flash.
       No-JS users keep it open via `.no-js .site-nav[hidden]`. From 900px the nav
       is a permanent flex row, so `hidden` is dropped and aria-expanded is set
       to "true" to describe the region accurately. Why the CSS override needs
       !important is explained in styles.css section 4 -- that is the one place
       the cascade subtlety is documented. */
    function toDesktop() {
      panel.removeAttribute('hidden');
      toggle.setAttribute('aria-expanded', 'true');
    }

    if (isDesktop()) toDesktop();
    else setOpen(false);

    toggle.addEventListener('click', function () {
      setOpen(!isOpen());
    });

    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape' && e.key !== 'Esc' && e.keyCode !== 27) return;
      if (isDesktop() || !isOpen()) return;
      setOpen(false);
      toggle.focus();
    });

    document.addEventListener('click', function (e) {
      if (isDesktop() || !isOpen()) return;
      if (panel.contains(e.target) || toggle.contains(e.target)) return;
      setOpen(false);
    });

    if (mq) {
      var onBreakpoint = function () {
        if (isDesktop()) toDesktop();
        else setOpen(false);
      };
      if (typeof mq.addEventListener === 'function') mq.addEventListener('change', onBreakpoint);
      else if (typeof mq.addListener === 'function') mq.addListener(onBreakpoint);
    }
  }

  /* --------------------------------------------------- (c) council search

     Required DOM. The order matters and is not inferred from the CSS:

       .council-search
         .council-search__control   <- data-search-region goes HERE, on this
           |                           element only, never on .council-search
           +-- .council-search__label   <label for> the input's id
           +-- .council-search__field   position:relative, holds icon+clear
           |     +-- .council-search__icon
           |     +-- .council-search__input   type="search"
           |     +-- .council-search__clear   ships WITH hidden
           +-- .council-search__hint
           +-- .council-search__status      role="status", one text node
         .council-grid               <- siblings of the control, not children
           +-- [data-council="<slug>"]  x9
         .council-search__empty      <- ships WITH hidden, and is a SIBLING of
           |                             the grid and OUTSIDE data-search-region
           +-- [data-empty-query]         so no-JS readers never see it
           +-- .council-search__empty-clear  a <button>

     data-search-region must not wrap the grid: hiding it without JS is how
     no-JS readers get all 9 councils, and it must not hide the grid too. */
  function initSearch() {
    var region = document.querySelector('[data-search-region]');
    if (!region) return;                          /* null-safe: 404, sources */

    var input = region.querySelector('.council-search__input');
    var clear = region.querySelector('.council-search__clear');
    var status = region.querySelector('.council-search__status');
    var emptyState = document.querySelector('.council-search__empty');
    var emptyClear = emptyState
      ? emptyState.querySelector('.council-search__empty-clear')
      : null;
    var emptyQuery = emptyState
      ? emptyState.querySelector('[data-empty-query]')
      : null;
    var items = document.querySelectorAll('[data-council]');
    if (!input || !items.length) return;

    var total = items.length;
    var timer = null;

    /* "&" and "," become spaces on BOTH sides of the comparison. Normalising
       the haystack alone is not enough: a query of "derby & derbyshire" would
       then ask for a literal "&" token the haystack can never contain, so both
       words of a query joined by an ampersand would fail to match at all. Both
       sides go through the same normaliser. */
    function terms(text) {
      return norm(text).toLowerCase().replace(/[&,]/g, ' ').split(' ').filter(Boolean);
    }

    /* Haystack per item: textContent + data-search. Computed once — 9 items, and
       nothing here ever mutates their text. */
    var haystacks = [];
    for (var h = 0; h < items.length; h++) {
      haystacks.push(terms(
        (items[h].textContent || '') + ' ' + (items[h].getAttribute('data-search') || '')
      ).join(' '));
    }

    function statusText(visible) {
      return visible === 0
        ? 'No councils match your search.'
        : 'Showing ' + visible + ' of ' + total + ' councils';
    }

    /* Debounced. The live region is only ever assigned a non-empty string, so
       the announcement is never lost to an empty frame. */
    function announce(visible) {
      if (timer) window.clearTimeout(timer);
      timer = window.setTimeout(function () {
        if (status) status.textContent = statusText(visible);
      }, STATUS_MS);
    }

    function syncClearButton() {
      if (!clear) return;
      if (input.value) clear.removeAttribute('hidden');
      else clear.setAttribute('hidden', '');
    }

    function apply(value) {
      var tokens = terms(value);
      var visible = 0;

      for (var i = 0; i < items.length; i++) {
        var hay = haystacks[i];
        var match = true;
        for (var t = 0; t < tokens.length; t++) {
          if (hay.indexOf(tokens[t]) === -1) { match = false; break; }
        }
        if (match) {
          items[i].removeAttribute('hidden');
          visible++;
        } else {
          items[i].setAttribute('hidden', '');
        }
      }

      if (emptyState) {
        if (visible === 0) {
          if (emptyQuery) emptyQuery.textContent = '“' + norm(value) + '”';
          emptyState.removeAttribute('hidden');
        } else {
          emptyState.setAttribute('hidden', '');
        }
      }

      syncClearButton();
      announce(visible);
      return visible;
    }

    /* Focus the input, which is the logically preceding control. It must happen
       AFTER apply(): apply() hides this very button (and, for the empty-state
       button, hides the container it sits in), and `hidden` means
       display:none, which drops focus to <body> -- so focusing first would just
       be undone a moment later. With focus parked on the input, the next Tab
       continues through the form instead of restarting from the skip link.
       This matches Chrome's native search-clear affordance and GOV.UK. */
    function reset() {
      input.value = '';
      apply('');
      input.focus();
    }

    /* type="search": `input` is the ONLY event bound. styles.css sets
       appearance:none on .council-search__input, so the WebKit/Safari native
       clear button does not exist here and never needs handling; binding only
       `input` also means a pasted or typed value cannot be counted twice.
       Do not add `search` or `change` listeners. */
    input.addEventListener('input', function () {
      apply(input.value);
    });

    if (clear) clear.addEventListener('click', reset);
    if (emptyClear) emptyClear.addEventListener('click', reset);

    /* Initial state, written directly (not debounced): this is page load, not a
       user action, and the value is derived from the DOM rather than trusted. */
    if (status) status.textContent = statusText(total);
    apply(input.value);
  }

  /* (d) dev assertions: read-only, never throws, never edits markup.

     GATED. assertMarkup() runs only on localhost or with ?dev=1 -- see boot().
     A Play reviewer opening devtools on production must not get a wall of
     console.warn noise from a dev aid; the noise would bury real drift.
     runDriftCheck() has its own gate, ?driftcheck=1, and only from the home
     page. Nothing in this section runs on a normal production view. */
  function check(ok, msg) { if (!ok) warn(msg); }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }

  function runDriftCheck() {
    /* Same-origin, opt-in via ?driftcheck=1. */
    if (typeof window.fetch !== 'function') return;

    /* slug -> [display name, sorted set of council page URLs, sorted set of
       #fragments]

       URL and fragment are compared SEPARATELY, and only when BOTH sides have
       entries, because the two pages link differently by design:

         URL -- the SAME on both pages, so it must match. Each council's own
           page. Collected through COUNCIL_URL_SEL, not through "every
           a[href^=http]", because "every anchor" is not the same thing on the
           two pages and made the check unsatisfiable:

             index   card  1 external anchor  (the council hostname link)
             sources card  3 external anchors (the visible URL, the "Open
                             official source" button pointing at the SAME URL,
                             and a GOV.UK council profile)

           Comparing all of them with sort().join(' ') and no dedupe guaranteed
           "drift url" for all nine councils on every single run. Two separate
           faults, either one fatal:
             * the council URL appears twice in a sources card, so even
               deleting the GOV.UK link could never make the two sides equal;
             * the GOV.UK profile exists only on the sources page, by design,
               so including it guarantees a permanent mismatch.

           Hence: select by structure, dedupe, compare as a set. The GOV.UK
           link is deliberately OUT of the compared set -- it is the national
           directory entry for a council, not the council's own data page, and
           it is asserted on its own below.

         fragment -- DIFFERENT by design, so only compared when both sides
           have one. The homepage card links INTERNAL (/sources.html#derby),
           the sources item links EXTERNAL, so it has none. The fragment check
           is what earns its keep here: it proves each council card points at
           its own source anchor. */
    var COUNCIL_URL_SEL = '.source-item__url a, .council-item__actions a.external-link';

    function items(scope, attr) {
      var out = {}, ns = scope.querySelectorAll('[' + attr + ']'), i, j, s, u, f, ls, m;
      for (i = 0; i < ns.length; i++) {
        s = norm(ns[i].getAttribute(attr));
        if (!s) continue;
        u = []; f = [];
        /* Council page URLs: structural selector + dedupe, so the sources card's
           duplicated URL collapses to one and its GOV.UK profile is excluded. */
        ls = ns[i].querySelectorAll(COUNCIL_URL_SEL);
        for (j = 0; j < ls.length; j++) {
          var u2 = ls[j].getAttribute('href') || '';
          if (/^https?:/i.test(u2)) u.push(u2);
        }
        u = uniq(u).sort();
        /* Fragments: every anchor, because a card may link to its own anchor
           from anywhere inside it. Dedupe for the same reason as above. */
        ls = ns[i].querySelectorAll('a[href]');
        for (j = 0; j < ls.length; j++) {
          var h = ls[j].getAttribute('href') || '';
          if (/^https?:/i.test(h)) continue;
          if (h.indexOf('#') > -1) f.push(h.slice(h.indexOf('#') + 1));
        }
        f = uniq(f).sort();
        m = ns[i].querySelector('.council-item__name, .source-item__name');
        out[s] = [norm(m ? m.textContent : ''), u.join(' '), f.join(' ')];
      }
      return out;
    }
    window.fetch(SOURCES_PATH).then(function (r) {
      if (!r.ok) throw new Error(r.status);
      return r.text();
    }).then(function (html) {
      var a = items(document, 'data-council');
      var b = items(new window.DOMParser().parseFromString(html, 'text/html'), 'data-source');
      var ka = Object.keys(a).sort(), kb = Object.keys(b).sort(), i, k;
      check(ka.join() === kb.join(), 'drift slugs ' + ka + ' vs ' + kb);
      for (i = 0; i < ka.length; i++) {
        k = ka[i];
        if (!b[k]) continue;
        if (a[k][0] !== b[k][0]) check(false, 'drift name ' + k + ': ' + a[k][0] + ' != ' + b[k][0]);
        /* The council's own page URL. Both sides now carry exactly one (see
           COUNCIL_URL_SEL), so this is a real equality, not a set-tolerance. */
        if (a[k][1] && b[k][1] && a[k][1] !== b[k][1]) {
          check(false, 'drift url ' + k + ': ' + a[k][1] + ' != ' + b[k][1]);
        }
        if (a[k][1] && !b[k][1]) check(false, 'drift url ' + k + ': sources page has no council URL');
        if (b[k][1] && !a[k][1]) check(false, 'drift url ' + k + ': home page has no council URL');
        /* Currently a no-op in practice: the sources item links externally only,
           so its fragment set is empty and this comparison is skipped by the
           both-sides rule. It is kept because it costs nothing and would catch
           a regression if the sources item ever gains an internal anchor. */
        if (a[k][2] && b[k][2] && a[k][2] !== b[k][2]) {
          check(false, 'drift fragment ' + k + ': ' + a[k][2] + ' != ' + b[k][2]);
        }
      }
    }).catch(function (e) { warn('drift failed: ' + (e.message || e)); });
  }

  /* textContent WITHOUT <script> and <style> subtrees, for DOMs that have no
     innerText. innerText already ignores them (it reports RENDERED text), so in
     a browser this is never reached. It exists for the other case: a DOM without
     innerText -- jsdom, most non-browser test runners -- where the bare
     textContent fallback reads app.js's OWN source, putting all nineteen
     BANNED_PHRASES literals into the haystack and firing every warning against
     the file that defines them. That is harmless in production and a trap for
     the next person who wires up a test runner. Recursion rather than
     clone-and-strip: one pass over <body>, no clone, no serialise, and sibling
     order is preserved so a phrase split across two elements still matches. */
  function textWithoutCode(el) {
    var out = '', kids, i, tag;
    if (!el) return '';
    if (el.nodeType === 3) return el.nodeValue || '';
    if (el.nodeType !== 1) return '';
    tag = (el.tagName || '').toLowerCase();
    if (tag === 'script' || tag === 'style') return '';
    kids = el.childNodes;
    for (i = 0; i < kids.length; i++) out += textWithoutCode(kids[i]);
    return out;
  }

  function assertMarkup() {
    var i, k, v, n;

    n = document.querySelectorAll('h1').length;
    check(n === 1, 'h1=' + n + ', want 1');

    var cs = document.querySelectorAll('[data-council]');
    if (cs.length) {
      var seen = {}, dup = [], miss = [], extra = [];
      for (i = 0; i < cs.length; i++) {
        k = norm(cs[i].getAttribute('data-council'));
        if (!k) check(false, 'empty data-council value');
        else if (has(seen, k)) dup.push(k); else seen[k] = 1;
      }
      for (i = 0; i < EXPECTED_SLUGS.length; i++) if (!has(seen, EXPECTED_SLUGS[i])) miss.push(EXPECTED_SLUGS[i]);
      for (k in seen) if (EXPECTED_SLUGS.indexOf(k) < 0) extra.push(k);
      check(cs.length === EXPECTED_SLUGS.length && !dup.length && !miss.length && !extra.length,
        'councils ' + cs.length + ' dup=' + dup + ' miss=' + miss + ' unknown=' + extra);
    }

    /* aria-label is banned ONLY where it would override VISIBLE ADDRESS TEXT,
       because on both pages an external link's visible text IS an address and
       the address is the verification affordance:

         sources.html .source-item__url  -> the full https:// URL, spelled out
         index.html   .council-item     -> the bare hostname (www.council.gov.uk)

       Both shapes are matched (isUrlText), so the guard survives the homepage
       showing a hostname rather than a full URL. Anchored at both ends, so
       prose that merely STARTS with something hostname-shaped -- "GOV.UK:
       find your local council", "GOV.UK council profile" -- is not flagged.
       A legitimate icon-only link (aria-label, no address text) is likewise
       unaffected. */
    var labelled = document.querySelectorAll('a[aria-label]');
    for (i = 0; i < labelled.length; i++) {
      if (isUrlText(labelled[i])) {
        check(false, 'aria-label overrides visible address text on "' +
          visibleText(labelled[i]).slice(0, 40) + '"');
      }
    }

    /* Asserted on a[href^="http"], NOT a[data-external]. Keying off the data
       attribute made this opt-in: an anchor that forgot the marker was never
       inspected, so it could ship with no rel, no target and no new-tab hint and
       the check stayed silent -- on the one page whose entire payload is
       external council URLs. data-external is now a STYLING hook only
       (.external-link, .icon-external); the three requirements apply to every
       off-site anchor whether or not it is marked. */
    var ex = document.querySelectorAll('a[href^="http"]'), rel, hint;
    for (i = 0; i < ex.length; i++) {
      rel = norm(ex[i].getAttribute('rel')).toLowerCase();
      hint = ex[i].querySelector('.visually-hidden');
      if (norm(ex[i].getAttribute('target')).toLowerCase() !== '_blank' ||
          rel.indexOf('noopener') < 0 || rel.indexOf('noreferrer') < 0 ||
          !hint || !norm(hint.textContent)) {
        check(false, 'a[href^=http] "' + norm(ex[i].textContent).slice(0, 30) +
          '": need target=_blank, rel noopener+noreferrer, .visually-hidden hint');
      }
    }

    /* THE PROVENANCE INVARIANT. On the sources page the council's URL IS the
       link text: a reviewer must be able to read the address on screen, copy
       it, and know where the link goes. visibleText() strips the new-tab hint
       and the icon, so the comparison is against what a person actually reads.

       Also asserts the "Open official source" button points at the same string,
       so the readable address and the button can never disagree. Nine
       comparisons on one page; there is no cheaper way to protect the single
       claim this whole site exists to support.

       Scoped to .source-item, which only exists on /sources.html. */
    var srcItems = document.querySelectorAll('.source-item');
    for (i = 0; i < srcItems.length; i++) {
      var urlA = srcItems[i].querySelector('.source-item__url a');
      var btnA = srcItems[i].querySelector('.source-item__actions .btn');
      var govA = srcItems[i].querySelector('.source-item__actions .external-link');
      var slug = norm(srcItems[i].getAttribute('data-source')) || ('#' + i);
      if (!urlA) { check(false, slug + ': no .source-item__url link'); continue; }
      var h = norm(urlA.getAttribute('href'));
      var t2 = visibleText(urlA);
      check(/^https?:\/\//i.test(h), slug + ': council URL is absolute, got "' + h + '"');
      check(t2 === h, slug + ': council URL text "' + t2 + '" != href "' + h + '"');
      check(!!btnA && norm(btnA && btnA.getAttribute('href')) === h,
        slug + ': "Open official source" href != ' + h);
      /* The GOV.UK profile is deliberately outside the drift comparison (it
         exists on this page only), so give it its own cheap shape check rather
         than no check at all. */
      check(!!govA && /^https:\/\/www\.gov\.uk\/find-local-council\//i.test(norm(govA && govA.getAttribute('href'))),
        slug + ': GOV.UK council profile href is malformed');
    }

    /* Checked on .disclaimer AND .site-footer__disclaimer: the footer repeats the
       sentence on every page and was otherwise unprotected, so it was the one
       place a well-meaning edit could soften the wording and trip nothing. */
    var ds = document.querySelectorAll('.disclaimer, .site-footer__disclaimer');
    for (i = 0; i < ds.length; i++) {
      k = norm(ds[i].textContent);
      check(k === DISCLAIMER, 'disclaimer: ' + k);
    }
    v = pageKind();
    /* The minimum counts BOTH carriers: a .disclaimer block and the footer's
       .site-footer__disclaimer repeat. Counting .disclaimer alone made the
       homepage minimum unsatisfiable -- the shipped homepage has exactly one
       aside plus one footer, so a minimum of 2 over .disclaimer alone could
       only be met by duplicating the statement into the page body, which is
       not what the disclosure is for. Google wants the sentence in the Play
       listing, not stamped under the hero.

       So the invariant is: every real page carries the sentence TWICE, once in
       a .disclaimer block and once in the footer. 404 has only the footer. */
    n = document.querySelectorAll('.disclaimer, .site-footer__disclaimer').length;
    var min = (v === 'home' || v === 'sources') ? 2 : 0;
    check(!min || n >= min, v + ' has ' + n + ' disclaimer statements (aside + footer), want ' + min);

    /* innerText, else the script/style-stripped walk above: an empty haystack
       would check nothing, and an unstripped textContent would check app.js
       against itself. */
    var t = String(document.body.innerText || textWithoutCode(document.body) || '').toLowerCase();
    for (i = 0; i < BANNED_PHRASES.length; i++) {
      check(t.indexOf(BANNED_PHRASES[i]) < 0, 'banned phrase: ' + BANNED_PHRASES[i]);
    }

    if (window.location.search.indexOf('driftcheck=1') !== -1 && v === 'home') runDriftCheck();
  }

  /* ------------------------------------------------------------------ boot

     initNav() and initSearch() are real features and always run.
     assertMarkup() is a development aid and is GATED: production hosts get
     nothing. Use http://localhost/... during development, or append ?dev=1 to
     any page to switch the checks on without a local server. */
  function devMode() {
    var h = String(window.location.hostname || '');
    /* The (?:&|$) matters: a bare substring test also matches ?dev=10. */
    return h === 'localhost' || h === '127.0.0.1' || h === '[::1]' ||
      /[?&]dev=1(?:&|$)/.test(String(window.location.search || ''));
  }

  initNav();
  initSearch();
  if (devMode()) assertMarkup();
}());
