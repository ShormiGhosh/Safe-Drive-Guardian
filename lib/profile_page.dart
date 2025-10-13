import 'package:alchoholdetect/services/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'main.dart';

AppBar buildAppBar(BuildContext context) {
  return AppBar(
    title: const Text('My Profile'),
    backgroundColor: Colors.blue[900],
    foregroundColor: Colors.white,
    actions: [
      IconButton(
        icon: const Icon(Icons.home),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        },
        tooltip: 'Go to Home',
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () async {
          await SessionManager.clearSession();
          await Supabase.instance.client.auth.signOut();
        },
        tooltip: 'Sign Out',
      ),
    ],
  );
}
class ProfilePage extends StatefulWidget {
 const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  Map<DateTime, int> _heatmapData = {};
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Load user profile
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      // Load alcohol detection history
      final alcoholData = await _supabase
          .from('drunk_monitor')
          .select('timestamp, alcohol_level')
          .eq('user_id', user.id)
          .gte('timestamp', DateTime.now().subtract(const Duration(days: 365)));

      // Process data for heatmap
      Map<DateTime, int> heatmapData = {};
      for (var record in alcoholData) {
        final date = DateTime.parse(record['timestamp']).toLocal();
        final dateOnly = DateTime(date.year, date.month, date.day);
        heatmapData[dateOnly] = (heatmapData[dateOnly] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _userProfile = profileData;
          _heatmapData = heatmapData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Info Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue[900]!, Colors.blue[700]!],
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userProfile?['username'] ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userProfile?['email'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatCard('Total Detections',
                          _heatmapData.values.fold(0, (a, b) => a + b).toString()),
                      const SizedBox(width: 16),
                      _buildStatCard('Last Detection',
                          _getLastDetectionDate()),
                    ],
                  ),
                ],
              ),
            ),

            // Activity Heatmap Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alcohol Detection History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  HeatMap(
                    datasets: _heatmapData,
                    startDate: DateTime.now().subtract(const Duration(days: 365)),
                    endDate: DateTime.now(),
                    colorMode: ColorMode.opacity,
                    defaultColor: Colors.grey[200]!,
                    textColor: Colors.black,
                    showColorTip: false,
                    showText: true,
                    scrollable: true,
                    size: 32,
                    colorsets: {
                      1: Colors.red[300]!,
                      2: Colors.red[400]!,
                      3: Colors.red[500]!,
                      4: Colors.red[600]!,
                      5: Colors.red[700]!,
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  String _getLastDetectionDate() {
    if (_heatmapData.isEmpty) return 'None';
    final lastDate = _heatmapData.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    return DateFormat('MMM d').format(lastDate);
  }
}