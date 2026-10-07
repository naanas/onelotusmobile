import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dev/component_gallery_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

// TODO(tahap-3): splash → login → tab bar per peran, redirect berdasarkan status login & peran.
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/dev/komponen',
  routes: [
    GoRoute(
      path: '/dev/komponen',
      builder: (context, state) => const ComponentGalleryPage(),
    ),
  ],
);
