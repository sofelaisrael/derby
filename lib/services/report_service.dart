import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'council_api.dart'; // for proxyBaseUrl

/// Result of a report submission.
sealed class ReportResult {}

class ReportSuccess extends ReportResult {}

class ReportFailure extends ReportResult {}

class ReportService {
  // Root-mounted, not '/api/report'. The backend is proxy/api/index.js on
  // Render and serves handlers at the root; its own index advertises
  // ['/bins', '/addresses', '/report']. The '/api' prefix is Vercel's
  // serverless convention, which this backend does not use.
  //
  // Public only so test/report_service_test.dart can hold this against the
  // server's real route map. Still const: the path is a fact about the
  // backend, not a knob.
  @visibleForTesting
  static const String endpoint = '/report';

  /// Submits a report to the proxy, which forwards it to the Apps Script
  /// sheet endpoint. Returns [ReportSuccess] or [ReportFailure].
  static Future<ReportResult> submit({
    required String name,
    required String email,
    String issueType = '',
    required String description,
    String address = '',
    String council = '',
    String postcode = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${CouncilApi.proxyBaseUrl}$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              'email': email.trim(),
              'issueType': issueType.trim(),
              'description': description.trim(),
              'address': address.trim(),
              'council': council.trim(),
              'postcode': postcode.trim(),
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ReportSuccess();
      }
      return ReportFailure();
    } catch (_) {
      return ReportFailure();
    }
  }
}
