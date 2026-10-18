/**
 * Report intake for the Derby Bin Collection app.
 *
 * The app POSTs JSON to the Vercel /api/report proxy, which forwards it here;
 * doPost appends one row per report to a private Google Sheet. The 302
 * redirect Apps Script returns for /exec POSTs is expected — the proxy follows
 * it (POST -> GET conversion) and only checks the status code.
 *
 * Deploy:
 *   1. Paste this file into Code.gs of the existing script project
 *      (script.google.com -> the project that owns your /exec URL).
 *   2. Project Settings -> Script properties -> add
 *      SPREADSHEET_ID = <id from your sheet URL:
 *      https://docs.google.com/spreadsheets/d/<ID>/edit>
 *      Keep the real ID out of source control.
 *   3. Deploy -> New deployment -> Web app:
 *        Execute as:     Me
 *        Who has access: Anyone
 *   4. Copy the /exec URL -> set REPORT_SCRIPT_URL in Render.
 *   5. After any edit: Deploy -> Manage deployments -> New version, and
 *      re-copy the /exec URL if it changed.
 *
 * Sheet: row 1 must be the header row (clear the sheet or add headers if it
 * already has data). Column order is fixed — the header row written on an
 * empty sheet is ['timestamp'].concat(HEADERS) and the data row is built
 * from the same list, so they cannot drift apart:
 *   timestamp, name, email, issueType, description, address, council, postcode
 */

var SHEET_NAME = 'DerbyReports';

var HEADERS = ['name', 'email', 'issueType', 'description', 'address', 'council', 'postcode'];

function getSpreadsheet() {
  var id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) {
    throw new Error('SPREADSHEET_ID script property is not set');
  }
  return SpreadsheetApp.openById(id);
}

function doGet() {
  return ContentService.createTextOutput(JSON.stringify({ ok: true }))
      .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  var data = {};
  if (e && e.postData && e.postData.contents) {
    try {
      data = JSON.parse(e.postData.contents) || {};
    } catch (err) {
      data = {};
    }
  }
  if (typeof data !== 'object' || Array.isArray(data)) {
    data = {};
  }

  // Force text on cell values: a leading = + - @ or tab can otherwise be
  // interpreted as a formula by the sheet (formula/CSV injection via the
  // public /exec URL). The leading apostrophe is invisible in Sheets.
  // Note: the apostrophe is stored in the cell, so CSV/API exports show "'=…";
  // that is expected — the sheet UI displays the value without it.
  var clean = function (v) {
    v = typeof v === 'string' ? v.trim() : '';
    return /^[=+\-@\t\r]/.test(v) ? "'" + v : v;
  };

  // Direct/bot hits with no parseable body: acknowledge without appending.
  if (Object.keys(data).length === 0) {
    return ContentService.createTextOutput(JSON.stringify({ ok: false, error: 'bad_request' }))
        .setMimeType(ContentService.MimeType.JSON);
  }

  // Defense-in-depth: mirror the proxy's required fields for direct hits.
  if (!clean(data.name) || !clean(data.email)) {
    return ContentService.createTextOutput(JSON.stringify({ ok: false, error: 'bad_request' }))
        .setMimeType(ContentService.MimeType.JSON);
  }

  var row = [
    Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss')
  ].concat(HEADERS.map(function (h) {
    return clean(data[h]);
  }));

  try {
    var ss = getSpreadsheet();
    var sheet = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(['timestamp'].concat(HEADERS));
    }
    sheet.appendRow(row);
  } catch (err) {
    // Do not leak config details (e.g. unset SPREADSHEET_ID) to callers.
    return ContentService.createTextOutput(JSON.stringify({ ok: false, error: 'misconfigured' }))
        .setMimeType(ContentService.MimeType.JSON);
  }

  return ContentService.createTextOutput(JSON.stringify({ ok: true }))
      .setMimeType(ContentService.MimeType.JSON);
}
