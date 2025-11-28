// lib/screens/shopping/shopping_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pbl_front/core/base_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AppColors, AppImages 는 기존 home_screen.dart 에 있다고 가정
import '../home/home_screen.dart';


const bool DUMMY_MODE = false;
const int dummyBalance = 500;

/// dummy data infos
///  백엔드 연결 후  DUMMY_MODE 만 false로 바꿔 주시면 됩니다.
///
// 더미 상품 리스트
final List<ShopItem> dummyItems = [
  ShopItem(
    id: 1,
    name: "츄파춥스",
    priceHb: 500,
    category: "convenience",
    imageUrl: null,
  ),
  ShopItem(
    id: 2,
    name: "가나 초콜릿",
    priceHb: 1200,
    category: "convenience",
    imageUrl: null,
  ),
  ShopItem(
    id: 3,
    name: "하리보",
    priceHb: 800,
    category: "convenience",
    imageUrl: null,
  ),
  ShopItem(
    id: 4,
    name: "병다방 카페라떼",
    priceHb: 1500,
    category: "cafe",
    imageUrl: null,
  ),
  ShopItem(
    id: 5,
    name: "맘스터치 사이버거",
    priceHb: 1800,
    category: "restaurant",
    imageUrl: null,
  ),
];



/// =============================================================
///  1. 백엔드 DB 모델에 맞춘 Dart 모델 정의
///    - ShopItem
///    - Order
/// =============================================================



class ShopItem {
  final int id;
  final String name;
  final int priceHb;
  final String? category;   // 예: "profile", "theme", "booster" 등
  final String? imageUrl;

