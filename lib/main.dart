import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart'; // Adjust path if needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connects to your Step Saga Firebase console
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const StepSagaApp());
}

class StepSagaApp extends StatelessWidget {
  const StepSagaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step Saga',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LoginScreen(),
    );
  }
}
