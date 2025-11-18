import 'dart:async';
import 'package:flutter/material.dart';
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
  static const camera  = '$root/camera.png';
  static const hash = '$root/hash.png';
}

class AppColors {
  // 화면 배경
  static const cream   = Color(0xFFFFF8E1);
  static const page    = cream;              // 👉 배경은 크림색으로

  // 기본 팔레트
  static const green   = Color(0xFFAFDBAE);
  static const brown   = Color(0xFFBF8D6A);
  static const brick   = Color(0xFFC32B2B);
  static const dark    = Color(0xFF535353);

  // 홈에서 쓰는 노란색들
  static const yellow  = Color(0xFFF3C34E);
  static const chip    = Color(0xFFF6E89E);

  // 공통 보더/섀도우
  static const divider = Color(0xFFE8E0D4);
  static const shadow  = Color(0x1F000000);

  // 폼/에러 (habit_setting.dart 에서 사용)
  static const danger  = Color(0xFFE25B5B);
  static const inputBg = Color(0xFFF6F1DC);

  // 진행바
  static const redBar      = Color(0xFFC32B2B);
  static const yellowRest  = Color(0xFFE9D973);

  // 카드 / 하단바
  static const caramel     = Color(0xFFA9783F);

  // 싸우고 있는 감자 카드 색
  static const fightingLeft = Color(0xFFECCA89);
  static const rivalBtn     = Color(0xFFF5CE73);

  static const lightBrown = Color(0xFFECCA89);
  static const chipYellow = Color(0xFFF0E27A);

}


class Dimens {
  static const pad = 16.0;
}

/// =======================
///  모델 정의
/// =======================
enum HabitStatus { pending, verified, skipped }

class HomeHabit {
  String title;
  String time;
  String method;
  HabitStatus status;
  HabitSetupData? source; // 설정에서 온 원본

  HomeHabit({
    required this.title,
    required this.time,
    required this.method,
    this.status = HabitStatus.pending,
    this.source,
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

  String nickname = '감자';
  String honorific = '농부님!';

  late List<HomeHabit> _today;
  late List<HomeHabit> _fighting;
  bool _initialized = false;

  List<HomeHabit> _seedToday() => [
    HomeHabit(
      title: '자기 전 스트레칭하기',
      time: '20:00 ~ 24:00',
      method: '사진',
    ),
    HomeHabit(
      title: '퇴근 후 빨래 바로 돌리기',
      time: '18:00 ~ 20:00',
      method: '사진',
    ),
  ];

  List<HomeHabit> _seedFighting() => [
    HomeHabit(
      title: '아침에 물 한잔 마시기',
      time: '10:00 ~ 12:00',
      method: '사진',
    ),
  ];

  @override
  void initState() {
    super.initState();

    if (widget.initialNickname != null &&
        widget.initialNickname!.trim().isNotEmpty) {
      nickname = widget.initialNickname!.trim();
    }

    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
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

    // ✅ 무조건 비워두기 (실제 설정에서만 채워짐)
    _today = [];
    _fighting = [];

    _initialized = true;
    setState(() {});
  }

  int get _maxGoals => _today.length + _fighting.length;
  int get _doneGoals {
    int done(List<HomeHabit> list) =>
        list.where((h) => h.status == HabitStatus.verified).length;
    return done(_today) + done(_fighting);
  }

  // ✅ 여기만 수정: 인증해도 HB / 보너스 안 올림
  void _onHabitVerified() {
    setState(() {
      // 해시 재화 관련 로직 제거 (UI만 다시 그림)
      // _hb += 2;
      // if (!_dailyBonusGiven && _maxGoals > 0 && _doneGoals == _maxGoals) {
      //   _hb += 5;
      //   _dailyBonusGiven = true;
      // }
    });
  }

  void _rebuild() => setState(() {});

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

    final timeLabel = '${result.deadline} 까지';
    final methodLabel = result.certType == CertType.photo ? '사진' : '글';

    setState(() {
      if (editing == null) {
        final newHabit = HomeHabit(
          title: result.title,
          time: timeLabel,
          method: methodLabel,
          source: result,
        );
        (toFighting ? _fighting : _today).add(newHabit);
      } else {
        final list = toFighting ? _fighting : _today;
        final idx = index ?? list.indexOf(editing);
        if (idx >= 0) {
          list[idx]
            ..title = result.title
            ..time = timeLabel
            ..method = methodLabel
            ..source = result;
        }
      }
    });
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
                        padding:
                        const EdgeInsets.symmetric(horizontal: Dimens.pad),
                        child: HeaderProfile(
                          nickname: nickname,
                          honorific: honorific,
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
            // 감자캐기
            Navigator.pushNamed(
              context,
              '/potato',
              arguments: {'hbCount': _hb},
            );
          } else if (i == 1) {
            // 해시내기
            Navigator.pushNamed(
              context,
              '/hash',
              arguments: {'hbCount': _hb},
            );
          } else if (i == 3) {
            // 알림
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AlarmScreen(),
              ),
            );
          } else if (i == 4) {
            // 마이페이지
            Navigator.pushNamed(
              context,
              '/mypage',
              arguments: {'hbCount': _hb},
            );
          } else {
            // 2: 홈화면
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
        IconButton(
          icon: Image.asset(AppImages.cart, width: 22, height: 22),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShoppingScreen(
                  hbCount: hb, // ✅ 현재 보유 해시브라운 수 전달
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 6),
      ],
    );
  }
}

