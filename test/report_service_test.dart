import 'dart:io';

import 'package:derby_bins/services/council_api.dart';
import 'package:derby_bins/services/report_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the URL contract between the Dart client and the deployed backend.
///
/// This file exists because of a real bug. `ReportService` posted to
/// `/api/report`, the backend mounted `/report`, and every submission since
/// shipped returned 404 — surfaced to the user as a bare `ReportFailure` with
/// no diagnostic, so no missed-bin report has ever reached the sheet. Derby had
/// no test for `ReportService` at all, which is precisely how that survived
/// release.
///
/// The fix is one character, and a fix that small is one that gets "corrected"
/// back by the next person who assumes `/api/*` is the convention. So the
/// assertion here is not "the path is `/report`" — that would just re-encode
/// today's answer. It is: **the path the client uses must be a key in the
/// route map the server actually ships.** Both halves of the contract are
/// checked, and both expected paths are derived from server source at test
/// time rather than hardcoded, so the client cannot drift from the server
/// again without a failure here.
///
/// `submit()` itself is deliberately not exercised. It uses a top-level
/// `http.post` against a live Render host with no injectable client, and a
/// test that reaches the network is a test that fails for reasons unrelated to
/// this contract.
void main() {
  group('server route map', () {
    late String indexSource;
    late Set<String> routes;

    setUpAll(() {
      final indexJs =
          File(_joinPath(_packageRoot(), 'proxy', 'api', 'index.js'));
      expect(
        indexJs.existsSync(),
        isTrue,
        reason: 'proxy/api/index.js not found at ${indexJs.path}. The route '
            'IS the contract this file checks; without it there is nothing to '
            'check against, and every test below would pass vacuously.',
      );
      indexSource = indexJs.readAsStringSync();
      routes = _routeMapKeysIn(indexSource);
    });

    test('parses to a non-empty route map', () {
      // The tripwire that keeps the other tests honest. If someone reformats
      // index.js and the extraction regex stops matching, `routes` becomes
      // empty and every membership assertion below would pass for the wrong
      // reason — a silent green over a test that no longer tests anything.
      expect(
        routes,
        isNotEmpty,
        reason: 'Extracted ZERO keys from the handlers map in index.js. The '
            "regex expects quoted keys in a 'const handlers = {...};' block. "
            'Teach this file how the new shape is written rather than letting '
            'the route assertions go vacuous.',
      );
    });

    test('mounts /report, /bins and /addresses', () {
      expect(
        routes,
        containsAll(<String>['/report', '/bins', '/addresses']),
        reason: 'The backend mounts ${_sorted(routes)}, but the client and the '
            "server's own root handler both assume /report, /bins and "
            '/addresses exist. Either a route was renamed or one is missing.',
      );
    });

    test("the root handler advertises exactly what it mounts", () {
      // index.js describes itself at `/` with an endpoints array. That array is
      // the server's own statement of what is routable, and it is what made
      // this bug diagnosable in the first place — a lone 404 does not tell
      // you the path is merely wrong. Keeping it equal to the route map means
      // the server cannot quietly contradict itself either.
      final advertised = _advertisedEndpointsIn(indexSource);
      expect(
        advertised,
        isNotEmpty,
        reason: 'Found no endpoints array in the root handler. The self-'
            'description this cross-check reads is gone.',
      );
      expect(
        advertised.difference(routes),
        isEmpty,
        reason: 'The root handler advertises ${_sorted(advertised)} but only '
            '${_sorted(routes)} are routable. A client trusting the '
            'advertisement would call a path that 404s.',
      );
    });
  });

  group('ReportService.endpoint', () {
    test('is a route the deployed server actually mounts', () {
      // The regression itself. ReportService.endpoint is '/report' today; if it
      // ever becomes '/api/report' again this fails with the route map in
      // plain sight, which is the whole point.
      final routes = _routeMapKeysIn(
        File(_joinPath(_packageRoot(), 'proxy', 'api', 'index.js'))
            .readAsStringSync(),
      );
      expect(
        routes,
        contains(ReportService.endpoint),
        reason: 'ReportService posts to "${CouncilApi.proxyBaseUrl}'
            '${ReportService.endpoint}", but index.js mounts '
            '${_sorted(routes)}. A POST to that URL returns '
            '404 {"error":"Not found"} and the submission is lost.',
      );
    });

    test("is not prefixed with Vercel's /api convention", () {
      // Named after the exact regression rather than folded into the check
      // above, so a failure here names the thing someone is about to
      // "helpfully" restore. This backend is a plain Node http server on
      // Render that mounts handlers at the root; '/api' is Vercel's
      // serverless convention and means nothing to it.
      expect(
        ReportService.endpoint,
        isNot(startsWith('/api')),
        reason: "'/api' is Vercel's serverless prefix. proxy/api/index.js "
            'serves handlers at the root and advertises '
            "{'/bins', '/addresses', '/report'}, so "
            "'/api${ReportService.endpoint}' is a 404 and every report is "
            'silently dropped.',
      );
    });
  });

  group('CouncilApi', () {
    test('proxyBaseUrl is a bare origin, so paths append at the root', () {
      // The client builds URLs by string concatenation, so any path baked
      // into proxyBaseUrl would sit in front of the route map keys and 404
      // everything. This is the other half of the same contract.
      final base = Uri.parse(CouncilApi.proxyBaseUrl);
      expect(
        base.hasScheme && base.scheme == 'https',
        isTrue,
        reason: 'proxyBaseUrl "${CouncilApi.proxyBaseUrl}" is not https.',
      );
      expect(
        base.path.isEmpty || base.path == '/',
        isTrue,
        reason: 'proxyBaseUrl "${CouncilApi.proxyBaseUrl}" carries a path '
            '("${base.path}"). Handlers are mounted at the root, so this would '
            'produce ${CouncilApi.proxyBaseUrl}/report -> "${base.path}'
            '${ReportService.endpoint}", which is not routed.',
      );
      expect(
        base.hasQuery || base.hasFragment,
        isFalse,
        reason: 'proxyBaseUrl "${CouncilApi.proxyBaseUrl}" carries a query or '
            'fragment; appended paths would land somewhere unrouted.',
      );
    });

    test('every path council_api.dart appends to proxyBaseUrl is routed', () {
      // Derived from the client source rather than hardcoded to '/bins', so
      // changing council_api.dart to a wrong path fails here even though the
      // bins path was never the bug.
      final clientSource = File(
        _joinPath(_packageRoot(), 'lib', 'services', 'council_api.dart'),
      ).readAsStringSync();
      final paths = _proxyPathsIn(clientSource);

      expect(
        paths,
        isNotEmpty,
        reason: 'Extracted ZERO paths of the form \$proxyBaseUrl/<path> from '
            'council_api.dart. The extraction has stopped matching how the '
            'client builds its URLs; the assertion below would pass vacuously.',
      );

      final routes = _routeMapKeysIn(
        File(_joinPath(_packageRoot(), 'proxy', 'api', 'index.js'))
            .readAsStringSync(),
      );

      expect(
        paths.difference(routes),
        isEmpty,
        reason: 'council_api.dart calls ${_sorted(paths)}, but index.js mounts '
            '${_sorted(routes)}. Anything unrouted 404s and the client '
            'degrades to empty results, which reads as "no data" rather than '
            '"wrong URL".',
      );
    });

    test('the bins path council_api.dart uses is /bins', () {
      // Pins the actual value the route-map check above cannot pin on its own.
      final paths = _proxyPathsIn(
        File(_joinPath(_packageRoot(), 'lib', 'services', 'council_api.dart'))
            .readAsStringSync(),
      );
      expect(paths, contains('/bins'));
    });
  });
}

