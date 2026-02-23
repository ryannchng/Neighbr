import 'package:flutter/material.dart';
import 'package:neighbr/app.dart';
import 'package:neighbr/core/constants.dart';
import 'package:neighbr/core/secure_session_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureSessionStorage(),
    ),
    debug: true,
  );

  runApp(const MainApp());
}