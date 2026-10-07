import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/auth/auth_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'ui/feedback/app_feedback.dart';
import 'ui/ol_logo.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class OneLotusApp extends ConsumerStatefulWidget {
  const OneLotusApp({super.key});

  @override
  ConsumerState<OneLotusApp> createState() => _OneLotusAppState();
}

class _OneLotusAppState extends ConsumerState<OneLotusApp> {
  final _feedback = AppFeedback(
    messengerKey: rootMessengerKey,
    navigatorKey: rootNavigatorKey,
  );
  late final AppLifecycleListener _lifecycle;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _feedback.onAuthExpired = () =>
        ref.read(authProvider.notifier).expireSession();
    _lifecycle = AppLifecycleListener(
      // UM-07: konten disamarkan di app switcher.
      onInactive: () => setState(() => _obscured = true),
      onResume: () {
        setState(() => _obscured = false);
        ref.read(authProvider.notifier).onForeground();
      },
      onHide: () => ref.read(authProvider.notifier).onBackground(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeedbackScope(
      feedback: _feedback,
      child: MaterialApp.router(
        title: 'One Lotus',
        debugShowCheckedModeBanner: false,
        theme: buildOlTheme(),
        scaffoldMessengerKey: rootMessengerKey,
        routerConfig: ref.watch(routerProvider),
        builder: (context, child) => Stack(
          children: [
            child!,
            if (_obscured && ref.read(authProvider).user != null)
              // TODO(workshop-4): FLAG_SECURE untuk layar medis bila diputuskan (§10).
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFF0C4A6E),
                  child: Center(child: OlLogoMark()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
