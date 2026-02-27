/// Supabase client initialization
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://eqbdqsiudzofitepmcxj.supabase.co';
const supabaseAnonKey = 'sb_publishable_U-NcYbPZ8Ol6_hL1ROsc3A_qHaNgKOP';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