/// The package root, found by walking up from the working directory.
///
/// Anchored on [Directory.current], which `flutter test` runs at the package
/// root, then searching upwards so the file is still found if the suite is ever
/// driven from a subdirectory. [Platform.script] is deliberately NOT used:
/// under `flutter test` it resolves to the app entrypoint (lib/main.dart)
/// rather than to this test file. The search terminates at the filesystem root
/// and throws rather than returning a guess, because a wrong root would make
/// every file read below throw anyway, and a clear error beats a confusing one.
Directory _packageRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 8; depth++) {
    if (File(_joinPath(dir.path, 'proxy', 'api', 'index.js')).existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'Could not find proxy/api/index.js searching upwards from '
    '${Directory.current.path}. These tests exist to keep the client pointed '
    'at the server that is actually deployed; they cannot run without it and '
    'must fail loudly rather than pass vacuously.',
  );
}

String _joinPath(String root, String a, String b, String c) =>
    '$root${Platform.pathSeparator}$a${Platform.pathSeparator}'
    '$b${Platform.pathSeparator}$c';

/// The `const handlers = { ... };` block in index.js. Non-greedy up to the
/// closing brace so the extraction cannot run past the map into unrelated
/// object literals further down the file.
final _handlersBlock =
    RegExp(r'const\s+handlers\s*=\s*\{(.*?)\};', dotAll: true);

/// A quoted path key in that map, e.g. the `'/report'` in
/// `'/report': reportHandler`. Values are deliberately not captured: only the
/// paths are the contract.
final _routeKey = RegExp(r"""['"](/[A-Za-z0-9/_\-]*)['"]\s*:""");

/// The `endpoints` array the root handler advertises at `/`.
final _endpointsArray = RegExp(r'endpoints\s*:\s*\[([^\]]*)\]');

final _quotedPath = RegExp(r"""['"](/[A-Za-z0-9/_\-]*)['"]""");

/// Matches the `/bins` in `Uri.parse('$proxyBaseUrl/bins')`. Anchored on the
/// interpolation rather than on a call shape, so it survives the client
/// switching between `Uri.parse('$proxyBaseUrl/bins')` and
/// `Uri.parse('$proxyBaseUrl/bins').replace(...)`.
final _proxyPath = RegExp(r'''\$proxyBaseUrl(/\*?[A-Za-z0-9/_\-]*)''');

/// Every route the server mounts, as a distinct set.
Set<String> _routeMapKeysIn(String source) {
  final block = _handlersBlock.firstMatch(source);
  if (block == null) return <String>{};
  return block
      .group(1)!
      .split('\n')
      .map((line) => _routeKey.firstMatch(line)?.group(1))
      .whereType<String>()
      .toSet();
}

/// Every path the server's root handler says it serves.
Set<String> _advertisedEndpointsIn(String source) {
  final block = _endpointsArray.firstMatch(source);
  if (block == null) return <String>{};
  return _quotedPath
      .allMatches(block.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}

/// Every distinct path the client appends to `proxyBaseUrl`.
Set<String> _proxyPathsIn(String clientSource) => _proxyPath
    .allMatches(clientSource)
    .map((m) => m.group(1)!)
    .where((p) => p.isNotEmpty && p != '/')
    .toSet();

/// Sorted for reproducible failure messages.
List<String> _sorted(Iterable<String> items) => items.toList()..sort();
