import 'package:flutter/material.dart';
import '../home/home_screen.dart'; // AppColors, AppImages 사용하려면 필요

class ShoppingScreen extends StatefulWidget {
  final int hbCount; // 보유한 해시 개수

  const ShoppingScreen({
    super.key,
    required this.hbCount,
  });

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  int _tab = 0; // 0 = 편의점, 1 = 음식점, 2 = 카페

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _TopBar(),
              ),

              /// =============================
              ///  상단 "보유 해시브라운"
              /// =============================
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF8E1),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '나의 보유 해시 브라운',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF68491A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Image.asset(
                            AppImages.hbLogo,
                            width: 70,
                            height: 70,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'X ${widget.hbCount}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF68491A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              /// =============================
              ///     교환 안내글 + 카테고리 탭
              /// =============================
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '해시 브라운과 상품을 교환해요!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF68491A),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _CategoryChip(
                            label: '편의점',
                            selected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: '음식점',
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: '카페',
                            selected: _tab == 2,
                            onTap: () => setState(() => _tab = 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              /// =============================
              ///          상품 리스트
              /// =============================
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _ItemTile(
                      img: 'lib/assets/image1/candy.png',
                      name: '츄파춥스',
                      cost: 500,
                    ),
                    _ItemTile(
                      img: 'lib/assets/image1/ghana.png',
                      name: '가나 초콜릿',
                      cost: 1200,
                    ),
                    _ItemTile(
                      img: 'lib/assets/image1/haribo.png',
                      name: '하리보',
                      cost: 800,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =============================
///   상단 뒤로가기 + 타이틀
/// =============================
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 45, 16, 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 26),
          ),
          const SizedBox(width: 14),
          const Text(
            '쇼핑하기',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================
///      카테고리 Chip
/// =============================
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : const Color(0xFFEDECEC),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF68491A) : Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// =============================
///        상품 1개 타일
/// =============================
class _ItemTile extends StatelessWidget {
  final String img;
  final String name;
  final int cost;

  const _ItemTile({
    required this.img,
    required this.name,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        children: [
          Container(
            width: 95,
            height: 95,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                img,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Image.asset(AppImages.hbLogo, width: 26, height: 26),
                    const SizedBox(width: 6),
                    Text(
                      'X $cost',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF68491A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}