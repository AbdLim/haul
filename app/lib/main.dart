import 'package:flutter/widgets.dart';

import 'app/dependencies.dart';
import 'app/haul_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await AppDependencies.start();
  runApp(HaulApp(deps: deps));
}
