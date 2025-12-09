// lib/screens/home/profile_setting.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import 'home_screen.dart' show AppColors;
// 🔹 서버 상대 경로를 풀 URL로 만들기 위해 base_url 가져오기
import '../../core/base_url.dart';

/// 프로필 설정 화면
class ProfileSettingPage extends StatefulWidget {
  const ProfileSettingPage({
    Key? key,
    this.nickname,
    this.gender,
    this.age,
    this.intro,
    this.interests,
    this.avatarPath, // URL 또는 로컬 파일 경로
  }) : super(key: key);

  final String? nickname;
  final String? gender; // 'M'/'F'/'N' 또는 '남'/'여'/'없음'
  final String? age;
  final String? intro;
  final List<String>? interests;
  final String? avatarPath;

  @override
  State<ProfileSettingPage> createState() => _ProfileSettingPageState();
}

class _ProfileSettingPageState extends State<ProfileSettingPage> {
  late TextEditingController _nicknameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _introCtrl;
  late TextEditingController _habitCtrl;

  /// 'M','F','N' 코드로 관리
  late String _selectedGender;

  final List<String> _interests = [
    '운동',
    '음식',
    '시험',
    '영화',
    '공부',
    '사진',
    '음악',
    '춤',
  ];
  List<String> _selectedInterests = [];

  final ImagePicker _picker = ImagePicker();
  final ScrollController _interestScrollCtrl = ScrollController();

  // ===== 백엔드 관련 =====
  final _auth = AuthService();
  int? _userId;

  bool _loading = false;
  bool _saving = false;

  bool _nickChecked = false;
  bool? _nickAvailable;
  String? _originalNickname;

  // 프로필 이미지
  XFile? _profileImageFile; // 기기에서 고른 이미지
  String? _avatarUrl; // 서버에서 받은 URL (http…)

  /// 이름 → ID 매핑 (백엔드 interestId용)
  static const Map<String, int> _interestNameToId = {
    '운동': 1,
    '음식': 2,
    '시험': 3,
    '영화': 4,
    '공부': 5,
    '사진': 6,
    '음악': 7,
    '춤': 8,
  };

  @override
  void initState() {
    super.initState();

    // 우선 위젯에서 받은 값으로 세팅
    _nicknameCtrl = TextEditingController(text: widget.nickname ?? '');
    _ageCtrl = TextEditingController(text: widget.age ?? '');
    _introCtrl = TextEditingController(text: widget.intro ?? '');
    _habitCtrl = TextEditingController();

    _selectedInterests = List<String>.from(widget.interests ?? []);

    // ===========================
    // avatarPath가 URL인지, 로컬 파일 경로인지 구분
    // ===========================
    if (widget.avatarPath != null && widget.avatarPath!.isNotEmpty) {
      final path = widget.avatarPath!;

      // 🔹 devnone 같은 이상한 URL이면 그냥 무시 (이미지 없는 걸로 처리)
      if (!path.contains('devnone')) {
        if (path.startsWith('http')) {
          // 이미 풀 URL
          _avatarUrl = path;
        } else if (path.startsWith('/')) {
          // 🔹 "/uploads/..." 같은 서버 상대 경로 → 풀 URL로 변환
          _avatarUrl = '$kBaseUrl$path';
        } else {
          // 🔹 로컬 파일 경로로 간주 (기기 사진)
          _profileImageFile = XFile(path);
        }
      }
    }

    // 성별 코드 정리
    _selectedGender = _normalizeGender(widget.gender);

    // 닉네임 변경 시 중복 인증 상태 리셋
    _nicknameCtrl.addListener(() {
      if (_nickChecked) {
        setState(() {
          _nickChecked = false;
          _nickAvailable = null;
        });
      }
    });

    // 서버에서 최신 프로필 한 번 더 가져오기
    _loadProfileFromServer();
  }

  String _normalizeGender(String? g) {
    if (g == null) return 'N';
    switch (g) {
      case 'M':
      case 'F':
      case 'N':
        return g;
      case '남':
        return 'M';
      case '여':
        return 'F';
      case '없음':
        return 'N';
      default:
        return 'N';
    }
  }

  String _genderCodeToLabel(String? code) {
    switch (code) {
      case 'M':
        return '남';
      case 'F':
        return '여';
      case 'N':
      case null:
      default:
        return '없음';
    }
  }

