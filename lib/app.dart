import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'ui/feedback/app_feedback.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class OneLotusApp extends StatefulWidget {
  const OneLotusApp({super.key});

  @override
  State<OneLotusApp> createState() => _OneLotusAppState();
}

class _OneLotusAppState extends State<OneLotusApp> {
  final _feedback = AppFeedback(
    messengerKey: rootMessengerKey,
    navigatorKey: rootNavigatorKey,
  );

  @override
  Widget build(BuildContext context) {
    return FeedbackScope(
      feedback: _feedback,
      child: MaterialApp.router(
        title: 'One Lotus',
        debugShowCheckedModeBanner: false,
        theme: buildOlTheme(),
        scaffoldMessengerKey: rootMessengerKey,
        routerConfig: appRouter,
      ),
    );
  }
}
