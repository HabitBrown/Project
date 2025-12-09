// lib/services/habit_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';
import '../models/farmer.dart';
import '../screens/home/habit_setting.dart';

class HabitService {
  final _client = http.Client();

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// DateTime → "YYYY-MM-DD" 로 포맷
  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  // [1~7(월~일)] 요일 리스트 → 비트마스크 정수로 변환
  int _encodeDaysOfWeek(List<int> weekdays) {
    int mask = 0;
    for (final d in weekdays) {
      if (d < 1 || d > 7) continue;
      mask |= 1 << (d - 1);
    }
    return mask;
  }

  Future<Map<String, dynamic>> createHabit(HabitSetupData data) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }

    final uri = Uri.parse('$kBaseUrl/habits');

    String method;
    if (data.certType == CertType.photo) {
      method = 'photo';
    } else {
      method = 'text';
    }

    final body = <String, dynamic>{
      'title': data.title,
      'method': method,
      'days_of_week': _encodeDaysOfWeek(data.weekdays),
      'period_start': _formatDate(data.startDate),
      'period_end': _formatDate(data.endDate),
      'deadline_local': data.deadline,
      'difficulty': data.difficulty,
      'source_habit_id': null, // 혼자 습관 생성이므로 현재는 항상 null
    };

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded;
    } else {
      // 디버그용 로그
      // ignore: avoid_print
      print('습관 생성 실패: ${res.statusCode} ${res.body}');
      throw Exception('습관 생성 실패: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateHabit(
      int userHabitId, HabitSetupData data) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception('로그인이 필요합니다. (토큰 없음)');
    }

    final uri = Uri.parse('$kBaseUrl/habits/$userHabitId');

    // createHabit 이랑 동일한 로직으로 맞추기
    final method = data.certType == CertType.photo ? 'photo' : 'text';

    final body = <String, dynamic>{
      'title': data.title,
      'method': method,
      'days_of_week': _encodeDaysOfWeek(data.weekdays),   // 🔴 여기 고정
      'period_start': _formatDate(data.startDate),
      'period_end': _formatDate(data.endDate),
      'deadline_local': data.deadline,
      'difficulty': data.difficulty,
      'source_habit_id': null, // 지금은 항상 혼자 습관이니까 null
    };

    final res = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    // 디버그용 로그
    // ignore: avoid_print
    print('UPDATE /habits/$userHabitId => ${res.statusCode} ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('습관 수정 실패: ${res.statusCode} ${res.body}');
    }

    if (res.body.isEmpty) {
      // 혹시 200인데 body가 비어 있으면 그냥 빈 맵 돌려줌
      return <String, dynamic>{};
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
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



  Future<void> evaluateHabits() async {
    final token = await _getAccessToken();
    if (token == null) throw Exception("로그인 필요");

    final uri = Uri.parse('$kBaseUrl/habits/evaluate');

    final resp = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('습관 평가 실패: ${resp.statusCode} ${resp.body}');
    }
  }



}