  /// 서버에서 내 프로필 가져와서 폼에 채워 넣기
  Future<void> _loadProfileFromServer() async {
    setState(() {
      _loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('user_id');
      if (uid == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없습니다. 다시 로그인해 주세요.')),
        );
        setState(() => _loading = false);
        return;
      }
      _userId = uid;

      final profile = await _auth.fetchMyProfile(uid);

      if (profile != null) {
        final serverNickname = profile['nickname']?.toString();
        final serverGender = profile['gender']?.toString();
        final serverAge = profile['age'];
        final serverBio = profile['bio']?.toString();
        final serverInterests = profile['interests']; // List<String>/List<int>/List<Map>
        final serverAvatarUrl = profile['avatarUrl']?.toString();

        setState(() {
          // ===== 닉네임 =====
          if (_nicknameCtrl.text.trim().isEmpty && serverNickname != null) {
            _nicknameCtrl.text = serverNickname;
          }
          _originalNickname ??= _nicknameCtrl.text;
          _nickChecked = true;
          _nickAvailable = true;

          // ===== 성별 =====
          if (serverGender != null) {
            _selectedGender = _normalizeGender(serverGender);
          }

          // ===== 나이 =====
          if (_ageCtrl.text.trim().isEmpty && serverAge != null) {
            _ageCtrl.text = serverAge.toString();
          }

          // ===== 한줄소개 =====
          if (_introCtrl.text.trim().isEmpty &&
              serverBio != null &&
              serverBio.isNotEmpty) {
            _introCtrl.text = serverBio;
          }

          // ===== 관심사 =====
          final parsedInterests = <String>[];
          if (serverInterests is List && serverInterests.isNotEmpty) {
            final first = serverInterests.first;

            if (first is String) {
              // ["운동","공부", ...]
              parsedInterests.addAll(
                serverInterests.map((e) => e.toString()),
              );
            } else if (first is int) {
              // [1,5,3, ...]  → 이름으로 매핑
              for (final id in serverInterests) {
                final name = _interestNameToId.entries
                    .firstWhere(
                      (entry) => entry.value == id,
                  orElse: () => const MapEntry('', 0),
                )
                    .key;
                if (name.isNotEmpty) {
                  parsedInterests.add(name);
                }
              }
            } else if (first is Map) {
              // 🔹 [{ "id": 1, "name": "운동" }, ...] 형태 지원
              for (final item in serverInterests) {
                if (item is Map) {
                  final name = item['name']?.toString();
                  if (name != null && name.isNotEmpty) {
                    parsedInterests.add(name);
                  }
                }
              }
            }
          }

          // 서버에서 파싱에 성공했을 때만 덮어쓰기
          if (parsedInterests.isNotEmpty) {
            _selectedInterests = parsedInterests;
          }
          // (비어 있으면 기존 _selectedInterests 유지 → MyPage에서 넘겨준 값 그대로)

          // ===== 프로필 이미지 =====
          if (serverAvatarUrl != null &&
              serverAvatarUrl.isNotEmpty &&
              !serverAvatarUrl.contains('devnone')) {
            // 이미 기기에서 새 사진을 고른 경우는 건드리지 않음
            if (_profileImageFile == null) {
              // 🔹 서버에서 상대 경로로 올 수도 있으니 한 번 더 보정
              if (serverAvatarUrl.startsWith('http')) {
                _avatarUrl = serverAvatarUrl;
              } else if (serverAvatarUrl.startsWith('/')) {
                _avatarUrl = '$kBaseUrl$serverAvatarUrl';
              } else {
                _avatarUrl = serverAvatarUrl;
              }
            }
          }

          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필을 불러오지 못했어요: $e')),
      );
      setState(() => _loading = false);
    }
  }

  /// 이미지 선택
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? img = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (img != null) {
        setState(() {
          _profileImageFile = img; // 새로 고른 파일
          _avatarUrl = null; // 기존 URL은 버림
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지를 불러오지 못했어요: $e')),
      );
    }
  }

  void _showImageSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('이미지 제거'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _profileImageFile = null;
                  _avatarUrl = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 프로필 이미지가 있다면 서버에 업로드
  Future<void> _uploadIfNeeded(int userId) async {
    if (_profileImageFile == null) return;

    final url = await _auth.uploadProfilePicture(
      userId: userId,
      imageFile: _profileImageFile!,
    );

    if (url == null) {
      throw Exception('프로필 사진 업로드 실패');
    }

    setState(() {
      _avatarUrl = url;
    });
  }

  Future<void> _onSaveProfile() async {
    final nickname = _nicknameCtrl.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해 주세요.')),
      );
      return;
    }

    // 닉네임이 처음 받은 것과 다를 때만 중복체크 강제
    if (nickname != _originalNickname) {
      if (!_nickChecked || _nickAvailable != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임 중복인증을 먼저 통과해 주세요.')),
        );
        return;
      }
    }

    var userId = _userId;
    if (userId == null) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('user_id');
    }

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 불러올 수 없습니다. 다시 로그인해주세요.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final ageText = _ageCtrl.text.trim();
      final int? age = ageText.isEmpty ? null : int.tryParse(ageText);

      final selectedNames = List<String>.from(_selectedInterests);

      final selectedIds = <int>[];
      for (final name in selectedNames) {
        final id = _interestNameToId[name];
        if (id != null) selectedIds.add(id);
      }

      // 1) 이미지 업로드
      await _uploadIfNeeded(userId);

