// lib/screens/home/mypage_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import '../../services/user_service.dart';
import '../../core/base_url.dart';

// AppImages, AppColors 재사용
import 'home_screen.dart';
import 'profile_setting.dart';

class MyPageScreen extends StatefulWidget {
  final String? nickname;
  final String? gender;
  final String? intro;
  final List<String>? interests;
  final List<String>? successHabits;
  final String? avatarPath;

  const MyPageScreen({
    super.key,
    this.nickname,
    this.gender,
    this.intro,
    this.interests,
    this.successHabits,
    this.avatarPath,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  double _alarmVolume = 0.5;
  bool _alarmOn = true;

  // ===== 프로필 상태 =====
  late String _nick;
  late String _gen;
  late String _about;
  late List<String> _myInterests;
  late List<String> _mySuccessHabits;
  String? _avatarPath;
  String? _avatarUrl;   // 서버에서 받은 프로필 이미지 URL
  final _authService = AuthService();
  final _habitService = HabitService();
  final _userService = UserService();

  @override
  void initState() {
    super.initState();

    // 우선 위젯에서 넘어온 값(있다면)으로 기본 세팅
    _nick = widget.nickname ?? '망설이는 감자';
    _gen = widget.gender ?? 'N';
    _about = widget.intro ?? '';
    _myInterests = widget.interests ?? [];
    _mySuccessHabits = widget.successHabits ?? [];
    _avatarPath = widget.avatarPath;

    // 백엔드에서 유저 정보 동기화
    _loadUserProfile();

    _loadCompletedHabits();
    _loadUserInterests();
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) return;

      final me = await _authService.getUser(userId);

      final nick = (me['nickname'] ?? '').toString().trim();
      final name = (me['name'] ?? '').toString().trim();
      final bio  = (me['bio'] ?? '').toString().trim();
      final gender = (me['gender'] ?? 'N').toString();

      final rawAvatar = (me['profile_picture'] ?? '').toString().trim();

      String? normalizedAvatar;
      if (rawAvatar.isEmpty || rawAvatar == 'none') {
        normalizedAvatar = null;
      } else if (rawAvatar.startsWith('http')) {
        normalizedAvatar = rawAvatar;
      } else {
        // "/uploads/..." 같은 상대경로면 kBaseUrl 붙이기
        normalizedAvatar = '$kBaseUrl$rawAvatar';
      }

      // 관심사 / 성공한 습관은 백엔드에 아직 없으면 기본값 유지
      // 예: me['interests']가 ["코딩","운동"] 이런 식으로 온다고 가정
      final interests = (me['interests'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          _myInterests;

      final successHabits = (me['success_habits'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          _mySuccessHabits;

      if (!mounted) return;
      setState(() {
        _nick = nick.isNotEmpty ? nick : (name.isNotEmpty ? name : _nick);
        _gen = gender;
        _about = bio.isNotEmpty ? bio : _about;
        _myInterests = interests;
        _mySuccessHabits = successHabits;
        _avatarUrl = normalizedAvatar;
      });
    } catch (e) {
      // 실패해도 앱이 죽지는 않게 그냥 무시
      // print('마이페이지 유저 정보 불러오기 실패: $e');
    }
  }

  Future<void> _loadCompletedHabits() async {
    try {
      final titles = await _habitService.fetchCompletedHabitTitles();
      if (!mounted) return;

      setState(() {
        // 백엔드에서 가져온 제목들로 교체
        _mySuccessHabits = titles;
      });
    } catch (e) {
      // 실패해도 마이페이지 전체가 죽지 않도록 조용히 무시
      // print('완료된 습관 불러오기 실패: $e');
    }
  }

  Future<void> _loadUserInterests() async {
       try {
         final names = await _userService.fetchMyInterestNames();
         if (!mounted) return;

         setState(() {
           // 백엔드에서 조회한 관심사 이름 리스트로 교체
           _myInterests = names;
         });
       } catch (e) {
         // 실패해도 마이페이지 전체가 죽지 않도록 조용히 무시
         // print('관심사 불러오기 실패: $e');
       }
     }

  // ================ 환경설정 팝업 ================
  void _openSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
              decoration: BoxDecoration(
                color: const Color(0xFFE1B872),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFBFA26B),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (context, setInnerState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      const Text(
                        '환경설정',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            '알림  소리',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 6,
                                activeTrackColor: const Color(0xFFC98A55),
                                inactiveTrackColor:
                                const Color(0xFFC98A55).withOpacity(0.4),
                                thumbColor: Colors.white,
                                overlayColor:
                                Colors.white.withOpacity(0.15),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10,
                                ),
                              ),
                              child: Slider(
                                value: _alarmVolume,
                                onChanged: (v) {
                                  setInnerState(() {
                                    _alarmVolume = v;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            '알림',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 28),
                          _AlarmToggleButton(
                            label: '켜기',
                            isOn: _alarmOn,
                            activeColor: const Color(0xFFC32B2B),
                            onTap: () {
                              setInnerState(() => _alarmOn = true);
                            },
                          ),
                          const SizedBox(width: 10),
                          _AlarmToggleButton(
                            label: '끄기',
                            isOn: !_alarmOn,
                            activeColor: const Color(0xFF3D6B33),
                            onTap: () {
                              setInnerState(() => _alarmOn = false);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SettingsBigButton(
                            label: '초기화',
                            onTap: () {
                              setInnerState(() {
                                _alarmVolume = 0.5;
                                _alarmOn = true;
                              });
                            },
                          ),
                          const SizedBox(width: 24),
                          _SettingsBigButton(
                            label: '로그아웃',
                            onTap: () {
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ============== 프로필 수정 이동 ==============
  Future<void> _goToProfileSetting() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSettingPage(
          nickname: _nick,
          gender: _gen,
          intro: _about,
          interests: _myInterests,
          avatarPath: _avatarPath,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _nick = result['nickname'] as String? ?? _nick;
      _gen = result['gender'] as String? ?? _gen;
      _about = result['intro'] as String? ?? _about;
      _myInterests =
          (result['interests'] as List<dynamic>?)?.cast<String>() ??
              _myInterests;
      _mySuccessHabits =
          (result['successHabits'] as List<dynamic>?)?.cast<String>() ??
              _mySuccessHabits;
      _avatarPath = result['avatarPath'] as String? ?? _avatarPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final File? avatarFile = (_avatarPath != null && _avatarPath!.isNotEmpty)
        ? File(_avatarPath!)
        : null;
    Widget avatarWidget;
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarWidget = Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          // URL이 깨지면 로컬/기본 아이콘으로 폴백
          if (avatarFile != null) {
            return Image.file(avatarFile, fit: BoxFit.cover);
          }
          return Center(
            child: Image.asset(
              AppImages.camera,
              width: 42,
              fit: BoxFit.contain,
            ),
          );
        },
      );
    } else if (avatarFile != null) {
      avatarWidget = Image.file(
        avatarFile,
        fit: BoxFit.cover,
      );
    } else {
      avatarWidget = Center(
        child: Image.asset(
          AppImages.camera,
          width: 42,
          fit: BoxFit.contain,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              // ================= 갈색 헤더 + 프로필 수정 버튼 =================
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: AppColors.brown),
                    ),
                    // 맨 위 오른쪽 귀퉁이 프로필 수정 버튼
                    Positioned(
                      right: 18,
                      top: 38,
                      child: _EditProfileButton(
                        onTap: _goToProfileSetting,
                      ),
                    ),
                  ],
                ),
              ),

              // ================= 아래 흰색 영역 =================
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 프로필 동그라미
                      Positioned(
                        top: -55,
                        left: 26,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.black12,
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarWidget,
                          ),
                        ),
                      ),

                      // 내용
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(34, 26, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 닉네임 + 성별 + 설정 버튼
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 120),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: _nick,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const TextSpan(text: '  '),
                                            TextSpan(
                                              text: '(성별: $_gen)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _about,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: _openSettingsDialog,
                                  child: const Icon(
                                    Icons.settings,
                                    size: 26,
                                    color: Color(0xFF555555),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // 관심사
                            const Text(
                              '· 관심사:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: _myInterests
                                  .map((e) => _InterestChip('# $e'))
                                  .toList(),
                            ),

                            const SizedBox(height: 18),

                            // 성공한 해시브라운 영역 (흰색 카드)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.fromLTRB(
                                  18, 14, 18, 18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x11000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '· 성공한 해시브라운',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Image.asset(
                                        AppImages.hbLogo,
                                        width: 22,
                                        height: 22,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    children: _mySuccessHabits
                                        .map(
                                          (habit) => Padding(
                                        padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 7),
                                        child: _SuccessHabitCard(
                                          title: habit,
                                        ),
                                      ),
                                    )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // 하단바
      bottomNavigationBar: _BottomBar(
        index: 4,
        onChanged: (i) {
          if (i == 0) {
            Navigator.pushNamed(
              context,
              '/potato',
              arguments: {'hbCount': 0},
            );
          } else if (i == 1) {
            Navigator.pushNamed(
              context,
              '/hash',
              arguments: {'hbCount': 0},
            );
          } else if (i == 2) {
            Navigator.pushNamed(context, '/home');
          } else if (i == 3) {
            // TODO: 알림 화면
          } else if (i == 4) {
            // 이미 마이페이지
          }
        },
      ),
    );
  }
}

//// ================== 환경설정 팝업용 위젯들 ==================

class _AlarmToggleButton extends StatelessWidget {
  final String label;
  final bool isOn;
  final Color activeColor;
  final VoidCallback onTap;

  const _AlarmToggleButton({
    required this.label,
    required this.isOn,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isOn ? activeColor : activeColor.withOpacity(0.6);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SettingsBigButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SettingsBigButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFC99663),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x338C5B33),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

//// ================== 프로필 수정 버튼 ==================

class _EditProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E2C0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 3,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.edit,
              size: 13,
              color: Color(0xFF555555),
            ),
            SizedBox(width: 4),
            Text(
              '프로필 수정',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//// ================== 관심사 칩 ==================

class _InterestChip extends StatelessWidget {
  final String text;
  const _InterestChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 3,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13, // ← 살짝 키움
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }
}

//// ================== 성공한 습관 카드 ==================

class _SuccessHabitCard extends StatelessWidget {
  final String title;
  const _SuccessHabitCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.caramel,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Image.asset(
            AppImages.hash,
            width: 30,
            height: 30,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

//// =============== 하단바 (홈이랑 동일 스타일) ===============

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(
          top: BorderSide(color: AppColors.caramel, width: 3),
        ),
      ),
      child: Row(
        children: List.generate(5, (i) {
          return Expanded(
            child: _BottomItem(
              index: i,
              selected: index == i,
              onTap: () => onChanged(i),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;
  const _BottomItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['감자캐기', '해시내기', '홈화면', '알림', '마이페이지'];

    Widget icon;
    switch (index) {
      case 0:
        icon = Image.asset(
          AppImages.bottomDig,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
      case 1:
        icon = Image.asset(
          AppImages.bottomHash,
          width: 35,
          height: 35,
          fit: BoxFit.contain,
        );
        break;
      case 2:
        icon = Image.asset(
          AppImages.hbLogo,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
        );
        break;
      case 3:
        icon = Image.asset(
          AppImages.alarm,
          width: 33,
          height: 33,
          fit: BoxFit.contain,
        );
        break;
      case 4:
      default:
        icon = Image.asset(
          AppImages.bottomMyPage,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
    }

    final bool isHome = index == 2;
    final Color labelColor =
    selected ? Colors.black87 : Colors.black87.withOpacity(0.5);
    final FontWeight labelWeight =
    isHome ? FontWeight.w500 : (selected ? FontWeight.w600 : FontWeight.w400);

    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 46,
                  height: 38,
                  child: Center(child: icon),
                ),
                const SizedBox(height: 2),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: labelWeight,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
          if (index != 0)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AppColors.caramel,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
