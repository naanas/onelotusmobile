import 'package:flutter/material.dart';
import 'package:onelotus_staff/theme/app_theme.dart';
import 'package:onelotus_staff/ui/feedback/app_feedback.dart';

/// Membungkus widget dengan tema & AppFeedback seperti di aplikasi.
class TestApp extends StatelessWidget {
  TestApp({super.key, required this.child, this.scroll = true});

  final Widget child;
  final bool scroll;
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final navigatorKey = GlobalKey<NavigatorState>();
  late final feedback = AppFeedback(
    messengerKey: messengerKey,
    navigatorKey: navigatorKey,
  );

  @override
  Widget build(BuildContext context) => FeedbackScope(
    feedback: feedback,
    child: MaterialApp(
      theme: buildOlTheme(),
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      home: scroll
          ? Scaffold(body: SingleChildScrollView(child: child))
          : child,
    ),
  );
}
