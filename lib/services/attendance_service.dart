// lib/services/attendance_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/base_url.dart';

class AttendanceResult {
  final bool alreadyChecked;
  final int todayReward;
  final int streak;
  final int hbBalance;
  final bool isSevenDayReward;

  AttendanceResult({
    required this.alreadyChecked,
    required this.todayReward,
    required this.streak,
    required this.hbBalance,
    required this.isSevenDayReward,
  });

  factory AttendanceResult.fromJson(Map<String, dynamic> json) {
    return AttendanceResult(
      alreadyChecked: json['already_checked'] as bool? ?? false,
      todayReward: json['today_reward'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      hbBalance: json['hb_balance'] as int? ?? 0,
      isSevenDayReward: json['is_seven_day_reward'] as bool? ?? false,
    );
  }
}

class AttendanceService {

  Future<AttendanceResult> checkIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final uri = Uri.parse('$kBaseUrl/attendance/check-in');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('출석체크 실패: ${res.statusCode} / ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final result = AttendanceResult.fromJson(data);

    // 서버에서 갱신된 hb_balance를 로컬에도 저장
    await prefs.setInt('hb_balance', result.hbBalance);

    return result;
  }
}
