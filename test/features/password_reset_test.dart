import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/widgets/widgets.dart';
import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/features/auth/domain/usecases/password_reset_usecases.dart';
import 'package:college_level/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:college_level/features/auth/presentation/pages/reset_password_page.dart';

class _MockRequestReset extends Mock implements RequestPasswordResetUseCase {}

class _MockReset extends Mock implements ResetPasswordUseCase {}

/// The single sentence the server returns for every reset failure — an unknown
/// account, an expired code, a burned code and a plain mismatch alike.
const _serverRejection =
    'The verification code is invalid or has expired. Please request a new one.';

void main() {
  late _MockRequestReset requestReset;
  late _MockReset reset;

  setUpAll(() {
    registerFallbackValue(const RequestPasswordResetParams(email: 'a@b.co'));
    registerFallbackValue(
      const ResetPasswordParams(email: 'a@b.co', otp: '123456', password: 'x'),
    );
  });

  setUp(() {
    requestReset = _MockRequestReset();
    reset = _MockReset();

    when(() => requestReset(any()))
        .thenAnswer((_) async => const Right<Failure, Unit>(unit));
    when(() => reset(any()))
        .thenAnswer((_) async => const Right<Failure, Unit>(unit));
  });

  /// Both screens navigate with `context.go` on success, so they need a real
  /// router rather than a bare `home:` — which also lets the tests assert where
  /// the student actually lands.
  Widget host(String initialLocation) => MaterialApp.router(
        // The app theme carries the token extension `context.scheme` reads; a
        // bare MaterialApp has no such extension and every build throws.
        theme: AppTheme.light,
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(
              path: '/auth/login',
              builder: (_, _) => const Scaffold(body: Text('SIGN IN SCREEN')),
            ),
            GoRoute(
              path: '/auth/forgot-password',
              builder: (_, _) =>
                  ForgotPasswordPage(requestPasswordReset: requestReset),
            ),
            GoRoute(
              path: '/auth/reset-password',
              builder: (_, state) => ResetPasswordPage(
                resetPassword: reset,
                requestPasswordReset: requestReset,
                email: state.uri.queryParameters['email'],
              ),
            ),
          ],
        ),
      );

  Widget forgotPage() => host('/auth/forgot-password');

  Widget resetPage({String? email = 'ada@school.edu'}) => host(
        email == null
            ? '/auth/reset-password'
            : '/auth/reset-password?email=${Uri.encodeQueryComponent(email)}',
      );

  group('ForgotPasswordPage', () {
    testWidgets('sends the trimmed email', (tester) async {
      await tester.pumpWidget(forgotPage());

      await tester.enterText(find.byType(TextFormField), '  ada@school.edu  ');
      await tester.tap(find.text('Send code'));
      await tester.pump();

      final params = verify(() => requestReset(captureAny()))
          .captured
          .single as RequestPasswordResetParams;
      expect(params.email, 'ada@school.edu');
    });

    testWidgets('rejects a malformed address before the network',
        (tester) async {
      await tester.pumpWidget(forgotPage());

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send code'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      verifyNever(() => requestReset(any()));
    });

    /// The server answers identically for an address it has never seen, so the
    /// screen must not claim an email was actually delivered.
    testWidgets('hedges the success message', (tester) async {
      await tester.pumpWidget(forgotPage());

      await tester.enterText(find.byType(TextFormField), 'ada@school.edu');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text("If an account exists for that email, we've sent a code."),
        findsOneWidget,
      );
    });
  });

  group('ResetPasswordPage', () {
    testWidgets('sends email, otp and password together', (tester) async {
      await tester.pumpWidget(resetPage());

      await tester.enterText(find.widgetWithText(TextFormField, '6-digit code'),
          '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'At least 8 characters'),
          'sup3rsecret');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Re-enter your password'),
          'sup3rsecret');

      await tester.tap(find.widgetWithText(AppButton, 'Reset password'));
      await tester.pump();

      final params =
          verify(() => reset(captureAny())).captured.single as ResetPasswordParams;
      expect(params.email, 'ada@school.edu');
      expect(params.otp, '123456');
      expect(params.password, 'sup3rsecret');
    });

    testWidgets('a five-digit code never reaches the server', (tester) async {
      await tester.pumpWidget(resetPage());

      await tester.enterText(
          find.widgetWithText(TextFormField, '6-digit code'), '12345');
      await tester.tap(find.widgetWithText(AppButton, 'Reset password'));
      await tester.pump();

      expect(find.text('The code is 6 digits'), findsOneWidget);
      verifyNever(() => reset(any()));
    });

    testWidgets('the code field refuses non-digits', (tester) async {
      await tester.pumpWidget(resetPage());

      final field = find.widgetWithText(TextFormField, '6-digit code');
      await tester.enterText(field, '12ab34cd56');
      await tester.pump();

      // Filtered to digits and capped at six, on both platform branches.
      expect(find.text('123456'), findsOneWidget);
    });

    testWidgets('mismatched passwords are caught locally', (tester) async {
      await tester.pumpWidget(resetPage());

      await tester.enterText(
          find.widgetWithText(TextFormField, '6-digit code'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'At least 8 characters'),
          'sup3rsecret');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Re-enter your password'),
          'sup3rsecretx');

      await tester.tap(find.widgetWithText(AppButton, 'Reset password'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(() => reset(any()));
    });

    testWidgets('a short password is caught locally', (tester) async {
      await tester.pumpWidget(resetPage());

      await tester.enterText(
          find.widgetWithText(TextFormField, '6-digit code'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'At least 8 characters'), 'short7');
      await tester.tap(find.widgetWithText(AppButton, 'Reset password'));
      await tester.pump();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      verifyNever(() => reset(any()));
    });

    /// Every server-side failure is one 400 with one sentence, so the screen
    /// has nothing to branch on — it must render what the server said.
    testWidgets('shows the server rejection inline', (tester) async {
      when(() => reset(any())).thenAnswer(
        (_) async => const Left<Failure, Unit>(
          ServerFailure(_serverRejection, statusCode: 400),
        ),
      );

      await tester.pumpWidget(resetPage());

      await tester.enterText(
          find.widgetWithText(TextFormField, '6-digit code'), '000000');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'At least 8 characters'),
          'sup3rsecret');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Re-enter your password'),
          'sup3rsecret');
      await tester.tap(find.widgetWithText(AppButton, 'Reset password'));
      await tester.pump();
      await tester.pump();

      // Inline as well as toasted, so it survives the toast dismissing itself.
      expect(find.text(_serverRejection), findsWidgets);
    });

    testWidgets('the resend countdown starts on arrival and then frees up',
        (tester) async {
      await tester.pumpWidget(resetPage());

      expect(find.text('Resend in 60s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend in 30s'), findsOneWidget);
      // Still blocked, so no second code can be requested yet.
      verifyNever(() => requestReset(any()));

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend code'), findsOneWidget);
    });

    /// The server burns the outstanding code whenever it issues a new one, so
    /// whatever is typed is dead the moment a resend succeeds.
    testWidgets('resending clears the stale code', (tester) async {
      await tester.pumpWidget(resetPage());
      await tester.pump(const Duration(seconds: 60));

      await tester.enterText(
          find.widgetWithText(TextFormField, '6-digit code'), '111111');
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump();

      expect(find.text('111111'), findsNothing);
      expect(find.text('A new code is on its way.'), findsOneWidget);
      verify(() => requestReset(any())).called(1);

      // Drain the toast's own dismissal timer.
      await tester.pumpAndSettle();
    });

    /// Landing here cold — a deep link, or a restart — leaves nothing to resend
    /// to, so the address becomes a field instead of a caption.
    testWidgets('asks for the email when the route carries none',
        (tester) async {
      await tester.pumpWidget(resetPage(email: null));

      expect(find.text('Email'), findsOneWidget);
      expect(find.textContaining('If an account exists for'), findsNothing);
      // Nothing was just sent, so the resend is live immediately.
      expect(find.text('Resend code'), findsOneWidget);
    });
  });

  group('params', () {
    test('carry value equality so mocktail can match them', () {
      expect(
        const RequestPasswordResetParams(email: 'a@b.co'),
        const RequestPasswordResetParams(email: 'a@b.co'),
      );
      expect(
        const ResetPasswordParams(email: 'a@b.co', otp: '1', password: 'p'),
        const ResetPasswordParams(email: 'a@b.co', otp: '1', password: 'p'),
      );
    });
  });
}
