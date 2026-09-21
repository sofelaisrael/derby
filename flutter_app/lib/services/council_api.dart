import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bin_schedule.dart';

/// API client for the Derby proxy backend.
class CouncilApi {
  final String baseUrl;
  final http.Client _client;

  CouncilApi({this.baseUrl = 'http://localhost:3000', http.Client? client})
      : _client = client ?? http.Client();

  /// Look up addresses for a postcode.
  Future<List<Map<String, String>>> lookupAddresses(String postcode) async {
    final uri = Uri.parse('$baseUrl/api/addresses').replace(
      queryParameters: {'postcode': postcode},
    );

    final response = await _client.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Connection timed out'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to look up addresses (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    final addresses = (data['addresses'] as List? ?? [])
        .map((a) => Map<String, String>.from(a))
        .toList();

    return addresses;
  }

  /// Fetch collection schedule for a UPRN.
  Future<CollectionSchedule> fetchSchedule({
    required String uprn,
    required String council,
  }) async {
    final uri = Uri.parse('$baseUrl/api/bins').replace(
      queryParameters: {'uprn': uprn, 'council': council},
    );

    final response = await _client.get(uri).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw ApiException('Connection timed out'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch schedule (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    return CollectionSchedule.fromJson(data);
  }

  /// Report a missed collection.
  Future<bool> reportMissed({
    required String uprn,
    required String council,
    required String wasteType,
    required String reason,
  }) async {
    final uri = Uri.parse('$baseUrl/api/report');
    final body = jsonEncode({
      'uprn': uprn,
      'council': council,
      'wasteType': wasteType,
      'reason': reason,
    });

    final response = await _client
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw ApiException('Connection timed out'),
        );

    return response.statusCode == 200;
  }
}

/// Custom API exception.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
