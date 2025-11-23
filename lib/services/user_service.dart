// lib/services/user_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
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

  /// 3) 마이페이지용: 프로필 수정
  Future<void> updateMyProfile({
    String? nickname,
    String? bio,
    int? age,
    String? gender,
    List<int>? interestIds, // ← 나중에 관심사 ID까지 관리하고 싶으면 사용
  }) async {
    final token = await _getAccessToken();
    final userId = await _getUserId();
    if (token == null || userId == null) {
      throw Exception('로그인 정보 없음');
    }

    final uri = Uri.parse('$kBaseUrl/users/$userId/profile');

    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (bio != null) body['bio'] = bio;
    if (age != null) body['age'] = age;
    if (gender != null) body['gender'] = gender;
    if (interestIds != null) body['interests'] = interestIds;

    final res = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('프로필 수정 실패: ${res.statusCode} ${res.body}');
    }
  }

  /// 4) 프로필 이미지 업로드
  Future<String> uploadProfileImage(File file) async {
    final token = await _getAccessToken();
    final userId = await _getUserId();

    if (token == null || userId == null) {
      throw Exception('로그인 정보가 없습니다. 다시 로그인해 주세요.');
    }

    final uri = Uri.parse('$kBaseUrl/users/$userId/profile-picture');

    // 파일명 / 확장자 추출
    final path = file.path;
    final filename = path.split(Platform.pathSeparator).last;
    final ext = filename.split('.').last.toLowerCase();

    MediaType contentType;
    if (ext == 'png') {
      contentType = MediaType('image', 'png');
    } else if (ext == 'webp') {
      contentType = MediaType('image', 'webp');
    } else {
      // 기본 jpeg
      contentType = MediaType('image', 'jpeg');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',        // ★ FastAPI의 파라미터 이름과 동일해야 함
          file.path,
          filename: filename,
          contentType: contentType,
        ),
      );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 201 || res.statusCode == 200) {
      final Map<String, dynamic> jsonMap = jsonDecode(res.body);

      final String? profilePic = jsonMap['profile_picture'] as String?;
      if (profilePic == null || profilePic.isEmpty) {
        throw Exception('프로필 이미지 경로가 응답에 없습니다. body=${res.body}');
      }

      return profilePic; // 예: "/uploads/profile/xxx.jpg"
    } else {
      // ★ 디버깅용으로 서버가 보낸 에러 메시지를 그대로 보게
      throw Exception('프로필 이미지 업로드 실패: ${res.statusCode} ${res.body}');
    }
  }
}
