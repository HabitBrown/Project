import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pbl_front/screens/daily_check.dart';

// 추가: 백엔드/로컬 저장 연동
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/farmer.dart';
import '../../models/home_summary.dart';
import '../../models/home_habit.dart' as dto;
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import '../../services/home_service.dart';
import '../../services/certification_service.dart';
import '../../core/base_url.dart';

import 'habit_setting.dart';
import 'cert_page.dart';
import 'mypage_screen.dart';
import 'alarm_screen.dart';
import 'shopping_screen.dart';

/// =======================
///  공통 리소스 & 테마 정의
/// =======================
class AppImages {
  static const root = 'lib/assets/image1';
  static const smallHabitLogo = '$root/small_habit_logo.png';
  static const hbLogo = '$root/HB_logo.png';
  static const cart = '$root/cart.png';
  static const hotHash = '$root/hot_hashbrown.png';

  // 목표 카드용 감자 아이콘
  static const gamja1 = '$root/gamja1.png';
  static const gamja2 = '$root/gamja2.png';
  // 싸우고 있는 감자
  static const angryGamja = '$root/angry_gamja.png';

  // 하단바
  static const bottomDig = '$root/homi.png';
  static const bottomHash = '$root/gamjakal.png';
  static const alarm = '$root/alarm.png';
  static const bottomCommunity = '$root/comunity_people.png';
  static const bottomMyPage = '$root/mypage_logo_gamja.png';
  static const kal = '$root/kal.png';
  static const camera = '$root/camera.png';
  static const hash = '$root/hash.png';
}

class AppColors {
  // 화면 배경
  static const cream = Color(0xFFFFF8E1);
  static const page = cream;

  // 기본 팔레트
  static const green = Color(0xFFAFDBAE);
  static const brown = Color(0xFFBF8D6A);
  static const brick = Color(0xFFC32B2B);
  static const dark = Color(0xFF535353);

  // 홈에서 쓰는 노란색들
  static const yellow = Color(0xFFF3C34E);
  static const chip = Color(0xFFF6E89E);

  // 공통 보더/섀도우
  static const divider = Color(0xFFE8E0D4);
  static const shadow = Color(0x1F000000);

  // 폼/에러
  static const danger = Color(0xFFE25B5B);
  static const inputBg = Color(0xFFF6F1DC);

  // 진행바
  static const redBar = Color(0xFFC32B2B);
  static const yellowRest = Color(0xFFE9D973);

  // 카드 / 하단바
  static const caramel = Color(0xFFA9783F);

  // 싸우고 있는 감자 카드 색
  static const fightingLeft = Color(0xFFECCA89);
  static const rivalBtn = Color(0xFFF5CE73);

  static const lightBrown = Color(0xFFECCA89);
  static const chipYellow = Color(0xFFF0E27A);
}

class Dimens {
  static const pad = 16.0;
}

/// =======================
///  모델 정의 (UI용)
/// =======================
enum HabitStatus { pending, verified, skipped }

class HomeHabit {
  final int userHabitId;

  String title;
  String time;
  String method;
  HabitStatus status;
  HabitSetupData? source; // 설정에서 온 원본 (habit_setting.dart)
  bool certifiedToday;

  HomeHabit({
    required this.userHabitId,
    required this.title,
    required this.time,
    required this.method,
    this.status = HabitStatus.pending,
    this.source,
    this.certifiedToday = false,
  });
}

