import 'package:alchoholdetect/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alchoholdetect/supabase_config.dart';
import 'package:alchoholdetect/auth_page.dart';
import 'package:alchoholdetect/gps_locator.dart';
import 'package:alchoholdetect/police_dashBoard.dart';

String _generateUniqueUsername(String name) {
  final cleanName = name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${cleanName}_$timestamp';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Auth state listener for automatic profile creation
  // In main.dart, update the auth state listener:
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;
    final user = session?.user;

    if (event == AuthChangeEvent.signedIn && user != null) {
      print('User signed in: ${user.id}');

      try {
        // Wait a bit for the session to be fully established
        await Future.delayed(const Duration(seconds: 1));

        // Check if profile exists
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profile == null) {
          print('Creating profile for new user: ${user.id}');

          // Get username from user_metadata (set during signup)
          final username = user.userMetadata?['username'] ?? 'User';

// Create profile using real username
          await Supabase.instance.client.from('profiles').insert({
            'id': user.id,
            'username': username,
            'email': user.email ?? '',
            'created_at': DateTime.now().toIso8601String(),
          });

          print('Profile created successfully for user: ${user.id}');
        }
      } catch (error) {
        print('Error in auth state listener: $error');
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Drive Guardian',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final AuthState state = snapshot.data!;
          if (state.event == AuthChangeEvent.signedIn) {
            final user = Supabase.instance.client.auth.currentUser;
            if (user?.email == "dummyemail@police.gov.bd") {
              return PoliceDashboardScreen();
            } else {
              return const ProfilePage();
            }
          }
        }
        return const AuthPage(); // This will show login first
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle(); // safer than .single()

        if (response != null && response is Map<String, dynamic>) {
          setState(() {
            _userProfile = response;
            _isLoadingProfile = false;
          });
        } else {
          print('Profile not found for user: ${user.id}');
          setState(() {
            _isLoadingProfile = false;
          });
        }
      }
    } catch (error) {
      print('Error loading profile: $error');
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }




  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      print('Error signing out: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Drive Guardian'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_userProfile != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_userProfile!['username'] ?? 'User'}!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  Text(
                    'Email: ${_userProfile!['email'] ?? 'N/A'}',
                    style: TextStyle(
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: const Center(
              child: LocationTrackingWidget(),
            ),
          ),
        ],
      ),
    );
  }
}