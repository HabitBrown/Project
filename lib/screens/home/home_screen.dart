import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
/// =======================
///  공통 리소스 & 테마 정의
/// =======================
class AppImages {
  static const root = 'lib/assets/image1';
  static const smallHabitLogo = '$root/small_habit_logo.png';
  static const hbLogo         = '$root/HB_logo.png';
  static const cart           = '$root/cart.png';
  static const hotHash        = '$root/hot_hashbrown.png';
  // 목표 카드용 감자 아이콘(교대로 사용)
  static const gamja1         = '$root/gamja1.png';
  static const gamja2         = '$root/gamja2.png';
}

class AppColors {
  static const page     = Color(0xFFFFFFFF);
  static const cream    = Color(0xFFFFF8E1);
  static const brown    = Color(0xFFBF8D6A);
  static const dark     = Color(0xFF535353);
  static const yellow   = Color(0xFFF3C34E);
  static const chip     = Color(0xFFF6E89E);
  static const divider  = Color(0xFFE8E0D4);
  static const shadow   = Color(0x1F000000);

  // 진행바 색
  static const redBar      = Color(0xFFC32B2B);
  static const yellowRest  = Color(0xFFE9D973);

  // 카드 배경(시안 느낌 카라멜)
  static const caramel  = Color(0xFFA9783F);
}

class Dimens {
  static const pad = 16.0;
  static const r16 = 16.0;
  static const r24 = 24.0;
}

/// =======================
///  모델 정의
/// =======================
enum HabitStatus { pending, verified, skipped }

class HomeHabit {
  final String title;
  final String time;
  final String method;
  double progress;
  HabitStatus status;

  HomeHabit({
    required this.title,
    required this.time,
    required this.method,
    this.progress = 0.0,
    this.status = HabitStatus.pending,
  });
}

