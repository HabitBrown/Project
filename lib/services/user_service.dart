// lib/services/user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';
import '../models/interest.dart';

class UserService {
  final _client = http.Client();

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  /// 1) 관심사 전체(모델) 조회
  Future<UserInterestsResponse> fetchMyInterests() async {
    final token = await _getAccessToken();
    final userId = await _getUserId();

    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }
    if (userId == null) {
      throw Exception('유저 ID를 찾을 수 없습니다. 다시 로그인 해주세요.');
    }

    final uri = Uri.parse('$kBaseUrl/users/$userId/interests');

    final res = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      return UserInterestsResponse.fromJson(jsonMap);
    } else {
      throw Exception('유저 관심사 불러오기 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// 2) 마이페이지용: 관심사 이름 리스트만 간단히 가져오기
  Future<List<String>> fetchMyInterestNames() async {
    final resp = await fetchMyInterests();
    return resp.interests.map((e) => e.name).toList();
  }
}