  ShopItem({
    required this.id,
    required this.name,
    required this.priceHb,
    this.category,
    this.imageUrl,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as int,
      name: json['name'] as String,
      priceHb: json['price_hb'] as int,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

typedef OrderStatus = String; // "placed" 등 문자열 상태

class Order {
  final int id;
  final int userId;
  final int? itemId;
  final OrderStatus status;
  final DateTime createdAt;
  final ShopItem? item;

  Order({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.status,
    required this.createdAt,
    this.item,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      itemId: json['item_id'] as int?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      item: json['item'] != null
          ? ShopItem.fromJson(json['item'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// =============================================================
///  2. Shop API 호출용 헬퍼 클래스
///
///  ⚠️ 실제 백엔드 스펙에 따라
///   - baseUrl
///   - endpoint 경로
///   - header (Authorization 등)
///   - 응답 JSON 구조
///  를 꼭 맞춰서 수정해야 한다!
/// =============================================================

class ShopApi {
  static const String baseUrl = kBaseUrl;

  static Future<Map<String, String>> _headers() async {

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 유저의 현재 HB 잔액 가져오기
  ///
  /// 예시: GET /me/wallet  -> { "hb_balance": 1200 }
  static Future<int> fetchHbBalance() async {
    if (DUMMY_MODE) {
      await Future.delayed(const Duration(milliseconds: 400));
      return dummyBalance;
    }

    final uri = Uri.parse('$baseUrl/me/wallet');

    final headers = await _headers();
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('HB 잔액 조회 실패 (status: ${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['hb_balance'] as int;
  }

  /// 전체 상품 목록 가져오기
  ///
  /// 예시: GET /shop/items  -> ShopItem[]
  ///  백엔드에서 카테고리 필터를 지원한다면
  ///  /shop/items?category=profile 이런 식으로 쿼리 파라미터로 넘겨도 됨.
  static Future<List<ShopItem>> fetchShopItems() async {
    if (DUMMY_MODE) {
      await Future.delayed(const Duration(milliseconds: 400));
      return dummyItems;
    }

    final headers = await _headers();
    final uri = Uri.parse('$baseUrl/shop/items');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('상품 목록 조회 실패 (status: ${res.statusCode})');
    }

    final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 상품 주문(교환) 요청
  ///
  /// 예시: POST /shop/orders  body: { "item_id": 1 }
  ///  응답: Order 객체 (item 포함 가능)
  ///
  /// ⚠️ 실제로는 응답에 "새로운 hb_balance" 를 같이 내려주도록
  ///    백엔드에 요청하면, FE에서 더 안전하게 잔액을 맞출 수 있다.
  static Future<Order> placeOrder({required int itemId}) async {
    if (DUMMY_MODE) {
      await Future.delayed(const Duration(milliseconds: 400));

      // 가짜 주문 생성
      return Order(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: 1,
        itemId: itemId,
        status: "placed",
        createdAt: DateTime.now(),
        item: dummyItems.firstWhere((e) => e.id == itemId),
      );
    }

    final headers = await _headers();
    final uri = Uri.parse('$baseUrl/shop/orders');

    final body = jsonEncode({'item_id': itemId});
    final res = await http.post(uri, headers: headers, body: body);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('주문 실패 (status: ${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await fetchHbBalance();
    return Order.fromJson(data);
  }
}

/// =============================================================
///  3. 쇼핑 화면 ShoppingScreen
///   - hbBalance: 백엔드에서 가져옴
///   - items: ShopItem 리스트도 백엔드에서 가져옴
///   - 탭별 category 필터링
///   - 구매 시: HB 차감 + 주문 API 호출
/// =============================================================

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  int _tab = 0; // 0 = 편의점, 1 = 음식점, 2 = 카페 (UI 기준)
  bool _isLoading = true;
  String? _errorMessage;

  int _hbBalance = 0;
  List<ShopItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// 최초 진입 시 HB 잔액 + 상품 목록을 같이 가져옴
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ShopApi.fetchHbBalance(),
        ShopApi.fetchShopItems(),
      ]);

      setState(() {
        _hbBalance = results[0] as int;
        _items = results[1] as List<ShopItem>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '쇼핑 정보를 불러오는 데 실패했어요.\n$e';
        _isLoading = false;
      });
    }
  }

  /// 탭 인덱스를 DB category 값으로 매핑
  ///
  /// 백엔드 category 예시는 "profile", "theme", "booster" 라고 되어 있는데,
  /// 현재 UI는 "편의점 / 음식점 / 카페" 이므로
  /// 실제 백엔드와 맞춰서 아래 매핑을 바꿔야 한다.
  String? _categoryForTab(int tab) {
    switch (tab) {
      case 0:
        return 'convenience'; // TODO: 백엔드에서 사용하는 실제 문자열로 변경
      case 1:
        return 'restaurant';  // TODO
      case 2:
        return 'cafe';        // TODO
      default:
        return null;
    }
  }

  List<ShopItem> get _filteredItems {
    final cat = _categoryForTab(_tab);
    if (cat == null) return _items;
    return _items.where((item) => item.category == cat).toList();
  }

  /// 상품 교환(주문) 흐름
  Future<void> _buyItem(ShopItem item) async {
    if (_hbBalance < item.priceHb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해시 브라운이 부족해요 😭')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('상품 교환'),
        content: Text('${item.name}을(를) ${item.priceHb} HB로 교환할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('교환'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      setState(() => _isLoading = true);

      final order = await ShopApi.placeOrder(itemId: item.id);

      // ⚠️ 여기서는 "서버가 주문 성공했다"는 가정하에
      //     프론트에서 hbBalance를 직접 차감.
      //     실제론 백엔드에서 "새로운 hb_balance"를 내려주면
      //     그 값을 사용하는 게 가장 안전하다.
      setState(() {
        _hbBalance -= item.priceHb;
        _isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hb_balance', _hbBalance);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.name} 교환 완료! (주문번호: ${order.id})',
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교환에 실패했어요. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadInitialData,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          )
              : CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: _TopBar(),
              ),

              /// 상단 "보유 해시 브라운"
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF8E1),
                  padding:
                  const EdgeInsets.fromLTRB(24, 28, 24, 30),
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
                            'X $_hbBalance',
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

              /// 교환 안내 + 카테고리 탭
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 26),
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
                            onTap: () =>
                                setState(() => _tab = 0),
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: '음식점',
                            selected: _tab == 1,
                            onTap: () =>
                                setState(() => _tab = 1),
                          ),
                          const SizedBox(width: 10),
                          _CategoryChip(
                            label: '카페',
                            selected: _tab == 2,
                            onTap: () =>
                                setState(() => _tab = 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              /// 상품 리스트
              if (filtered.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        '해당 카테고리의 상품이 없어요 😢',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final item = filtered[index];
                      return _ItemTile(
                        item: item,
                        onTap: () => _buyItem(item),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =============================================================
///  상단 뒤로가기 + 타이틀
/// =============================================================

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================================================
///  카테고리 Chip
/// =============================================================

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

/// =============================================================
///  상품 타일
/// =============================================================

class _ItemTile extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
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
                child: imageUrl == null || imageUrl.isEmpty
                    ? const Icon(Icons.fastfood, size: 40)
                    : Image.network(
                  imageUrl,
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
                    item.name,
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
                        'X ${item.priceHb}',
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
      ),
    );
  }
}
