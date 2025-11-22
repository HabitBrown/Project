// lib/services/certification_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/base_url.dart';

class CertificationService {
  final _client = http.Client();

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> createTextCertification(
      {required int userHabitId, required String textContent,}) async {
    final token = await _getAccessToken();
    if (token == null) throw Exception("로그인 토큰이 없습니다.");

    final uri = Uri.parse('$kBaseUrl/certifications');
    final body = jsonEncode({
      "user_habit_id": userHabitId,
      "method": "text",
      "text_content": textContent,
    });

    final resp = await _client.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );

    if (resp.statusCode != 201) {
      throw Exception("인증 실패: ${resp.statusCode} ${resp.body}");
    }
  }

  Future<int> uploadPhoto(File file) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception("로그인 토큰이 없습니다.");
    }

    final uri = Uri.parse('$kBaseUrl/media/upload');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 201) {
      throw Exception("사진 업로드 실패: ${resp.statusCode} ${resp.body}");
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    // 백엔드에서 MediaAssetOut(id, storage_url, created_at) 리턴한다고 가정
    return data['id'] as int;
  }

  /// 2단계: 업로드된 사진의 id로 인증 생성
  Future<void> createPhotoCertification({
    required int userHabitId,
    required int photoAssetId,
  }) async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception("로그인 토큰이 없습니다.");
    }

    final uri = Uri.parse('$kBaseUrl/certifications');
    final body = jsonEncode({
      "user_habit_id": userHabitId,
      "method": "photo",
      "photo_asset_id": photoAssetId,
    });

    final resp = await _client.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );

    if (resp.statusCode != 201) {
      throw Exception("사진 인증 실패: ${resp.statusCode} ${resp.body}");
    }
  }

  Future<Set<int>> fetchTodayCertifiedHabitIds() async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception("로그인 토큰이 없습니다.");
    }

    final uri = Uri.parse('$kBaseUrl/certifications/today/habits');

    final resp = await _client.get(
      uri,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (resp.statusCode != 200) {
      throw Exception(
          "오늘 인증한 습관 조회 실패: ${resp.statusCode} ${resp.body}");
    }

    final data = jsonDecode(resp.body) as List<dynamic>;
    // [1, 3, 7] 이런 리스트라고 가정
    return data.map((e) => e as int).toSet();
  }
}
