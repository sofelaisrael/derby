import 'dart:convert';
import 'package:http/http.dart' as http;
import 'council_api.dart'; // for proxyBaseUrl

/// Result of a report submission.
sealed class ReportResult {}

class ReportSuccess extends ReportResult {}

class ReportFailure extends ReportResult {}

class ReportService {
  static const _endpoint = '/api/report';

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
            Uri.parse('${CouncilApi.proxyBaseUrl}$_endpoint'),
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
