import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/verify_email_screen.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

class _FakeOtpAuth extends ChangeNotifier implements AuthProvider {
  int verifyCalls = 0;
  int resendCalls = 0;
  int signOutCalls = 0;
  String? email;
  String? token;
  bool verifyResult = true;
  bool resendResult = true;
  bool throwVerify = false;
  Completer<bool>? pendingVerify;
  @override
  Future<bool> verifyOtp({required String email, required String token}) async {
    verifyCalls++;
    this.email = email;
    this.token = token;
    if (throwVerify) throw StateError('PRIVATE_OTP_OR_EMAIL_DIAGNOSTIC');
    if (pendingVerify != null) return pendingVerify!.future;
    return verifyResult;
  }
  @override
  Future<bool> resendOtp() async {
    resendCalls++;
    return resendResult;
  }
  @override
  Future<void> signOut() async { signOutCalls++; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeOtpAuth fake, {String language = 'en'}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: fake,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const VerifyEmailScreen(email: 'captain@example.com'),
      ),
    );

Future<void> _pasteOtp(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField).first, value);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('incomplete OTP cannot contact the provider', (tester) async {
    final auth = _FakeOtpAuth();
    await tester.pumpWidget(_host(auth));
    await _pasteOtp(tester, '123');
    expect(auth.verifyCalls, 0);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('six-digit paste submits once to the expected email', (tester) async {
    final auth = _FakeOtpAuth()..pendingVerify = Completer<bool>();
    await tester.pumpWidget(_host(auth));
    await _pasteOtp(tester, '123456');
    expect(auth.verifyCalls, 1);
    expect(auth.email, 'captain@example.com');
    expect(auth.token, '123456');
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
    auth.pendingVerify!.complete(true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final language in ['ar', 'en']) {
    testWidgets('wrong OTP has localized generic failure: $language', (tester) async {
      final auth = _FakeOtpAuth()..verifyResult = false;
      await tester.pumpWidget(_host(auth, language: language));
      await _pasteOtp(tester, '123456');
      await tester.pump(const Duration(milliseconds: 350));
      expect(auth.verifyCalls, 1);
      expect(find.textContaining(language == 'ar'
          ? 'رمز التفعيل خاطئ أو انتهت صلاحيته'
          : 'Invalid or expired code'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending OTP prevents duplicate submission', (tester) async {
    final auth = _FakeOtpAuth()..pendingVerify = Completer<bool>();
    await tester.pumpWidget(_host(auth));
    await _pasteOtp(tester, '123456');
    expect(auth.verifyCalls, 1);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
    auth.pendingVerify!.complete(false);
    await tester.pump(const Duration(milliseconds: 350));
    expect(auth.verifyCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('thrown provider diagnostic cannot leak into verification UI', (tester) async {
    final auth = _FakeOtpAuth()..throwVerify = true;
    await tester.pumpWidget(_host(auth));
    await _pasteOtp(tester, '123456');
    await tester.pump(const Duration(milliseconds: 350));
    expect(auth.verifyCalls, 1);
    expect(find.textContaining('PRIVATE_OTP_OR_EMAIL_DIAGNOSTIC'), findsNothing);
    expect(find.textContaining('Could not verify the code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend stays disabled until countdown ends', (tester) async {
    final auth = _FakeOtpAuth()..resendResult = false;
    await tester.pumpWidget(_host(auth));
    expect(find.textContaining('Resend in 60s'), findsOneWidget);
    expect(auth.resendCalls, 0);
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(find.text('Resend Code'), findsOneWidget);
    await tester.tap(find.text('Resend Code'));
    await tester.pump();
    expect(auth.resendCalls, 1);
    expect(find.textContaining('Failed to resend OTP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
