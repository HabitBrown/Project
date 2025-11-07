import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/base_url.dart';

class AuthService {
  final _client = http.Client();

  Future<bool> checkNickname(String nickname) async{
    try{
      final uri = Uri.parse('$kBaseUrl/auth/nicknames/check').replace(queryParameters: {'nickname': nickname});
      final res = await _client.get(uri);

      if(res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['available'] == true;
      }
      else{
        print('닉네임 중복 체크 실패: ${res.statusCode}');
        return false;
      }
    } catch (e){
      print('닉네임 중복 체크 오류: $e');
      return false;
    }
  }
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('$kBaseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'name': name,
      }),
    );
    if (res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception(_safe(res.body, fallback: '회원가입 실패'));
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('$kBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('access_token', data['access_token']);
      await prefs.setInt('user_id', data['user']['id']);

      final user = data['user'] as Map<String, dynamic>;
      final nickname = (user['nickname'] ?? '').toString();
      final name = (user['name'] ?? '').toString();
      await prefs.setString('nickname', nickname);
      await prefs.setString('name', name);

      return data;
    }
    throw Exception(_safe(res.body, fallback: '로그인 실패'));
  }

  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? name,
    String? nickname,
    String? gender,
    int? age,
    String? bio,
    String? profilePicture,
  }) async
  {

    /// 단일 사용자 정보 조회
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (nickname != null) body['nickname'] = nickname;
    if (gender != null) body['gender'] = gender;
    if (age != null) body['age'] = age;
    if (bio != null) body['bio'] = bio;
    if (profilePicture != null) body['profile_picture'] = profilePicture;

    final res = await _client.put(
      Uri.parse('$kBaseUrl/auth/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception(_safe(res.body, fallback: '프로필 저장 실패'));
  }
  Future<Map<String, dynamic>> getUser(int userId) async {
    final res = await _client.get(
      Uri.parse('$kBaseUrl/auth/users/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception(_safe(res.body, fallback: '사용자 정보 조회 실패'));
  }

  String _safe(String raw, {String fallback = '요청 실패'}) {
    try {
      final m = jsonDecode(raw);
      if (m is Map && m['detail'] != null) return m['detail'].toString();
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}
