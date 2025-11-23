// lib/services/duel_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';
import '../screens/home/habit_setting.dart';
import '../screens/home/hash_screen.dart' show RivalInfo;

class DuelService {
  final _client = http.Client();

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<List<RivalInfo>> fetchActiveDuels() async {
    final token = await _token();
    if (token == null) throw Exception("로그인 필요");

    final uri = Uri.parse('$kBaseUrl/duels/active');

    final res = await _client.get(
      uri,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("듀얼 조회 실패: ${res.body}");
    }

    final List<dynamic> decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map((e) => RivalInfo.fromJson(e))
        .toList();
  }

  Future<bool> createDuelFromExchange({
    required int exchangeRequestId,
    required int opponentUserHabitId,
    required HabitSetupData setup,
  }) async {
    final token = await _token();
    final uri = Uri.parse('$kBaseUrl/duels/from-exchange');

    final body = {
      'exchange_request_id': exchangeRequestId,
      'opponent_user_habit_id': opponentUserHabitId,
      'start_date': setup.startDate.toIso8601String().split('T').first,
      'end_date': setup.endDate.toIso8601String().split('T').first,
      'days_of_week': setup.weekdays,
      'deadline_local': setup.deadline + ':00',
      'difficulty': setup.difficulty,
      'method': setup.certType.name,
    };

    final res = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return res.statusCode == 200 || res.statusCode == 201;
  }
}
