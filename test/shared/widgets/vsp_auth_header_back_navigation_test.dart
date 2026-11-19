import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vsp_application/shared/widgets/vsp_auth_header.dart';
import 'package:vsp_application/shared/widgets/vsp_back_button.dart';

Widget app({required String initialLocation}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('Welcome route'),
              TextButton(
                onPressed: () => context.push('/login'),
                child: const Text('Open login'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(
          body: Column(
            children: [
              VSPAuthHeader(showLogo: false),
              Text('Login route'),
            ],
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('header back button returns to the pushed previous route',
      (tester) async {
    await tester.pumpWidget(app(initialLocation: '/welcome'));
    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    expect(find.text('Login route'), findsOneWidget);
    await tester.tap(find.byType(VSPBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Welcome route'), findsOneWidget);
    expect(find.text('Login route'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android system back returns to the pushed previous route',
      (tester) async {
    await tester.pumpWidget(app(initialLocation: '/welcome'));
    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Welcome route'), findsOneWidget);
    expect(find.text('Login route'), findsNothing);
  });

  testWidgets('a directly opened login route has a safe back fallback',
      (tester) async {
    await tester.pumpWidget(app(initialLocation: '/login'));
    expect(find.text('Login route'), findsOneWidget);
    await tester.tap(find.byType(VSPBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Welcome route'), findsOneWidget);
    expect(find.text('Login route'), findsNothing);
  });

  testWidgets('back is a minimum 48dp touch target with an English label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VSPBackButton()),
    ));
    final size = tester.getSize(find.byType(VSPBackButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('RTL back control exposes an Arabic screen-reader label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: VSPBackButton()),
      ),
    ));
    expect(find.bySemanticsLabel('رجوع'), findsOneWidget);
    handle.dispose();
  });
}
