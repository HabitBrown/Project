import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';
import '../models/farmer.dart';
import '../screens/home/habit_setting.dart';  // HabitSetupData

class ExchangeService {
  final _client = http.Client();

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> sendExchangeRequest(HabitSetupData data, int targetHabitId) async {
    final token = await _token();
    if (token == null) throw Exception("로그인 필요");

    final uri = Uri.parse('$kBaseUrl/exchange-requests');

    final body = {
      "target_habit_id": targetHabitId,
      "weekdays": data.weekdays,
      "start_date": data.startDate.toIso8601String().split('T').first,
      "end_date": data.endDate.toIso8601String().split('T').first,
      "deadline": data.deadline,        // "23:59" 또는 "21:30"
      "difficulty": data.difficulty,    // 1~5
      "method": data.certType == CertType.photo ? "photo" : "text",
    };

    final res = await _client.post(
      uri,
      body: jsonEncode(body),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 201) {
      throw Exception("교환 요청 실패: ${res.body}");
    }
  }
}
