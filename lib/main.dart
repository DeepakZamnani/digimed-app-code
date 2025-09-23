import 'package:digimedindia/firebase_options.dart';
import 'package:digimedindia/screens/auth/auth.dart';
import 'package:digimedindia/screens/home.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  var delegate = await LocalizationDelegate.create(
    fallbackLocale: 'en',
    supportedLocales: ['en', 'hi', 'es'],
  );
  runApp(LocalizedApp(delegate, DigiMedIndia()));
}

class DigiMedIndia extends StatefulWidget {
  const DigiMedIndia({super.key});

  @override
  State<DigiMedIndia> createState() => _DigiMedIndiaState();
}

class _DigiMedIndiaState extends State<DigiMedIndia> {
  @override
  Widget build(BuildContext context) {
    var localizationDelegate = LocalizedApp.of(context).delegate;
    return MaterialApp(
      localizationsDelegates: [localizationDelegate],
      supportedLocales: localizationDelegate.supportedLocales,
      locale: localizationDelegate.currentLocale,
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return Home();
          }
          return LoginScreen();
        },
      ),
    );
  }
}
