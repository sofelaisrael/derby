'use strict';

// Fixture loader for the driver regression suite.
//
// A fixture directory is `test/fixtures/<slug>/` containing:
//   fixtures.json      - an array of envelopes (see below)
//   <body files>       - referenced from the envelopes via `bodyFile`
//
// Envelope shape:
//   slug        driver slug; `../lib/drivers/<slug>` must exist
//   case        unique-per-slug case name, used as the test name
//   entry       an `_`-prefixed pure export on that driver
//   bodyFile    path to the driver input, resolved relative to this directory
//   bodyKind    "json" (parsed) or "text" (raw string, for HTML fixtures)
//   now         ISO local date/time string, always supplied so no fixture ever
//               reads the system clock
//   source      provenance; "synthetic" marks a hand-written minimal input that
//               is NOT a live council recording
//   expect      streams / byStream / labels expectations
//
// `bodyFile` paths are resolved relative to `test/fixtures/` (this directory),
// NOT relative to the slug directory.
//
// NOTE ON PROVENANCE: no fixture here is a recorded council response. There was
// no network access to the AVBC / NED / Bolsover / Derbyshire Dales / Derby
// endpoints when these were written, so every body file is a minimal synthetic
// input shaped to the driver's parsing contract. Each carries a `source.kind`
// of "synthetic" plus the URL to replace it with. Treat a fixture as a contract
// test of the parser, never as evidence about a council's real payload.

const fs = require('fs');
const path = require('path');

const FIXTURE_ROOT = __dirname;

function listSlugDirs() {
  return fs
    .readdirSync(FIXTURE_ROOT, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .filter((name) =>
      fs.existsSync(path.join(FIXTURE_ROOT, name, 'fixtures.json')))
    .sort();
}

const SLUGS = listSlugDirs();

function loadCases(slug) {
  const file = path.join(FIXTURE_ROOT, slug, 'fixtures.json');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function loadBody(envelope) {
  const file = path.join(FIXTURE_ROOT, envelope.bodyFile);
  const raw = fs.readFileSync(file, 'utf8');
  return envelope.bodyKind === 'json' ? JSON.parse(raw) : raw;
}

/// The drivers the fixture suite covers. Every slug here must be a real driver,
/// and every driver here must have at least one case.
const CASES = SLUGS.flatMap(loadCases);

function oneYearFrom(now) {
  return new Date(now.getFullYear() + 1, now.getMonth(), now.getDate());
}

/// Runs one fixture through its driver's named pure export and returns the
/// resulting collection groups (the 4-field wire contract).
function runFixture(envelope) {
  const driver = require(path.join(FIXTURE_ROOT, '..', '..', 'lib', 'drivers', envelope.slug));
  const entry = driver[envelope.entry];
  if (typeof entry !== 'function') {
    throw new Error(`${envelope.slug} does not export ${envelope.entry} as a function`);
  }
  const now = new Date(envelope.now);
  if (isNaN(now.getTime())) {
    throw new Error(`${envelope.slug}/${envelope.case}: bad now "${envelope.now}"`);
  }
  return entry(loadBody(envelope), now, oneYearFrom(now));
}

module.exports = { SLUGS, CASES, loadCases, loadBody, runFixture, oneYearFrom };