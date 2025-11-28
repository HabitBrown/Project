import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pbl_front/screens/home/shopping_screen.dart';

// 이 파일에서는 Home 쪽에 있는 색/이미지 정의를 가져온다고 했으니까 그대로 둡니다.
// home_screen.dart 안에 AppColors, AppImages 가 있다고 가정
import '../../core/base_url.dart';
import '../../models/farmer.dart';
import '../../services/exchange_service.dart';
import '../../services/potato_service.dart';
import 'home_screen.dart';
import 'hash_screen.dart';

// 교환 설정 화면/DTO
import 'habit_setting.dart' show HabitSetupData, CertType;
import 'fight_setting.dart';

class PotatoScreen extends StatefulWidget {
  const PotatoScreen({
    super.key,
    required this.hbCount,
    this.me,
    this.onHbChanged, // 👈 홈이 넘겨주는 콜백
  });

  final int hbCount;
  final Map<String, dynamic>? me;
  final ValueChanged<int>? onHbChanged; // 👈 해시내기에서 올라오는 HB를 다시 홈으로 전달

  @override
  State<PotatoScreen> createState() => _PotatoScreenState();
}

class _PotatoScreenState extends State<PotatoScreen> {
  final ScrollController _mateCtrl = ScrollController();

  // 이 화면에서 실제로 보여줄 HB
  late int _hb;

  // 위 캐러셀에 나오는 사람들
  List<Map<String, dynamic>> fellowFarmers = [];

  // 추천 농부
  List<FarmerSummary> recommendedFarmers = [];

  // 검색어
  String _searchKeyword = '';

  // 2) _loadData에서 더미 제거하고, 서비스 호출로 교체
  final _potatoService = PotatoService();

