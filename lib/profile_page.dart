import 'package:alchoholdetect/services/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'auth_page.dart';
import 'main.dart';


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

  Future<void> _signOut() async {
    try {
      await SessionManager.clearSession();
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthPage()),
              (route) => false,
        );
      }
    } catch (error) {
      print('Error signing out: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('My Profile'),
      backgroundColor: Colors.blue[900],
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _signOut,
          tooltip: 'Sign Out',
        ),
      ],
    );
  }

  Future<void> _updateDeviceId(String deviceId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('profiles').update({
        'device_id': deviceId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // Refresh user data
      await _loadUserData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device ID updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating device ID: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<void> _showDeviceIdDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _userProfile?['device_id'] ?? '',
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Device ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device ID',
            hintText: 'Enter device ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final deviceId = controller.text.trim();
              if (deviceId.isNotEmpty) {
                _updateDeviceId(deviceId);
              }
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
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

      if (profileData == null || profileData['device_id'] == null) {
        print('No device ID found for user: ${user.id}');
        setState(() => _isLoading = false);
        return;
      }

      final deviceId = profileData['device_id'];
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365)).toIso8601String();

      // Load all alcohol detection history ordered by timestamp
      final alcoholData = await _supabase
          .from('alcohol_status')
          .select('timestamp, alert')
          .eq('device_id', deviceId)
          .gte('timestamp', oneYearAgo)
          .order('timestamp');

      // Process data for heatmap with consecutive alert handling
      Map<DateTime, int> heatmapData = {};
      bool previousWasAlert = false;

      for (var record in alcoholData) {
        final date = DateTime.parse(record['timestamp']).toLocal();
        final dateOnly = DateTime(date.year, date.month, date.day);
        final bool isAlert = record['alert'] ?? false;

        if (isAlert && !previousWasAlert) {
          // Only count the first alert in a sequence
          heatmapData[dateOnly] = (heatmapData[dateOnly] ?? 0) + 1;
        }

        previousWasAlert = isAlert;
      }

      if (context.mounted) {
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
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Device ID: ${_userProfile?['device_id'] ?? 'Not set'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white70),
                          onPressed: _showDeviceIdDialog,
                          tooltip: 'Update Device ID',
                        ),
                      ],
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