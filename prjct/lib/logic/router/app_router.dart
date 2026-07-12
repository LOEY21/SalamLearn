import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/auth/auth_choice_screen.dart';
import '../../ui/auth/consent_screen.dart';
import '../../ui/auth/email_verification_gate_screen.dart';
import '../../ui/auth/learner_setup_screen.dart';
import '../../ui/auth/pin_setup_screen.dart';
import '../../ui/auth/pin_verify_screen.dart';
import '../../ui/auth/role_flow_shell.dart';
import '../../ui/auth/role_picker_screen.dart';
import '../../ui/core_modules/custom_lesson_detail_screen.dart';
import '../../ui/debug/database_inspector_screen.dart';
import '../../ui/onboarding/get_started_screen.dart';
import '../../ui/onboarding/onboarding_screen.dart';
import '../../ui/onboarding/onboarding_shell.dart';
import '../../ui/onboarding/splash_screen.dart';
import '../../ui/parent_dashboard/edit_child_profile_screen.dart';
import '../../ui/parent_dashboard/parent_dashboard_screen.dart';
import '../../ui/settings/settings_screen.dart';
import '../../ui/student_hub/adventure_map_screen.dart';
import '../../ui/student_hub/backpack_screen.dart';
import '../../ui/student_hub/hub_shell.dart';
import '../../ui/student_hub/profile_screen.dart';
import '../../ui/teacher_dashboard/cast_screen.dart';
import '../../ui/teacher_dashboard/class_detail_screen.dart';
import '../../ui/teacher_dashboard/classroom_management_screen.dart';
import '../../ui/teacher_dashboard/teacher_dashboard_screen.dart';
import '../../ui/widgets/auth_loading_overlay.dart' show rootNavigatorKey;
import '../auth/session.dart';

/// Role-gated router.
///
/// Guard rules:
/// - Onboarding (language) and consent must complete before role selection.
/// - Learner is locked to the hub and modules — never settings or
///   parent/teacher areas (FR-3.1 role lock).
/// - Parent/Asatidz areas, casting, and settings require a verified PIN
///   (FR-2.1).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  const adminPaths = [
    '/parent',
    '/teacher',
    '/settings',
    '/cast',
    '/debug/database',
  ];
  const gatePaths = [
    '/',
    '/get-started',
    '/language',
    '/consent',
    '/roles',
    '/auth',
  ];

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;
      // Full path + query (e.g. `?from=hub`) so the PIN gate can restore it
      // exactly — matchedLocation alone drops query parameters.
      final fullPath = state.uri.toString();

      final needsAdmin = adminPaths.any(path.startsWith);
      final inGateFlow = gatePaths.contains(path) || path.startsWith('/pin');

      // Force onboarding order: language → consent → roles.
      if (!session.onboarded && !gatePaths.contains(path)) return '/';
      if (session.onboarded && !session.consented && !inGateFlow) {
        return '/consent';
      }

      // Learner can never reach admin areas.
      if (session.activeRole == UserRole.learner && needsAdmin) {
        return '/hub';
      }

      // Admin areas demand a verified PIN. The originally-requested path is
      // carried through as ?redirect= so the PIN screens can send the user
      // on to (e.g.) /settings instead of always landing on the dashboard.
      if (needsAdmin && !session.pinVerified) {
        final gate = session.hasPin ? '/pin/verify' : '/pin/setup';
        return '$gate?redirect=${Uri.encodeComponent(fullPath)}';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            OnboardingShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/get-started',
            pageBuilder: (context, state) =>
                _fadePage(state, const GetStartedScreen()),
          ),
          GoRoute(
            path: '/language',
            pageBuilder: (context, state) =>
                _fadePage(state, const OnboardingScreen()),
          ),
          GoRoute(
            path: '/consent',
            pageBuilder: (context, state) =>
                _fadePage(state, const ConsentScreen()),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) =>
            RoleFlowShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/roles',
            pageBuilder: (context, state) =>
                _fadePage(state, const RolePickerScreen()),
          ),
          GoRoute(
            path: '/auth',
            pageBuilder: (context, state) =>
                _fadePage(state, const AuthChoiceScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/learner-setup',
        builder: (_, _) => const LearnerSetupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => EmailVerificationGateScreen(
          redirectTarget: state.uri.queryParameters['redirect'] ?? '/parent',
        ),
      ),
      GoRoute(path: '/pin/setup', builder: (_, _) => const PinSetupScreen()),
      GoRoute(path: '/pin/verify', builder: (_, _) => const PinVerifyScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HubShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub',
                builder: (_, _) => const AdventureMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/backpack',
                builder: (_, _) => const BackpackScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/custom-lesson/:id',
        builder: (_, state) =>
            CustomLessonDetailScreen(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/parent',
        builder: (_, _) => const ParentDashboardScreen(),
      ),
      GoRoute(
        path: '/parent/edit-child',
        builder: (_, _) => const EditChildProfileScreen(),
      ),
      GoRoute(
        path: '/teacher',
        builder: (_, _) => const TeacherDashboardScreen(),
      ),
      GoRoute(
        path: '/teacher/classes',
        builder: (_, _) => const ClassroomManagementScreen(),
      ),
      GoRoute(
        path: '/teacher/classes/:classId',
        builder: (_, state) =>
            ClassDetailScreen(classId: state.pathParameters['classId']!),
      ),
      GoRoute(path: '/cast', builder: (_, _) => const CastScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/debug/database',
        builder: (_, _) => const DatabaseInspectorScreen(),
      ),
    ],
  );
});

/// Crossfade page transition (no slide) — the platform default (a
/// full-screen slide) fought with the onboarding shell's persistent
/// step-dots and ambient blobs, which don't move, making the page swap
/// look mismatched. The outgoing page also fades via [secondaryAnimation]
/// so the hop reads as one continuous overlap instead of a hard cut
/// (most noticeable on language → consent, where the tone shifts).
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final enter = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final exit = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(exit),
        child: FadeTransition(
          opacity: enter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(enter),
            child: child,
          ),
        ),
      );
    },
  );
}
