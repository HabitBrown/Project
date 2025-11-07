import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

class AppColors {
  static const cream = Color(0xFFFFF8E1);
  static const green = Color(0xFFAFDBAE);
  static const brown = Color(0xFFBF8D6A);
  static const dark = Color(0xFF535353);
  static const grey = Color(0xFFD9D9D9);
  static const lightBrown = Color(0xFFECCA89);
  static const chipYellow = Color(0xFFF0E27A);
  static const divider = Color(0xFFD8CBB6);
  static const brick = Color(0xFFC32B2B);
}

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({Key? key}) : super(key: key);

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _nicknameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _introCtrl = TextEditingController();
  final _habitCtrl = TextEditingController();

  final _auth = AuthService();
  bool _saving = false;
  int? _userId;

  bool _nickChecked = false;
  bool? _nickAvailable; // true=사용가능, false=중복, null=미확인

  String? _selectedGender;
  final List<String> _interests = ['운동', '음식', '시험', '영화', '공부', '사진'];
  final List<String> _selectedInterests = [];

  @override
  void initState() {
    super.initState();
    // 닉네임이 바뀌면 다시 인증하게 리셋
    _nicknameCtrl.addListener(() {
      if (_nickChecked) {
        setState(() {
          _nickChecked = false;
          _nickAvailable = null;
        });
      }
    });
  }

  final ImagePicker _picker = ImagePicker();
  File? _profileImageFile;

  /// 회원가입 화면에서 전달된 값을 한 번만 초기 세팅
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? img = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (img != null) {
        setState(() => _profileImageFile = File(img.path));
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
                setState(() => _profileImageFile = null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSaveProfile() async {
    final nickname = _nicknameCtrl.text.trim();

    // 기본 유효성 검사
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해 주세요.')),
      );
      return;
    }

    if (!_nickChecked || _nickAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임 중복인증을 먼저 통과해 주세요.')),
      );
      return;
    }

    //유저 ID 가져오기 (회원가입 후 전달받거나 SharedPreferences에서 가져옴)
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

    // 서버로 프로필 업데이트 요청
    setState(() => _saving = true);
    try {
      final genderEnum = _genderToEnum(_selectedGender);
      final age = _ageCtrl.text.trim().isEmpty ? null : int.tryParse(_ageCtrl.text.trim());

      await _auth.updateProfile(
        userId: userId,
        nickname: nickname,
        gender: genderEnum,
        age: age,
        bio: _introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim(),
        // nickname 추가해야 DB에 닉네임이 저장됨!
        name: nickname, // ⚠️ 백엔드 update_user 함수에서 닉네임 필드를 name 대신 nickname으로 받는다면 이 키 이름 수정 필요
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 성공적으로 저장되었습니다.')),
      );

      // 홈 화면으로 이동
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false,
        arguments: {
          'nickname': nickname,
          'gender': _selectedGender,
          'age': _ageCtrl.text.trim(),
          'intro': _introCtrl.text.trim(),
          'interests': List<String>.from(_selectedInterests),
          'avatarPath': _profileImageFile?.path,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 최초 1회만
    if (_userId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _userId = args['userId'] as int?;
        final nickFromSignup = (args['nickname'] as String?)?.trim();
        if (nickFromSignup != null && nickFromSignup.isNotEmpty) {
          _nicknameCtrl.text = nickFromSignup;
        }
      }
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _ageCtrl.dispose();
    _introCtrl.dispose();
    _habitCtrl.dispose();
    super.dispose();
  }

  String? _genderToEnum(String? g) {
    switch (g) {
      case '남': return 'M';
      case '여': return 'F';
      case '없음': return 'N';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 배경 + 프로필 이미지
            Stack(
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
                              ? FileImage(_profileImageFile!)
                              : null,
                          child: _profileImageFile == null
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
                const SizedBox(height: 64),
              ],
            ),

            // ✅ 여기서는 Positioned를 쓰지 않습니다 (Stack 밖이므로)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),

                  _label('*닉네임'),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(_nicknameCtrl, hint: '닉네임을 입력하세요'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final nickname = _nicknameCtrl.text.trim();
                          if(nickname.isEmpty){
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해 주세요.')),);
                          return;
                          }

                          setState(() => _saving = true);
                          final available = await _auth.checkNickname(nickname);
                          setState(() {
                            _saving = false;
                            _nickChecked = true;
                            _nickAvailable = available;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                  available
                                      ?'사용 가능 닉네임입니다.'
                                      :'이미 사용중인 닉네임입니다.',
                                ),
                              backgroundColor:
                                available ? Colors.green : AppColors.brick,
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

                  if(_nickChecked)
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

                  _label('성별'),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    items: const ['남', '여', '없음']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedGender = v),
                    decoration: _inputDecoration(),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  const SizedBox(height: 16),

                  _label('나이'),
                  _textField(
                    _ageCtrl,
                    hint: '나이를 입력하세요',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  _label('한줄소개'),
                  _textField(_introCtrl, hint: '자신을 소개해 주세요'),
                  const SizedBox(height: 16),

                  _label('관심사'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
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

                  _label('습관 등록하기'),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(_habitCtrl, hint: '습관 이름 입력'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: 습관 리스트에 추가하는 로직 연결
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('추가: ${_habitCtrl.text}')),
                          );
                          _habitCtrl.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  Center(
                    child: ElevatedButton(
                      onPressed: _onSaveProfile, // ✅ 저장 → 홈으로
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
                      child: const Text(
                        '저장',
                        style: TextStyle(fontSize: 14, color: Colors.white),
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
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
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