/// =======================
///  홈 화면
/// =======================
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialNickname,
  });

  final String? initialNickname;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = -1;
  int _hb = 0;
  bool _dailyBonusGiven = false;

  Timer? _tick;

  String nickname = '망설이는 감자';
  String honorific = '농부님!';

  late List<HomeHabit> _today;
  late List<HomeHabit> _fighting;
  bool _initialized = false;

  // ====== 백엔드 연동 관련 필드 ======
  final _homeService = HomeService();
  final _certService = CertificationService();

  HomeSummary? _summary;
  bool _isSummaryLoading = true;
  String? _summaryError;

  String? _avatarUrl; // 프로필 이미지 URL

  @override
  void initState() {
    super.initState();

    if (widget.initialNickname != null &&
        widget.initialNickname!.trim().isNotEmpty) {
      nickname = widget.initialNickname!.trim();
    }

    WidgetsBinding.instance.addPostFrameCallback((_){
      showDailyCheckDialog(
          context,
      onHbUpdated: (newHb){
            setState(() {
              _hb = newHb;
            });
        },
      );
    });


    // late 리스트 초기화 (안전하게)
    _today = [];
    _fighting = [];

    // 1분마다 화면 갱신 (마감시간 체크 등)
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    // ===== 추가: 유저 정보 & 홈 요약 불러오기 =====
    _loadDisplayName();     // 로컬 캐시에서 닉네임/아바타/HB
    _syncUserFromServer();  // 서버에서 유저 정보 동기화
    _loadHomeSummary();     // 홈 요약(오늘/싸우는 습관 리스트)
  }


  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['nickname'] is String) {
      final n = (args['nickname'] as String).trim();
      if (n.isNotEmpty) {
        nickname = n;
      }
    }

    // HabitSetting으로만 채우고 싶을 때는 비워두고 쓰면 됨
    _today = [];
    _fighting = [];

    _initialized = true;
    setState(() {});
  }

  // ===== SharedPreferences 에서 기본 표시 이름/아바타/HB 불러오기 =====
  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final nick = (prefs.getString('nickname') ?? '').trim();
    final name = (prefs.getString('name') ?? '').trim();
    final avatar = (prefs.getString('profile_picture') ?? '').trim();
    final hb = prefs.getInt('hb_balance') ?? 0;

    if (!mounted) return;
    setState(() {
      nickname = nick.isNotEmpty ? nick : (name.isNotEmpty ? name : nickname);
      _avatarUrl = avatar.isNotEmpty ? avatar : null;
      _hb = hb;
    });
  }

  // ===== 서버에서 유저 정보 동기화 (/auth/users/{id}) =====
  Future<void> _syncUserFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    try {
      final me = await AuthService().getUser(userId);

      final nick = (me['nickname'] ?? '').toString().trim();
      final name = (me['name'] ?? '').toString().trim();

      final balance = me['hb_balance'] is int
          ? me['hb_balance'] as int
          : int.tryParse('${me['hb_balance'] ?? 0}') ?? 0;

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

      // 로컬 캐시 갱신
      await prefs.setString('nickname', nick);
      await prefs.setString('name', name);
      await prefs.setInt('hb_balance', balance);
      if (normalizedAvatar == null) {
        await prefs.remove('profile_picture');
      } else {
        await prefs.setString('profile_picture', normalizedAvatar);
      }

      if (!mounted) return;
      setState(() {
        if (nick.isNotEmpty) {
          nickname = nick;
        } else if (name.isNotEmpty) {
          nickname = name;
        }
        _hb = balance;
        _avatarUrl = normalizedAvatar;
      });
    } catch (_) {
      // 오프라인이거나 서버 에러면 그냥 조용히 패쓰
    }
  }

  // ===== 홈 요약 불러오기 (/home/summary) =====
  Future<void> _loadHomeSummary() async {
    try {
      await HabitService().evaluateHabits();

      final data = await _homeService.fetchSummary();

      final certifiedIds = await _certService.fetchTodayCertifiedHabitIds(); // Set<int>

      if (!mounted) return;

      setState(() {
        _summary = data;
        _isSummaryLoading = false;
        _summaryError = null;

        // 서버 DTO(dto.HomeHabit)를 UI용 HomeHabit으로 변환
        _today = data.todayHabits
            .map<HomeHabit>((dto.HomeHabit h) {
          final certified = certifiedIds.contains(h.userHabitId);
          return HomeHabit(
            userHabitId: h.userHabitId,
            title: h.title,
            time: h.time,
            method: h.method,
            status: certified ? HabitStatus.verified : HabitStatus.pending,
            certifiedToday: certified,
          );
        }).toList();

        _fighting = data.fightingHabits
            .map<HomeHabit>((dto.HomeHabit h) {
          final certified = certifiedIds.contains(h.userHabitId);
          return HomeHabit(
            userHabitId: h.userHabitId,
            title: h.title,
            time: h.time,
            method: h.method,
            status: certified ? HabitStatus.verified : HabitStatus.pending,
            certifiedToday: certified,
          );
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryError = e.toString();
        _isSummaryLoading = false;
        _today = [];
        _fighting = [];
      });
    }
  }

  int get _maxGoals => _today.length + _fighting.length;
  int get _doneGoals {
    int done(List<HomeHabit> list) =>
        list.where((h) => h.status == HabitStatus.verified).length;
    return done(_today) + done(_fighting);
  }

  // 지금은 HB/보너스 로직은 비워둔 상태 (필요하면 다시 활성화)
  void _onHabitVerified() {
    setState(() {
      // 예전 HB 증가 로직은 주석 처리해 둠
      // _hb += 2;
      // if (!_dailyBonusGiven && _maxGoals > 0 && _doneGoals == _maxGoals) {
      //   _hb += 5;
      //   _dailyBonusGiven = true;
      // }
    });
  }

  void _rebuild() => setState(() {});

  // 기존: HabitSetting 페이지와 연동하는 부분 유지
  Future<void> _openHabitSetupPage({
    required bool toFighting,
    HomeHabit? editing,
    int? index,
  }) async {
    final result = await Navigator.push<HabitSetupData>(
      context,
      MaterialPageRoute(
        builder: (_) => HabitSetupPage(
          initialTitle: editing?.title ?? '습관을 설정해주세요',
          initialStartDate: editing?.source?.startDate,
          initialEndDate: editing?.source?.endDate,
          initialWeekdays: editing?.source?.weekdays,
          initialBet: editing?.source != null
              ? editing!.source!.difficulty.toString()
              : null,
          initialCertType: editing?.source?.certType ?? CertType.photo,
          initialDeadline: editing?.source?.deadline,
        ),
      ),
    );

    if (result == null) return;

    // 공통 라벨
    final timeLabel = '${result.deadline} 까지';
    final methodLabel = result.certType == CertType.photo ? '사진' : '글';

    // =====================
    // 1) 새 습관 만들기
    // =====================
    if (editing == null) {
      try {
        final created = await HabitService().createHabit(result);
        final newId = created['user_habit_id'] as int;   // 백엔드 응답 필드명

        setState(() {
          final newHabit = HomeHabit(
            userHabitId: newId,      // ★ 여기서 딱 한 번 사용
            title: result.title,
            time: timeLabel,
            method: methodLabel,
            source: result,
          );
          (toFighting ? _fighting : _today).add(newHabit);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새 습관이 등록되었어요!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('습관 생성 실패: $e')),
        );
      }
      return; // 생성 모드 끝
    }

    // =====================
    // 2) 기존 습관 수정하기
    // =====================
    try {
      // editing.userHabitId 는 HomeHabit 에 추가된 필드
      await HabitService().updateHabit(editing.userHabitId, result);

      setState(() {
        final list = toFighting ? _fighting : _today;
        final idx = index ?? list.indexOf(editing);
        if (idx >= 0) {
          list[idx]
            ..title = result.title
            ..time = timeLabel
            ..method = methodLabel
            ..source = result;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('습관이 수정되었어요!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('습관 수정 실패: $e')),
      );
    }
  }

  void _openEditList(bool toFighting) {
    final list = toFighting ? _fighting : _today;
    if (list.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF3BA37),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  toFighting
                      ? '싸우고 있는 감자 선택'
                      : '튀기기를 기다리고 있는 감자 선택',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(list.length, (i) {
                  final h = list[i];
                  return ListTile(
                    title: Text(h.title),
                    subtitle: Text(h.time),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openHabitSetupPage(
                        toFighting: toFighting,
                        editing: h,
                        index: i,
                      );
                    },
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _TopBar(hb: _hb)),
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.cream,
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Dimens.pad),
                        child: HeaderProfile(
                          nickname: nickname,
                          honorific: honorific,
                          avatarUrl: _avatarUrl,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Dimens.pad, 8, Dimens.pad, 0),
                        child: TodayProgressCard(
                          maxGoals: _maxGoals,
                          doneGoals: _doneGoals,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // 섹션 1
              SliverToBoxAdapter(
                child: _SectionHeaderRow(
                  title: '튀기기를 기다리고 있는 감자',
                  right: _SectionActions(
                    onAdd: () => _openHabitSetupPage(toFighting: false),
                    onEdit: () => _openEditList(false),
                  ),
                ),
              ),
              _HabitList(
                habits: _today,
                onChange: _rebuild,
                onVerified: _onHabitVerified,
                isFighting: false,
                nickname: nickname,
              ),

              // 섹션 2
              SliverToBoxAdapter(
                child: _SectionHeaderRow(
                  title: '싸우고 있는 감자',
                  icon: Icons.gavel,
                ),
              ),
              _HabitList(
                habits: _fighting,
                onChange: _rebuild,
                onVerified: _onHabitVerified,
                isFighting: true,
                nickname: nickname,
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        onChanged: (i) {
          if (i == 0) {
            Navigator.pushNamed(
              context,
              '/potato',
              arguments: {'hbCount': _hb},
            );
          } else if (i == 1) {
            Navigator.pushNamed(
              context,
              '/hash',
              arguments: {'hbCount': _hb},
            );
          } else if (i == 3){
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AlarmScreen(),
                ),
            );
          } else if (i == 4) {
            Navigator.pushNamed(
              context,
              '/mypage',
              arguments: {'hbCount': _hb},
            );
          } else {
            setState(() {
              _tab = i;
            });
          }
        },
      ),
    );
  }
}

/// =======================
///  상단바
/// =======================
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final int hb;
  const _TopBar({super.key, required this.hb});

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.cream,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      toolbarHeight: 84,
      leadingWidth: 140,
      leading: Padding(
        padding: const EdgeInsets.only(left: 6, top: 10),
        child: Image.asset(
          AppImages.smallHabitLogo,
          width: 94,
          height: 18,
          fit: BoxFit.contain,
        ),
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Image.asset(AppImages.hbLogo, width: 18, height: 18),
              const SizedBox(width: 6),
              Text(
                '$hb',
                style: const TextStyle(color: AppColors.dark),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: Image.asset(AppImages.cart, width: 22, height: 22),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ShoppingScreen(),
                ),
            );
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// =======================
///  프로필 헤더 (아바타 + 닉네임)
/// =======================
class HeaderProfile extends StatelessWidget {
  final String nickname;
  final String honorific;
  final String? avatarUrl;

  const HeaderProfile({
    super.key,
    required this.nickname,
    required this.honorific,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    const helloStyle = TextStyle(color: Colors.black, fontSize: 14);
    const nameBold = TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black);
    const titleStyle = TextStyle(
        fontSize: 17, fontWeight: FontWeight.w400, color: Colors.black);

    Widget avatarChild;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.camera_alt_outlined, color: AppColors.dark),
        ),
      );
    } else {
      avatarChild =
      const Icon(Icons.camera_alt_outlined, color: AppColors.dark);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.page,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xBFBF8D6A)),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(child: avatarChild),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('안녕하세요,', style: helloStyle),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: nickname, style: nameBold),
                    const TextSpan(text: '  '),
                    TextSpan(text: honorific, style: titleStyle),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// =======================