class HeaderProfile extends StatelessWidget {
  final String nickname;
  final String honorific;
  const HeaderProfile({
    super.key,
    required this.nickname,
    required this.honorific,
  });

  @override
  Widget build(BuildContext context) {
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
            child:
            const Icon(Icons.camera_alt_outlined, color: AppColors.dark),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('안녕하세요,',
                  style: TextStyle(color: Colors.black, fontSize: 14)),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: nickname,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: honorific,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: Colors.black),
                    ),
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
    final done = habits.where((h) => h.status == HabitStatus.verified).toList();
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
        Text('· 인증 시간: ${h.time}', style: bodyStyle, maxLines:1, ),
        Text('· 인증 방법: ${h.method}', style: bodyStyle, maxLines:1),
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
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));

    final src = h.source;
    if (src != null) {
      final parts = src.deadline.split(':'); // "23:59"
      if (parts.length == 2) {
        final hh = int.tryParse(parts[0]);
        final mm = int.tryParse(parts[1]);
        if (hh != null && mm != null) {
          final deadlineToday =
          DateTime(now.year, now.month, now.day, hh, mm, 59);
          return now.isAfter(deadlineToday);
        }
      }
      return false;
    }

    final t = h.time;
    if (t.contains('~')) {
      final right = t.split('~').last.trim(); // "20:50"
      final parts = right.split(':');
      if (parts.length == 2) {
        int? hh = int.tryParse(parts[0]);
        int? mm = int.tryParse(parts[1]);
        if (hh != null && mm != null) {
          if (hh == 24) {
            hh = 23;
            mm = 59;
          }
          final deadlineToday =
          DateTime(now.year, now.month, now.day, hh, mm, 59);
          return now.isAfter(deadlineToday);
        }
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    const skipBg = Color(0xFFE0E0E0);
    const certBg = Color(0xFFF3BA37);

    final expired = _isExpired(h);

    late Color topBg;
    late String topLabel;
    VoidCallback? topTap;

    Future<void> _goCert() async {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CertPage(
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


//하단바
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

    final Color labelColor = selected
        ? Colors.black87
        : Colors.black87.withOpacity(0.5);

    final FontWeight labelWeight = isHome
        ? FontWeight.w500
        : (selected ? FontWeight.w600 : FontWeight.w400);

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