      // 2) 프로필 업데이트
      await _auth.updateProfile(
        userId: userId,
        nickname: nickname,
        gender: _selectedGender,
        age: age,
        bio: _introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim(),
        interests: selectedIds,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 성공적으로 저장되었습니다.')),
      );

      // MyPage로 돌려줄 값
      final profile = {
        'nickname': nickname,
        'gender': _selectedGender,
        'genderLabel': _genderCodeToLabel(_selectedGender),
        'age': _ageCtrl.text.trim(),
        'intro': _introCtrl.text.trim(),
        'interests': selectedNames,
        'interestIds': selectedIds,
        'avatarPath':
        _profileImageFile != null ? _profileImageFile!.path : _avatarUrl,
        'avatarUrl': _avatarUrl,
      };

      Navigator.pop(context, profile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _ageCtrl.dispose();
    _introCtrl.dispose();
    _habitCtrl.dispose();
    _interestScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 배경 + 프로필 이미지
            SizedBox(
              height: 220, // 헤더 영역 전체 높이 확보
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 140,
                    color: AppColors.lightBrown.withOpacity(0.4),
                  ),
                  Positioned(
                    top: 80,
                    left: 35,
                    child: InkWell(
                      onTap: _showImageSheet,
                      borderRadius: BorderRadius.circular(64),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: AppColors.cream,
                            backgroundImage: _profileImageFile != null
                                ? FileImage(
                              File(_profileImageFile!.path),
                            )
                                : (_avatarUrl != null &&
                                !_avatarUrl!.contains('devnone')
                                ? NetworkImage(_avatarUrl!)
                            as ImageProvider
                                : null),
                            child: _profileImageFile == null &&
                                (_avatarUrl == null ||
                                    _avatarUrl!.contains('devnone'))
                                ? Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: AppColors.dark,
                            )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                    color: Colors.black12,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 아래 폼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),

                  // 닉네임 + 중복체크
                  _label('*닉네임'),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          _nicknameCtrl,
                          hint: '닉네임을 입력하세요',
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                          final nickname = _nicknameCtrl.text.trim();
                          if (nickname.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('닉네임을 입력해 주세요.'),
                              ),
                            );
                            return;
                          }

                          setState(() => _saving = true);
                          final available =
                          await _auth.checkNickname(nickname);
                          setState(() {
                            _saving = false;
                            _nickChecked = true;
                            _nickAvailable = available;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                available
                                    ? '사용 가능 닉네임입니다.'
                                    : '이미 사용중인 닉네임입니다.',
                              ),
                              backgroundColor: available
                                  ? Colors.green
                                  : AppColors.brick,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          fixedSize: const Size(60, 50),
                          backgroundColor: AppColors.brick,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '중복인증',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_nickChecked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _nickAvailable == true
                            ? '사용 가능한 닉네임입니다'
                            : '이미 사용 중입니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: _nickAvailable == true
                              ? Colors.green
                              : AppColors.brick,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 성별
                  _label('성별'),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    items: const [
                      DropdownMenuItem(
                        value: 'M',
                        child: Text('남'),
                      ),
                      DropdownMenuItem(
                        value: 'F',
                        child: Text('여'),
                      ),
                      DropdownMenuItem(
                        value: 'N',
                        child: Text('없음'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedGender = v ?? 'N'),
                    decoration: _inputDecoration(),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),

                  const SizedBox(height: 16),

                  // 나이
                  _label('나이'),
                  _textField(
                    _ageCtrl,
                    hint: '나이를 입력하세요',
                    keyboard: TextInputType.number,
                  ),

                  const SizedBox(height: 16),

                  // 한줄소개
                  _label('한줄소개'),
                  _textField(
                    _introCtrl,
                    hint: '자신을 소개해 주세요',
                  ),

                  const SizedBox(height: 16),

                  // 관심사
                  _label('관심사'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Scrollbar(
                      thumbVisibility: true,
                      controller: _interestScrollCtrl,
                      child: SingleChildScrollView(
                        controller: _interestScrollCtrl,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _interests.map((interest) {
                            final selected =
                            _selectedInterests.contains(interest);
                            return ChoiceChip(
                              label: Text(interest),
                              selected: selected,
                              backgroundColor: AppColors.cream,
                              selectedColor: AppColors.chipYellow,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedInterests.add(interest);
                                  } else {
                                    _selectedInterests.remove(interest);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _onSaveProfile,
                      style: ElevatedButton.styleFrom(
                        fixedSize: const Size(140, 55),
                        backgroundColor: AppColors.brick,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        _saving ? '저장 중...' : '저장',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== UI helpers =====
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );

  InputDecoration _inputDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.brown.withOpacity(0.7),
        width: 1.4,
      ),
    ),
  );

  Widget _textField(
      TextEditingController controller, {
        String? hint,
        TextInputType? keyboard,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: _inputDecoration().copyWith(hintText: hint),
    );
  }
}