///  오늘의 진행도 카드
/// =======================
class TodayProgressCard extends StatelessWidget {
  final int maxGoals;
  final int doneGoals;
  const TodayProgressCard({
    super.key,
    required this.maxGoals,
    required this.doneGoals,
  });

  @override
  Widget build(BuildContext context) {
    final clampedMax = maxGoals <= 0 ? 1 : maxGoals;
    final clampedDone = doneGoals.clamp(0, clampedMax);
    final fraction = clampedDone / clampedMax;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.caramel,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Image.asset(
              AppImages.hotHash,
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '오늘의 따끈따끈한 해시브라운',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: fraction,
                    color: AppColors.redBar,
                    backgroundColor: AppColors.yellowRest,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 6),
                _TickLabels(count: maxGoals),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TickLabels extends StatelessWidget {
  final int count;
  const _TickLabels({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const Padding(
        padding: EdgeInsets.only(top: 2.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '0개',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(count + 1, (i) {
          return Text(
            '$i개',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.0,
            ),
          );
        }),
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? right;
  const _SectionHeaderRow({required this.title, this.icon, this.right});

  @override
  Widget build(BuildContext context) {
    final bool isFighting = title.contains('싸우고 있는 감자');

    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimens.pad, 12, Dimens.pad, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '· $title',
            style: const TextStyle(
              color: AppColors.dark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          if (isFighting)
            Image.asset(
              AppImages.kal,
              width: 22,
              height: 22,
            )
          else if (icon != null)
            Icon(icon, size: 18, color: AppColors.dark),
          const Spacer(),
          if (right != null) right!,
        ],
      ),
    );
  }
}

class _SectionActions extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  const _SectionActions({required this.onAdd, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(icon: Icons.add, onTap: onAdd),
        const SizedBox(width: 10),
        _RoundIcon(icon: Icons.edit_outlined, onTap: onEdit),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.yellow,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.redBar, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

typedef HabitChange = void Function();

class _HabitList extends StatelessWidget {
  final List<HomeHabit> habits;
  final HabitChange onChange;
  final VoidCallback onVerified;
  final bool isFighting;
  final String nickname;

  const _HabitList({
    required this.habits,
    required this.onChange,
    required this.onVerified,
    required this.isFighting,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      final emptyText = isFighting
          ? '교환한 습관이 여기에 추가돼요!!'
          : '+버튼을 눌러 만들고 싶은 나의 습관을 등록해봐요!';

      return SliverToBoxAdapter(
        child: Padding(
          padding:
          const EdgeInsets.only(left: 28, right: 16, top: 4, bottom: 14),
          child: Text(
            emptyText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ),
      );
    }

    final normal =
    habits.where((h) => h.status != HabitStatus.verified).toList();
    final done =
    habits.where((h) => h.status == HabitStatus.verified).toList();
    final ordered = [...normal, ...done];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.pad, vertical: 6),
      sliver: SliverList.separated(
        itemCount: ordered.length,
        itemBuilder: (_, i) => Align(
          alignment: const Alignment(-0.1, 0),
          child: FractionallySizedBox(
            widthFactor: 0.92,
            child: _HabitRow(
              h: ordered[i],
              onChange: onChange,
              onVerified: onVerified,
              index: i,
              isFighting: isFighting,
              nickname: nickname,
            ),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 18),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final HomeHabit h;
  final HabitChange onChange;
  final VoidCallback onVerified;
  final int index;
  final bool isFighting;
  final String nickname;

  const _HabitRow({
    required this.h,
    required this.onChange,
    required this.onVerified,
    required this.index,
    required this.isFighting,
    required this.nickname,
  });

  static const double _rowHeight = 82;
  static const double _pillWidth = 110;

  @override
  Widget build(BuildContext context) {
    final potatoImg = isFighting
        ? AppImages.angryGamja
        : (index.isEven ? AppImages.gamja1 : AppImages.gamja2);
    final leftColor =
    isFighting ? AppColors.fightingLeft : AppColors.yellowRest;

    return SizedBox(
      height: _rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: _rowHeight,
                  decoration: BoxDecoration(
                    color: leftColor,
                    border: const Border(
                      top: BorderSide(color: AppColors.brown, width: 1.2),
                      left: BorderSide(color: AppColors.brown, width: 1.2),
                      bottom: BorderSide(color: AppColors.brown, width: 1.2),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(60, 0, 40, 0),
                  alignment: Alignment.centerLeft,
                  child: _HabitInfo(h: h),
                ),
              ),
              SizedBox(
                width: _pillWidth,
                height: _rowHeight,
                child: _StatusPill(
                  h: h,
                  onChange: onChange,
                  onVerified: onVerified,
                  isFighting: isFighting,
                  nickname: nickname,
                ),
              ),
            ],
          ),
          Positioned(
            left: -24,
            top: -18,
            child: Image.asset(potatoImg, width: 72, height: 72),
          ),
        ],
      ),
    );
  }
}

class _HabitInfo extends StatelessWidget {
  final HomeHabit h;
  const _HabitInfo({required this.h});

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.dark,
      fontSize: 13.5,
    );
    const bodyStyle = TextStyle(
      color: AppColors.dark,
      fontSize: 11.5,
      height: 1.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          h.title,
          style: titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text('· 인증 시간: ${h.time}', style: bodyStyle),
        Text('· 인증 방법: ${h.method}', style: bodyStyle),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final HomeHabit h;
  final HabitChange onChange;
  final VoidCallback onVerified;
  final bool isFighting;
  final String nickname;

  const _StatusPill({
    required this.h,
    required this.onChange,
    required this.onVerified,
    required this.isFighting,
    required this.nickname,
  });

  bool _isExpired(HomeHabit h) {
    // 한국 시간 기준
    final now = DateTime.now();

    // 1) source.deadline 우선 사용 (직접 만든 습관)
    final src = h.source;
    if (src != null && src.deadline.isNotEmpty) {
      final parts = src.deadline.split(':');
      if (parts.length == 2) {
        final hh = int.tryParse(parts[0]);
        final mm = int.tryParse(parts[1]);
        if (hh != null && mm != null) {
          final deadlineToday =
          DateTime(now.year, now.month, now.day, hh, mm, 59);
          return now.isAfter(deadlineToday);
        }
      }
      // 여기서 return 하지 않고 h.time 파싱으로 이어지게 한다
    }

    // 2) time 문자열에서 HH:mm 형식 추출
    // 예: "인증 시간: 23:59까지", "20:00 ~ 24:00", "09:00", 기타 모든 문자열 대응
    final raw = h.time;
    final regex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = regex.firstMatch(raw);

    if (match != null) {
      int hh = int.parse(match.group(1)!);
      int mm = int.parse(match.group(2)!);

      // 24:00 → 23:59 처리
      if (hh == 24) {
        hh = 23;
        mm = 59;
      }

      final deadlineToday =
      DateTime(now.year, now.month, now.day, hh, mm, 59);

      return now.isAfter(deadlineToday);
    }

    // HH:mm 형식이 없다면 만료 아님
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const skipBg = Color(0xFFE0E0E0);
    const certBg = Color(0xFFF3BA37);

    if (h.certifiedToday && h.status == HabitStatus.pending) {
      h.status = HabitStatus.verified;
    }

    final expired = _isExpired(h);

    late Color topBg;
    late String topLabel;
    VoidCallback? topTap;

    Future<void> _goCert() async {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CertPage(
            userHabitId: h.userHabitId,
            habitTitle: h.title,
            method: h.method,
            deadline: h.source?.deadline,
            nickname: nickname,
            setup: h.source,
          ),
        ),
      );

      if (result == true) {
        h.status = HabitStatus.verified;
        h.certifiedToday = true;
        onChange();
        onVerified();
      }
    }

    if (expired && h.status == HabitStatus.pending) {
      topBg = Colors.grey.shade300;
      topLabel = '인증 시간 초과로 인증불가';
      topTap = null;
    } else {
      switch (h.status) {
        case HabitStatus.pending:
          topBg = certBg;
          topLabel = '인증하기';
          topTap = _goCert;
          break;
        case HabitStatus.skipped:
          topBg = skipBg;
          topLabel = '오늘은 스킵';
          topTap = null;
          break;
        case HabitStatus.verified:
          topBg = const Color(0xFFFFF8E1);
          topLabel = '인증완료';
          topTap = null;
          break;
      }
    }

    final bool showBottom =
        !(h.status == HabitStatus.verified && !isFighting) &&
            !(expired && h.status == HabitStatus.pending);

    String bottomLabel;
    Color bottomBg;
    Color bottomTextColor;

    if (isFighting) {
      bottomLabel = '라이벌 보러가기';
      bottomBg = AppColors.rivalBtn;
      bottomTextColor = AppColors.redBar;
    } else {
      if (h.status == HabitStatus.skipped) {
        bottomLabel = '다시 도전하기';
        bottomBg = skipBg;
        bottomTextColor = AppColors.dark;
      } else {
        bottomLabel = '오늘은 안할래';
        bottomBg = certBg;
        bottomTextColor = AppColors.dark;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.brown, width: 1.2),
          right: BorderSide(color: AppColors.brown, width: 1.2),
          bottom: BorderSide(color: AppColors.brown, width: 1.2),
          left: BorderSide(color: AppColors.brown, width: 1.2),
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: showBottom ? 2 : 3,
            child: InkWell(
              onTap: topTap,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: topBg,
                  borderRadius: showBottom
                      ? const BorderRadius.only(topRight: Radius.circular(18))
                      : const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Text(
                  topLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ),
          ),
          if (showBottom)
            Expanded(
              flex: 1,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isFighting) {
                    if (h.status == HabitStatus.skipped) {
                      h.status = HabitStatus.pending;
                    } else {
                      h.status = HabitStatus.skipped;
                    }
                    onChange();
                  }
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bottomBg,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.redBar.withAlpha(90),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    bottomLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: bottomTextColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 하단바
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
