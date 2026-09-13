import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/payments/data/datasources/payments_remote_datasource.dart';
import 'features/payments/data/repositories/payments_repository_impl.dart';
import 'features/payments/presentation/controllers/month_controller.dart';
import 'features/payments/presentation/pages/home_page.dart';
import 'features/sky/domain/entities/cloud_rule.dart';
import 'features/sky/presentation/controllers/sky_controller.dart';

// Deliberately no DI package. Swap in get_it, riverpod, or whatever the DTR
// side settles on — nothing below the presentation layer knows or cares.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with SingleTickerProviderStateMixin {
  late final SkyController _sky = SkyController(
    vsync: this,
    rule: const CloudRule(centavosPerCloud: 100000, maxClouds: 12),
  );
  late final MonthController _months = MonthController(
    repository: PaymentsRepositoryImpl(
      PaymentsRemoteDataSource(ApiClient(baseUrl: kApiBaseUrl)),
    ),
    sky: _sky,
  );

  @override
  void initState() {
    super.initState();
    _months.load();
  }

  @override
  void dispose() {
    _sky.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clouds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: HomePage(controller: _months, sky: _sky),
      // The layout is a phone screen: a sky-over-list split with clouds sized
      // off the sky's width. In a desktop browser the clouds grow taller than
      // the sky and the list rows run the full window width. Capping the width
      // keeps web looking like the phone app. The builder wraps the Navigator,
      // so the drawer and bottom sheet stay inside the column as well.
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFDCE6F0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    );
  }
}
