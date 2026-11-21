import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/http_log.dart';
import 'data/auth.dart';
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
    _feedback.onAuthExpired = () => ref.read(authProvider.notifier).expire();
    // Data pasien disamarkan di app switcher.
    _lifecycle = AppLifecycleListener(
      onInactive: () => setState(() => _obscured = true),
      onResume: () => setState(() => _obscured = false),
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
        locale: const Locale('id'),
        supportedLocales: const [Locale('id'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        scaffoldMessengerKey: rootMessengerKey,
        routerConfig: ref.watch(routerProvider),
        builder: (context, child) => Stack(
          children: [
            child!,
            if (_obscured && ref.read(authProvider).loggedIn)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFF0C4A6E),
                  child: Center(child: OlLogoMark()),
                ),
              ),
            if (HttpLog.enabled) HttpLogButton(navigatorKey: rootNavigatorKey),
          ],
        ),
      ),
    );
  }
}
