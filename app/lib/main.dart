import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/payments/data/datasources/payments_local_datasource.dart';
import 'features/payments/data/repositories/local_payments_repository.dart';
import 'features/payments/presentation/controllers/month_controller.dart';
import 'features/payments/presentation/pages/home_page.dart';
import 'features/sky/domain/entities/cloud_rule.dart';
import 'features/sky/presentation/controllers/sky_controller.dart';

// Deliberately no DI package. Swap in get_it, riverpod, or whatever the DTR
// side settles on — nothing below the presentation layer knows or cares.
//
// Months live on the device, so the app needs no backend to run. To point it
// at the API again, build the repository from PaymentsRepositoryImpl(
// PaymentsRemoteDataSource(ApiClient(baseUrl: ...))) instead.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(App(prefs: prefs));
}

class App extends StatefulWidget {
  const App({required this.prefs, super.key});

  final SharedPreferences prefs;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with SingleTickerProviderStateMixin {
  late final SkyController _sky = SkyController(
    vsync: this,
    rule: const CloudRule(centavosPerCloud: 100000, maxClouds: 12),
  );
  late final MonthController _months = MonthController(
    repository: LocalPaymentsRepository(PaymentsLocalDataSource(widget.prefs)),
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