/// =======================
///  홈 화면
/// =======================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1;

  String nickname  = '망설이는 감자';
  String honorific = '농부님!';
  int _hb = 0;
  String? _avatarPath;

  // 가변 리스트
  late List<HomeHabit> _today;
  late List<HomeHabit> _fighting;

  bool _initialized = false;

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final nick = (prefs.getString('nickname') ?? '').trim();
    final name = (prefs.getString('name') ?? '').trim();

    if (!mounted) return;
    setState(() {
      nickname = nick.isNotEmpty ? nick : (name.isNotEmpty ? name : nickname);
    });

  }

  Future<void> _syncUserFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    try {
      final me = await AuthService().getUser(userId); // GET /auth/users/{id}

      // 1) 닉네임/이름 최신화
      final nick = (me['nickname'] ?? '').toString().trim();
      final name = (me['name'] ?? '').toString().trim();

      // 2) 잔고/아바타
      final balance = me['hb_balance'] is int ? me['hb_balance'] as int
          : int.tryParse('${me['hb_balance'] ?? 0}') ?? 0;
      final avatar  = (me['profile_picture'] ?? '').toString();
      final normalizedAvatar = (avatar.isEmpty || avatar == 'none') ? null : avatar;

      // 3) 캐시 갱신
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
        _avatarPath = normalizedAvatar;
      });
    } catch (_) {
      // 서버 실패해도 조용히 무시 (오프라인 대비)
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDisplayName(); // 로그인 시 닉네임 불러오기
    _syncUserFromServer();
  }

  // 로그인으로 바로 온 경우 사용할 기본(씨드) 데이터
  List<HomeHabit> _seedToday() => [
    HomeHabit(title: '자기 전 스트레칭하기', time: '20:00 ~ 24:00', method: '사진', progress: .62),
    HomeHabit(title: '퇴근 후 빨래 바로 돌리기', time: '18:00 ~ 20:00', method: '사진', progress: .25),
  ];
  List<HomeHabit> _seedFighting() => [
    HomeHabit(title: '아침에 물 한잔 마시기', time: '10:00 ~ 12:00', method: '사진', progress: .8),
    HomeHabit(title: '나갈 때 키 챙기기', time: '09:00 ~ 10:00', method: '사진', progress: .3),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map && args['nickname'] is String) {
      final fromProfile = (args['nickname'] as String).trim();
      if (fromProfile.isNotEmpty) {
        nickname = fromProfile; // 프로필 설정 직후 닉네임 반영
      }
      _today = [];
      _fighting = [];
    } else {
      // ▶ 일반 로그인→홈: 기본 목표 넣기
      _today = _seedToday();
      _fighting = _seedFighting();
    }

    _initialized = true;
    setState(() {});
  }

  // 진행바 값 계산
  int get _maxGoals => _today.length + _fighting.length;
  int get _doneGoals {
    int done(List<HomeHabit> list) =>
        list.where((h) => h.status == HabitStatus.verified).length;
    return done(_today) + done(_fighting);
  }

  void _rebuild() => setState(() {});

  // ===== 목표 추가 =====
  Future<void> _openAddHabitSheet({required bool toFighting}) async {
    final titleC = TextEditingController();
    final timeC  = TextEditingController();
    final methodC= TextEditingController(text: '사진');

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(toFighting ? '싸우고 있는 감자 추가' : '튀기기를 기다리는 감자 추가',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(decoration: const InputDecoration(labelText: '제목'), controller: titleC),
              TextField(decoration: const InputDecoration(labelText: '시간 (예: 20:00 ~ 24:00)'), controller: timeC),
              TextField(decoration: const InputDecoration(labelText: '방법'), controller: methodC),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleC.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('추가'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (added == true) {
      final h = HomeHabit(
        title: titleC.text.trim(),
        time:  timeC.text.trim().isEmpty ? '시간 미정' : timeC.text.trim(),
        method: methodC.text.trim().isEmpty ? '사진' : methodC.text.trim(),
      );
      setState(() {
        (toFighting ? _fighting : _today).add(h);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: Center(
        child: ConstrainedBox(
          // ▶ 전반적인 가로폭 축소(스크린샷 느낌)
          constraints: const BoxConstraints(maxWidth: 560),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _TopBar(hbBalance: _hb)),

              // 상단 크림 영역
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.cream,
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dimens.pad),
                        child: HeaderProfile(
                          nickname: nickname,
                          honorific: honorific.isEmpty ? '농부님!' : honorific,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Dimens.pad, 8, Dimens.pad, 0),
                        child: TodayProgressCard(maxGoals: _maxGoals, doneGoals: _doneGoals),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // ▶ 섹션/버튼은 항상 노출
              SliverToBoxAdapter(
                child: _SectionHeaderRow(
                  title: '튀기기를 기다리고 있는 감자',
                  right: _SectionActions(
                    onAdd: () => _openAddHabitSheet(toFighting: false),
                    onEdit: () {},
                  ),
                ),
              ),
              _HabitList(habits: _today, onChange: _rebuild),
              if (_today.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('아직 등록된 감자가 없어요. + 버튼으로 추가해 보세요.',
                        style: TextStyle(color: AppColors.dark)),
                  ),
                ),

              SliverToBoxAdapter(
                child: _SectionHeaderRow(
                  title: '싸우고 있는 감자',
                  icon: Icons.gavel,
                  right: _SectionActions(
                    onAdd: () => _openAddHabitSheet(toFighting: true),
                    onEdit: () {},
                  ),
                ),
              ),
              _HabitList(habits: _fighting, onChange: _rebuild),
              if (_fighting.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('여기도 비었네요. + 버튼으로 추가하세요.',
                        style: TextStyle(color: AppColors.dark)),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(index: _tab, onChanged: (i) => setState(() => _tab = i)),
    );
  }
}

/// =======================
///  상단바
/// =======================
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final int hbBalance;
  const _TopBar({required this.hbBalance});
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
        child: Image.asset(AppImages.smallHabitLogo, width: 94, height: 18, fit: BoxFit.contain),
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Image.asset(AppImages.hbLogo, width: 18, height: 18),
              const SizedBox(width: 6),
              Text('$hbBalance', style: const TextStyle(color: AppColors.dark)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton(icon: Image.asset(AppImages.cart, width: 22, height: 22), onPressed: () {}),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// =======================
///  공개: 프로필 & 인사말
/// =======================
class HeaderProfile extends StatelessWidget {
  final String nickname;
  final String honorific;
  const HeaderProfile({super.key, required this.nickname, required this.honorific});

  @override
  Widget build(BuildContext context) {
    const helloStyle = TextStyle(color: Colors.black, fontSize: 14);
    const nameBold   = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black);
    const titleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: Colors.black);

    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: AppColors.page,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xBFBF8D6A)),
              boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 5, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.camera_alt_outlined, color: AppColors.dark),
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
///  공개: 오늘의 해시브라운 카드
///   - max = 오늘/싸움 목표 수 합
///   - done = 인증완료 수
///   - 모두 완료 시 바가 100% 꽉 차게 표시
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
    final clampedMax  = maxGoals <= 0 ? 1 : maxGoals;
    final clampedDone = doneGoals.clamp(0, clampedMax);
    final fraction    = clampedDone / clampedMax;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.caramel,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Image.asset(AppImages.hotHash, width: 56, height: 56, fit: BoxFit.contain),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('오늘의 따끈따끈한 해시브라운',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                _SnappedProgressBar(fraction: fraction),
                const SizedBox(height: 6),
                _TickLabels(count: clampedMax),
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
    return SizedBox(
      height: 18,
      child: Stack(
        children: List.generate(count + 1, (i) {
          final frac = i / count;
          final ax   = -1.0 + 2.0 * frac;
          return Align(
            alignment: Alignment(ax, 0),
            child: Text('$i개', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          );
        }),
      ),
    );
  }
}

class _SnappedProgressBar extends StatelessWidget {
  final double fraction; // 0.0~1.0 (done/max)
  const _SnappedProgressBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    const h = 10.0;
    final r = h / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: h,
        child: LayoutBuilder(
          builder: (_, c) {
            final fullW = c.maxWidth;
            final effW  = fullW - 2 * r;
            final f     = fraction.clamp(0.0, 1.0);

            // ▶ 모두 완료(f==1)면 바를 '완전한 fullW'로 하여 끝이 남지 않게.
            final redW  = (f >= 1.0) ? fullW : (r + effW * f);

            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: AppColors.yellowRest),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: redW,
                    color: AppColors.redBar,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// =======================
///  섹션 타이틀 행(아이콘/액션 포함)
/// =======================
class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? right;
  const _SectionHeaderRow({required this.title, this.icon, this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimens.pad, 12, Dimens.pad, 4),
      child: Row(
        children: [
          Text('· $title',
              style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w700)),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 18, color: AppColors.dark),
          ],
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
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: IconButton(icon: Icon(icon, color: AppColors.redBar, size: 20), onPressed: onTap),
    );
  }
}

