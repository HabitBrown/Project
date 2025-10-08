import 'package:flutter/material.dart';

/// ================= 공통 테마(시안 기반) =================
class AppColors {
  static const cream = Color(0xFFFFF8E1);   // 배경
  static const green = Color(0xFFAFDBAE);   // 인증 버튼
  static const brown = Color(0xFFBF8D6A);   // 메인 포인트
  static const brick = Color(0xFFC32B2B);
  static const dark = Color(0xFF535353);    // 텍스트
  static const divider = Color(0xFFD8CBB6); // 라인
  static const danger = Color(0xFFE25B5B);  // 에러
  static const inputBg = Color(0xFFF6F1DC); // 인풋 배경
}

const LogoPath = 'lib/assets/image2/signup_logo.png';


class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _pwFocus = FocusNode();
  final _pwConfirmFocus = FocusNode();

  bool _isVerifyingPhone = false;
  bool _isPhoneVerified = false;
  bool _obscurePw = true;
  bool _obscurePwConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _pwFocus.dispose();
    _pwConfirmFocus.dispose();
    super.dispose();
  }

  // 더미: 서버 연동 없이 간단히 인증 성공 처리
  Future<void> _verifyPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty || !_isPhoneValid(phone)) {
      _showSnack('올바른 전화번호를 입력해 주세요.');
      return;
    }
    setState(() => _isVerifyingPhone = true);
    await Future.delayed(const Duration(seconds: 1)); // 로딩 연출
    setState(() {
      _isVerifyingPhone = false;
      _isPhoneVerified = true;
    });
    _showSnack('전화번호 인증 완료!');
  }

  bool _isPhoneValid(String v) {
    // 한국 휴대폰 간단 검사: 숫자만 10~11자리
    final onlyDigits = v.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^\d{10,11}$').hasMatch(onlyDigits);
  }

  bool get _canSubmit {
    return _formKey.currentState?.validate() == true && _isPhoneVerified;
  }

  void _onSubmit() {
    // 폼 검증 + 전화번호 인증 체크
    if (!_canSubmit) {
      _formKey.currentState?.validate();
      if (!_isPhoneVerified) _showSnack('전화번호 인증을 완료해 주세요.');
      return;
    }

    // TODO: 실제 회원가입 API 호출/처리

    // 사용자 피드백
    _showSnack('회원가입 완료! 🎉');

    // ✅ 회원가입 후 → 프로필 설정으로 이동 (뒤로가기 시 로그인으로 안 돌아가게 교체)
    Navigator.pushReplacementNamed(
      context,
      '/profileSetup',
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }


  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brown, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
    );
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (required)
            const Text('*', style: TextStyle(color: AppColors.danger)),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // 시안은 세로형, 폭을 살짝 제한해서 예쁘게 보이게
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: Image.asset(
                          LogoPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 이름
                    Align(alignment: Alignment.centerLeft, child: _fieldLabel('이름 :', required: true)),
                    TextFormField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                      decoration: _decoration('이름을 입력하세요'),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) return '이름을 입력해 주세요.';
                        return null;
                      },
                      onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),

                    // 전화번호 + 인증버튼
                    Align(alignment: Alignment.centerLeft, child: _fieldLabel('전화번호 :', required: true)),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            focusNode: _phoneFocus,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: _decoration('휴대폰 번호 (- 없이)'),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return '전화번호를 입력해 주세요.';
                              if (!_isPhoneValid(value)) return '전화번호 형식을 확인해 주세요.';
                              return null;
                            },
                            onChanged: (_) {
                              if (_isPhoneVerified) {
                                setState(() => _isPhoneVerified = false); // 번호 바꾸면 인증 해제
                              }
                            },
                            onFieldSubmitted: (_) => _pwFocus.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isPhoneVerified
                                  ? Colors.grey.shade500
                                  : AppColors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            onPressed: _isPhoneVerified || _isVerifyingPhone ? null : _verifyPhone,
                            child: _isVerifyingPhone
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : Text(_isPhoneVerified ? '완료' : '인증'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 비밀번호
                    Align(alignment: Alignment.centerLeft, child: _fieldLabel('비밀번호 :', required: true)),
                    TextFormField(
                      controller: _pwCtrl,
                      focusNode: _pwFocus,
                      obscureText: _obscurePw,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('영문/숫자 포함 8자 이상').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePw ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePw = !_obscurePw),
                        ),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                        if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(value)) {
                          return '영문과 숫자를 포함해 주세요.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _pwConfirmFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),

                    // 비밀번호 확인
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _fieldLabel('비밀번호 확인 :', required: true),
                    ),
                    TextFormField(
                      controller: _pwConfirmCtrl,
                      focusNode: _pwConfirmFocus,
                      obscureText: _obscurePwConfirm,
                      decoration: _decoration('비밀번호를 다시 입력').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePwConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePwConfirm = !_obscurePwConfirm),
                        ),
                      ),
                      validator: (v) {
                        if ((v ?? '') != _pwCtrl.text) return '비밀번호가 일치하지 않습니다.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 36),

                    // 회원가입 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.hovered)) {
                              return AppColors.brown;
                            }
                            if (states.contains(WidgetState.pressed)) {
                              return AppColors.brick;
                            }
                            return AppColors.brick;
                          }),
                          shape: const WidgetStatePropertyAll<OutlinedBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(26)),
                            ),
                          ),
                          elevation: const WidgetStatePropertyAll<double>(5.0),
                        ),
                        onPressed: _onSubmit,
                        child: const Text(
                          '회원가입하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 약관/정책 링크(옵션)
                    TextButton(
                      onPressed: () {/* TODO: 약관 페이지로 이동 */},
                      child: Text(
                        '가입하면 서비스 이용약관 및 개인정보 처리방침에 동의하게 됩니다.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.dark),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}