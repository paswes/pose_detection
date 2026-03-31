import 'package:flutter/material.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/presentation/pages/home_page.dart';
import 'package:pose_detection/rdl_example/rdl_feature.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDependencies(
    featureRegistrars: [registerRdlDependencies],
    analyzerResolver: rdlAnalyzerResolver,
    demoServiceFactory: rdlDemoService,
  );
  runApp(const PoseEngineApp());
}

class PoseEngineApp extends StatelessWidget {
  const PoseEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Engine Core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF888888),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF888888),
          secondary: Color(0xFF666666),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}