/// =======================
///  습관 카드 목록 & 카드
/// =======================
typedef HabitChange = void Function();

class _HabitList extends StatelessWidget {
  final List<HomeHabit> habits;
  final HabitChange onChange;
  const _HabitList({required this.habits, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.pad, vertical: 6),
      sliver: SliverList.separated(
        itemCount: habits.length,
        itemBuilder: (_, i) => _HabitRow(h: habits[i], onChange: onChange, index: i),
        separatorBuilder: (_, __) => const SizedBox(height: 18),
      ),
    );
  }
}

/// 한 줄(정보카드 + 상태버튼카드)
class _HabitRow extends StatelessWidget {
  final HomeHabit h;
  final HabitChange onChange;
  final int index;
  const _HabitRow({required this.h, required this.onChange, required this.index});

  static const double _rowHeight = 80;
  static const double _pillWidth = 110;

  @override
  Widget build(BuildContext context) {
    final potatoImg = index.isEven ? AppImages.gamja1 : AppImages.gamja2;

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
                    color: const Color(0xFFFFF8D6),
                    border: Border.all(color: AppColors.brown, width: 1.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(50, 10, 12, 10),
                  child: _HabitInfo(h: h),
                ),
              ),
              SizedBox(
                width: _pillWidth,
                height: _rowHeight,
                child: _StatusPill(h: h, onChange: onChange),
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
    const titleStyle = TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark, fontSize: 13.5);
    const bodyStyle  = TextStyle(color: AppColors.dark, fontSize: 11.5, height: 1.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(h.title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text('· 시간: ${h.time}', style: bodyStyle),
        Text('· 방법: ${h.method}', style: bodyStyle),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final HomeHabit h;
  final HabitChange onChange;
  const _StatusPill({required this.h, required this.onChange});

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late String bigLabel;
    String small = '오늘은 안할래';
    Color smallColor = AppColors.redBar;

    Future<void> _goCert() async {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const _DummyCertPage()),
      );
      if (result == true) {
        h.status = HabitStatus.verified;
        onChange();
      }
    }

    VoidCallback? bigTap;

    switch (h.status) {
      case HabitStatus.pending:
        bg = const Color(0xFFF3BA37);
        bigLabel = '인증하기';
        bigTap = _goCert;
        break;
      case HabitStatus.verified:
        bg = const Color(0xFFFFF8E1); // 요청 색
        bigLabel = '인증완료';
        bigTap = null;
        break;
      case HabitStatus.skipped:
        bg = Colors.grey.shade400;
        bigLabel = '스킵';
        small = '철회하고 인증하기';
        smallColor = AppColors.dark;
        bigTap = null;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: AppColors.brown, width: 1.2),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: bigTap,
              borderRadius: const BorderRadius.only(topRight: Radius.circular(18)),
              child: Center(
                child: Text(
                  bigLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ),
          ),
          Container(height: 1.2, color: AppColors.redBar.withAlpha(90)),
          Expanded(
            flex: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (h.status == HabitStatus.skipped) {
                  h.status = HabitStatus.pending;
                } else {
                  h.status = HabitStatus.skipped;
                }
                onChange();
              },
              child: Center(
                child: Text(
                  small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: smallColor,
                    decoration: TextDecoration.none,
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

/// 임시 인증 화면(완료 시 true 반환)
class _DummyCertPage extends StatelessWidget {
  const _DummyCertPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('인증 화면(임시)')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('인증 완료로 돌아가기'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
///  하단 네비게이션 바
/// =======================
class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: onChanged,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.page,
      selectedItemColor: AppColors.dark,
      unselectedItemColor: AppColors.dark.withOpacity(0.5),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.local_florist_outlined), label: '감자캐기'),
        BottomNavigationBarItem(icon: Icon(Icons.build_outlined),          label: '해시내기'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_none),      label: '알림'),
        BottomNavigationBarItem(icon: Icon(Icons.groups_outlined),         label: '커뮤니티'),
        BottomNavigationBarItem(icon: Icon(Icons.emoji_emotions_outlined), label: '마이페이지'),
      ],
    );
  }
}
