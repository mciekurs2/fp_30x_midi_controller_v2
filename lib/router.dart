import 'package:go_router/go_router.dart';

import 'ui/features/game/views/home_page.dart';

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
  ],
);
