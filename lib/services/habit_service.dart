// lib/services/habit_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';

class HabitService {
  final _client = http.Client();

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// 마이페이지용: 완료된 습관의 제목 리스트만 가져오기
  Future<List<String>> fetchCompletedHabitTitles() async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }

    final uri = Uri.parse('$kBaseUrl/habits/me/completed');

    final res = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final jsonList = jsonDecode(res.body) as List<dynamic>;

      // 백엔드 응답은 배열 형태라고 가정:
      // [
      //   { "user_habit_id": 3, "title": "...", "method": "...", ... },
      //   ...
      // ]
      return jsonList
          .map((e) => (e as Map<String, dynamic>)['title'].toString())
          .toList();
    } else {
      throw Exception('완료된 습관 불러오기 실패: ${res.statusCode}');
    }
  }
}