  @override
  void initState() {
    super.initState();
    _hb = widget.hbCount;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 라우트로 들어오면서 hbCount를 넘겨줄 수도 있으니 한 번 더 체크
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hbCount'] is int) {
      _hb = args['hbCount'] as int;
    } else {
      _hb = widget.hbCount;
    }
  }

  Future<void> _loadData() async {
    try {
      final farmers = await _potatoService.fetchFarmers();
      setState(() {
        recommendedFarmers = farmers;

        fellowFarmers = farmers
            .where((f) => f.isFollowing)
            .map((f) => {
              'userId': f.userId,
              'name': f.name,
              'avatarUrl': f.avatarUrl,
            })
            .toList();
      });
    } catch (e) {
      // 에러 핸들링 (스낵바 등)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추천 농부 불러오기 실패: $e')),
      );
    }
  }

  /// 검색
  List<FarmerSummary> _filterByKeyword(String keyword) {
    if (keyword.trim().isEmpty) return recommendedFarmers;
    final kw = keyword.toLowerCase();

    return recommendedFarmers.where((farmer) {
      final name = farmer.name.toLowerCase();
      final bio = farmer.bio.toLowerCase();
      final tags = farmer.tags.map((e) => e.toLowerCase());
      final hashes = farmer.hashes.map((h) => h.title.toLowerCase());

      if (name.contains(kw)) return true;
      if (bio.contains(kw)) return true;
      if (tags.any((t) => t.contains(kw))) return true;
      if (hashes.any((h) => h.contains(kw))) return true;
      return false;
    }).toList();
  }

  /// 팔로우 → 위 캐러셀에 추가
  Future<void> _handleFollow(FarmerSummary farmer) async {
    try {
      await _potatoService.followFarmer(farmer.userId);

      setState(() {
        // fellowFarmers 업데이트
        final exists = fellowFarmers.any((f) => f['userId'] == farmer.userId);
        if (!exists) {
          fellowFarmers.add({
            'userId': farmer.userId,
            'name': farmer.name,
            'avatarUrl': farmer.avatarUrl,
          });
        }

        // recommendedFarmers 안의 isFollowing도 true로 바꿔주기
        recommendedFarmers = recommendedFarmers.map((f) {
          if (f.userId == farmer.userId) {
            return FarmerSummary(
              userId: f.userId,
              name: f.name,
              bio: f.bio,
              tags: f.tags,
              avatarUrl: f.avatarUrl,
              hashes: f.hashes,
              isFollowing: true,
            );
          }
          return f;
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('팔로우 실패: $e')),
      );
    }
  }

  /// 언팔로우 → 캐러셀에서 제거
  Future<void> _handleUnfollow(FarmerSummary farmer) async {
    try {
      await _potatoService.unfollowFarmer(farmer.userId);

      setState(() {
        fellowFarmers.removeWhere((f) => f['userId'] == farmer.userId);

        recommendedFarmers = recommendedFarmers.map((f) {
          if (f.userId == farmer.userId) {
            return FarmerSummary(
              userId: f.userId,
              name: f.name,
              bio: f.bio,
              tags: f.tags,
              avatarUrl: f.avatarUrl,
              hashes: f.hashes,
              isFollowing: false,
            );
          }
          return f;
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('언팔로우 실패: $e')),
      );
    }
  }

  void _scrollLeft() {
    if (_mateCtrl.hasClients) {
      final next = (_mateCtrl.offset - 80)
          .clamp(0.0, _mateCtrl.position.maxScrollExtent);
      _mateCtrl.animateTo(
        next,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollRight() {
    if (_mateCtrl.hasClients) {
      final next = (_mateCtrl.offset + 80)
          .clamp(0.0, _mateCtrl.position.maxScrollExtent);
      _mateCtrl.animateTo(
        next,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
  }

  /// 교환하기 → fight_setting.dart 열기
  Future<void> _openFightSetting(HashSummary hash) async {
    
    final String habitTitle = hash.title;
    final int baseDifficulty = hash.difficulty;

    final int targetHabitId = hash.hashId;

    final String defaultDeadline = hash.deadline;
    final CertType defaultCertType = hash.certType; // 인증 방식(수정 불가)

    final result = await Navigator.push<HabitSetupData>(
      context,
      MaterialPageRoute(
        builder: (_) => FightSettingPage(
          targetTitle: habitTitle,              // ✅ 새 생성자 이름
          initialDifficulty: baseDifficulty,    // ✅ 난이도 기본값
          initialCertType: defaultCertType,     // ✅ 인증 방식
          initialDeadline: defaultDeadline,     // ✅ 기본 마감 시간
        ),
      ),
    );

    if (!mounted || result == null) return;

    try {
      await ExchangeService().sendExchangeRequest(result, targetHabitId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교환 요청을 보냈어요!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('교환 요청 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearching = _searchKeyword.trim().isNotEmpty;
    final visibleFarmers =
    isSearching ? _filterByKeyword(_searchKeyword) : recommendedFarmers;

    return Scaffold(
      // 전체 배경 흰색
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: CustomScrollView(
            slivers: [
              // 상단바
              SliverToBoxAdapter(
                child: _PotatoTopBar(hbCount: _hb),
              ),

              // 상단 설명 카드
              const SliverToBoxAdapter(child: _PotatoHeaderWrapper()),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),

              // 동료 농부
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '동료 농부',
                        style: TextStyle(
                          color: AppColors.dark,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 100,
                        child: Stack(
                          children: [
                            // 리스트
                            Positioned.fill(
                              left: 46,
                              right: 46,
                              child: ListView.separated(
                                controller: _mateCtrl,
                                scrollDirection: Axis.horizontal,
                                itemCount: fellowFarmers.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  // 빈칸
                                  if (index >= fellowFarmers.length) {
                                    return Column(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFFD9D9D9),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const SizedBox(
                                          width: 60,
                                          height: 12,
                                        ),
                                      ],
                                    );
                                  }

                                  final farmer = fellowFarmers[index];
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _ProfileCircle(
                                        size: 58,
                                        avatarPath:
                                        farmer['avatarUrl'] as String?,
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          farmer['name'] ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            // 왼쪽 화살표
                            Positioned(
                              left: 0,
                              top: 30,
                              child: _CircleArrow(
                                icon: Icons.arrow_back,
                                onTap: _scrollLeft,
                              ),
                            ),
                            // 오른쪽 화살표
                            Positioned(
                              right: 0,
                              top: 30,
                              child: _CircleArrow(
                                icon: Icons.arrow_forward,
                                onTap: _scrollRight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 30)),

              // 검색 박스
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SearchBox(
                    onSearch: (keyword) {
                      setState(() {
                        _searchKeyword = keyword;
                      });
                    },
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(height: isSearching ? 22 : 90),
              ),

              // 추천 / 검색 결과
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isSearching) const _RecommendButton(),
                      if (!isSearching) const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleFarmers.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 55),
                        itemBuilder: (context, index) {

                          final data = visibleFarmers[index];
                          final isFollowing = fellowFarmers.any((f) => f['userId'] == data.userId);
                          return _FarmerCard(
                            name: data.name,
                            bio: data.bio,
                            tags: data.tags,
                            hashes: data.hashes,
                            avatarPath: data.avatarUrl,
                            isFollowing: data.isFollowing,
                            myHb: _hb,
                            onFollow: () => _handleFollow(data),
                            onUnfollow: () => _handleUnfollow(data),
                            onExchangeHash: (hash) => _openFightSetting(hash),
                          );
                        },
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _PotatoBottomBar(
        index: 0,
        onChanged: (i) {
          if (i == 0) return; // 현재 탭
          if (i == 1) {
            // 해시내기로 갈 때 지금 가진 HB 넘기고, 거기서 바뀌면 여기에도 반영 + 위에도 반영
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HashScreen(
                  hbCount: _hb,
                  onHbChanged: (v) {
                    setState(() => _hb = v); // 이 화면 숫자 갱신
                    widget.onHbChanged?.call(v); // 홈에도 올려보내기
                  },
                ),
              ),
            );
          } else {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

/// =========================
///  위젯들
/// =========================

class _PotatoTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _PotatoTopBar({required this.hbCount});
  final int hbCount;

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      toolbarHeight: 84,
      leadingWidth: 140,
      leading: Padding(
        padding: const EdgeInsets.only(left: 6, top: 10),
        child: InkWell(
          // 무조건 홈으로
          onTap: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
                  (route) => false,
            );
          },
          child: Image.asset(
            AppImages.smallHabitLogo,
            width: 94,
            height: 18,
            fit: BoxFit.contain,
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF6E08F),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE2B65A), width: 1),
          ),
          child: Row(
            children: [
              Image.asset(AppImages.hbLogo, width: 20, height: 20),
              const SizedBox(width: 6),
              Text(
                '$hbCount',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
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
                    builder:  (_) => ShoppingScreen(
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

class _PotatoHeaderWrapper extends StatelessWidget {
  const _PotatoHeaderWrapper();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: const _PotatoHeaderCard(),
    );
  }
}

class _PotatoHeaderCard extends StatelessWidget {
  const _PotatoHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFBF8D6A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 4),
            child: Image.asset(
              'lib/assets/image1/homi2.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2),
                Text(
                  '감자캐기!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '다른 사람의 습관을 보고 마음에 드는 습관을 가져오거나 교환할 수 있어요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCircle extends StatelessWidget {
  const _ProfileCircle({
    required this.size,
    this.avatarPath,
  });

  final double size;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarPath != null &&
        avatarPath!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
          '$kBaseUrl${avatarPath!}',
          fit: BoxFit.cover,
        )
            : Container(color: const Color(0xFFDADADA),
        ),
      ),
    );
  }
}

class _CircleArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFFD8892B),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({this.onSearch});
  final ValueChanged<String>? onSearch;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final TextEditingController _controller = TextEditingController();

  void _doSearch() {
    widget.onSearch?.call(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brown, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 105,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFB57C4E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: const Text(
              '감자 찾기',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '관심있는 키워드를 입력하세요',
                  hintStyle: TextStyle(fontSize: 12.5, color: Colors.black45),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _doSearch(),
              ),
            ),
          ),
          InkWell(
            onTap: _doSearch,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.search, color: AppColors.brown),
            ),
          )
        ],
      ),
    );
  }
}

class _RecommendButton extends StatelessWidget {
  const _RecommendButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF2C94C),
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFC98A38), width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: () {},
        child: const Text(
          '추천 농부',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  const _FarmerCard({
    required this.name,
    required this.bio,
    required this.tags,
    required this.hashes,
    required this.avatarPath,
    required this.isFollowing,
    required this.onUnfollow,
    required this.onFollow,
    required this.onExchangeHash,
    required this.myHb
  });

  final String name;
  final String bio;
  final List<String> tags;
  final List<HashSummary> hashes;
  final String? avatarPath;
  final bool isFollowing;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;
  final void Function(HashSummary hash) onExchangeHash;
  final int myHb;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileCircle(size: 58, avatarPath: avatarPath),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: isFollowing ? onUnfollow : onFollow,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isFollowing
                                ? const Color(0xFFBAD3EC)
                                : const Color(0xFF83A9CE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isFollowing ? '팔로잉' : '팔로우',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('관심사:  ', style: TextStyle(fontSize: 11)),
                      ...tags.map((t) => _Tag(t)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bio,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MadeHashBrownBox(
          hashes: hashes,
          myHb: myHb,
          onExchangeHash: onExchangeHash,
        ),
      ],
    );
  }
}

class _MadeHashBrownBox extends StatelessWidget {

  const _MadeHashBrownBox({
    required this.hashes,
    required this.myHb,
    this.onExchangeHash,
  });

  final List<HashSummary> hashes;
  final int myHb;
  final void Function(HashSummary hash)? onExchangeHash;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Column(
              children: [
                for (final h in hashes)
                  _MadeHashRow(
                    title: h.title,
                    difficulty: h.difficulty,
                    disabled: h.difficulty > myHb,
                    onExchange: () => onExchangeHash?.call(h),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            top: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF8E8B2),
                border: Border.all(color: Colors.black87, width: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '만든 해시브라운',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MadeHashRow extends StatelessWidget {
  const _MadeHashRow({
    required this.title,
    required this.difficulty,
    required this.onExchange,
    required this.disabled,
  });

  final String title;
  final int difficulty;
  final VoidCallback onExchange;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Color titleColor =
    disabled ? Colors.black38 : Colors.black87;
    final Color chipBg =
    disabled ? const Color(0xFFDDDDDD) : const Color(0xFFAFDBAE);
    final Color chipTextColor =
    disabled ? Colors.black45 : Colors.black87;

    final Color buttonBg = disabled
        ? const Color(0xFFE5E5E5)
        : const Color(0xFF9A9C06);
    final Color buttonTextColor =
    disabled ? Colors.grey[700]! : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // 감자 아이콘
          Image.asset(
            'lib/assets/image1/mini_hash.png',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),

          // 제목 + 난이도 칩을 한 줄에 붙여서
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400, // 더 얇게
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '난이도: $difficulty',
                        style: TextStyle(
                          fontSize: 10, // 더 작게
                          fontWeight: FontWeight.w400,
                          color: chipTextColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Image.asset(
                        'lib/assets/image1/level_hash.png',
                        width: 14,
                        height: 14,
                        fit: BoxFit.contain,
                        color: disabled ? Colors.grey[500] : null,
                      ),
                    ],
                  ),
                ),
                if(disabled)
                  const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                          '해시 부족',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.redAccent,
                          ),
                      ),
                  )
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 교환하기 버튼
          SizedBox(
            height: 28,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: buttonTextColor,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: (){
                if(disabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content : Text('보유 해시가 부족해서 교환할 수 없어요.'),
                      ),
                    );
                  return;
                }
                onExchange();
              },
              child: const Text(
                '교환하기',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF2C94C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5),
      ),
    );
  }
}

/// 하단바
class _PotatoBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _PotatoBottomBar({required this.index, required this.onChanged});

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
    // 👉 순서: 감자캐기 / 해시내기 / 홈화면(HB) / 알림 / 마이페이지
    const labels = ['감자캐기', '해시내기', '홈화면', '알림', '마이페이지'];

    // 각 인덱스별 아이콘
    Widget icon;
    switch (index) {
      case 0: // 감자캐기
        icon = Image.asset(
          AppImages.bottomDig,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
      case 1: // 해시내기
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
      case 3: // 알림
        icon = Image.asset(
          AppImages.alarm,
          width: 33,
          height: 33,
          fit: BoxFit.contain,
        );
        break;
      case 4: // 마이페이지
      default:
        icon = Image.asset(
          AppImages.bottomMyPage,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        );
        break;
    }

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
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.black87
                        : Colors.black87.withOpacity(0.5),
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

