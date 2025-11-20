// lib/services/potato_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';
import '../models/farmer.dart';

class PotatoService {
  final _client = http.Client();

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<List<FarmerSummary>> fetchFarmers() async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }

    final uri = Uri.parse('$kBaseUrl/potato/farmers');

    final res = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;
      return jsonList
          .map((e) => FarmerSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        '추천 농부 조회 실패: ${res.statusCode} ${res.body}');
    }
  }
  /// 팔로우
  Future<void> followFarmer(int userId) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }

    // ⚠ 만약 백엔드가 phone을 path로 쓰면 여기 바꿔야 함
    final uri = Uri.parse('$kBaseUrl/potato/farmers/$userId/follow');

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('팔로우 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// 언팔로우
  Future<void> unfollowFarmer(int userId) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }

    // ⚠ 마찬가지로 phone 기반이면 여기 경로 수정
    final uri = Uri.parse('$kBaseUrl/potato/farmers/$userId/follow');

    final res = await _client.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('언팔로우 실패: ${res.statusCode} ${res.body}');
    }
  }

}
