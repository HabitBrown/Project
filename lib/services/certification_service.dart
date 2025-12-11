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
    if (token == null) throw Exception("로그인 토큰이 없습니다.");

    final uri = Uri.parse('$kBaseUrl/certifications/today/habits');

    final resp = await _client.get(
      uri,
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    // 1) 클라이언트 시간 (KST / UTC)
    final nowLocal = DateTime.now();
    final nowUtc = DateTime.now().toUtc();

    // 2) 서버 시간 (HTTP Date 헤더)
    final serverDateHeader = resp.headers['date'];
    DateTime? serverNow;
    if (serverDateHeader != null) {
      try {
        serverNow = HttpDate.parse(serverDateHeader); // dart:io
      } catch (e) {
        print('⚠ server date parse error: $e / header=$serverDateHeader');
      }
    }

    // 3) 로그 출력
    print('===== [CertificationService] /today/habits =====');
    print('client now local : $nowLocal');
    print('client now UTC   : $nowUtc');

    if (serverNow != null) {
      print('server now (UTC): $serverNow');
      print('server-client diff (UTC): ${serverNow.difference(nowUtc)}');
    } else {
      print('server date header NOT FOUND');
    }

    if (resp.statusCode != 200) {
      print('resp.body = ${resp.body}');
      throw Exception("오늘 인증한 습관 조회 실패: ${resp.statusCode} ${resp.body}");
    }

    print('todayCertified raw: ${resp.body}');

    final data = jsonDecode(resp.body) as List<dynamic>;
    final ids = data.map((e) => e as int).toSet();

    print('todayCertified ids: $ids');
    print('================================================');

    return ids;
  }}


