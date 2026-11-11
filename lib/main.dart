import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'features/auth/data/auth_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await createSessionRepository();
  runApp(AmenMoaApp(sessionRepository: repository));
}
