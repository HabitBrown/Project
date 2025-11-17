// lib/screens/home/profile_setting.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 기존 색상 팔레트 재사용
import 'home_screen.dart' show AppColors;

class ProfileSettingPage extends StatefulWidget {
  const ProfileSettingPage({
    Key? key,
    this.nickname,
    this.gender,
    this.age,
    this.intro,
    this.interests,
    this.avatarPath,
  }) : super(key: key);

  final String? nickname;
  final String? gender;
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

  String? _selectedGender;
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
  File? _profileImageFile;

  @override
  void initState() {
    super.initState();

    // ✅ 기존 값들로 컨트롤러 초기화
    _nicknameCtrl = TextEditingController(text: widget.nickname ?? '');
    _ageCtrl = TextEditingController(text: widget.age ?? '');
    _introCtrl = TextEditingController(text: widget.intro ?? '');
    _habitCtrl = TextEditingController();

    _selectedGender = widget.gender;
    _selectedInterests = List<String>.from(widget.interests ?? []);

    if (widget.avatarPath != null && widget.avatarPath!.isNotEmpty) {
      _profileImageFile = File(widget.avatarPath!);
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

  void _onSaveProfile() {
    if (_nicknameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해 주세요.')),
      );
      return;
    }

    final profile = {
      'nickname': _nicknameCtrl.text.trim(),
      'gender': _selectedGender,
      'age': _ageCtrl.text.trim(),
      'intro': _introCtrl.text.trim(),
      'interests': List<String>.from(_selectedInterests),
      'avatarPath': _profileImageFile?.path,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('프로필을 저장했어요!')),
    );

    // ✅ 수정 후, 현재 페이지를 닫으면서 새 프로필을 MyPage로 전달
    Navigator.pop(context, profile);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _ageCtrl.dispose();
    _introCtrl.dispose();
    _habitCtrl.dispose();
    super.dispose();
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
                        child:
                        _textField(_nicknameCtrl, hint: '닉네임을 입력하세요'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: 닉네임 중복 체크 API 연동
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('중복 체크 준비 중…')),
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
                  const SizedBox(height: 16),

                  _label('성별'),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    items: const ['남', '여', '없음']
                        .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g)))
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

                  Center(
                    child: ElevatedButton(
                      onPressed: _onSaveProfile,
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
