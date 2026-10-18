import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home/home_screen.dart';

const supabaseUrl = 'https://eiwkxjfqhlmnbjyemopi.supabase.co';
const supabaseKey = 'sb_publishable_pVszEL5juBFsL7r-NYZWjQ_XdXgDkRd';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const ProviderScope(child: DebtBookApp()));
}

class DebtBookApp extends StatelessWidget {
  const DebtBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دفتر الديون',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorSchemeSeed: Colors.teal,
      ),
      home: const HomeScreen(),
    );
  }
}