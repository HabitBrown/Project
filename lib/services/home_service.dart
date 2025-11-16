// lib/services/home_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';
import '../models/home_summary.dart';

class HomeService {
  final _client = http.Client();

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<HomeSummary> fetchSummary() async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }

    final uri = Uri.parse('$kBaseUrl/home/summary');

    final res = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      return HomeSummary.fromJson(jsonMap);
    } else {
      throw Exception('홈 요약 불러오기 실패: ${res.statusCode}');
    }
  }
}
