// lib/state/hb_state.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../core/base_url.dart'; // 필요없으면 제거

class HbState {
  HbState._();
  static final HbState instance = HbState._();

  // 앱 전체에서 구독하는 HB 상태
  final ValueNotifier<int> hb = ValueNotifier<int>(0);

  // 앱 시작 시: 로컬값 먼저 읽고
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getInt('hb_balance') ?? 0;
    hb.value = local;
  }

  // 서버에서 다시 동기화
  Future<void> refreshFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    final me = await AuthService().getUser(userId);
    final balance = me['hb_balance'] is int
        ? me['hb_balance'] as int
        : int.tryParse('${me['hb_balance'] ?? 0}') ?? 0;

    hb.value = balance;
    await prefs.setInt('hb_balance', balance);
  }

  // 어떤 화면에서든 직접 값 바꾸고 싶을 때
  Future<void> setBalance(int newValue) async {
    hb.value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hb_balance', newValue);
  }

  // delta 만큼 증/감 (예: 보상 +500, 구매 -500)
  Future<void> changeBy(int delta) async {
    await setBalance(hb.value + delta);
  }
}
