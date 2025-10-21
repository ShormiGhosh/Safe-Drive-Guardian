import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as realtime;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PoliceDashboardScreen extends StatefulWidget {
  const PoliceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<PoliceDashboardScreen> createState() => _PoliceDashboardScreenState();
}class _PoliceDashboardScreenState extends State<PoliceDashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  late RealtimeChannel _subscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _subscription = _supabase
        .channel('police_notifications')
        .onPostgresChanges(
      event: realtime.PostgresChangeEvent.insert,
      schema: 'public',
      table: 'police_notifications',
      callback: (payload) async {
        print('New police notification: ${payload.newRecord}');
        await _loadNotifications();
      },
    )
        .subscribe((status, error) {
      print('Channel status: $status');
      if (error != null) print('Channel error: $error');
    });
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await _supabase
          .from('police_notifications')
          .select('''
          *,
          profiles!police_notifications_user_id_fkey (
            username
          )
        ''')
          .order('timestamp', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _subscription.unsubscribe();
    super.dispose();
  }

  Future<void> _updateStatus(int notificationId, String status) async {
    try {
      await _supabase
          .from('police_notifications')
          .update({'status': status})
          .eq('id', notificationId);
      await _loadNotifications();
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Dashboard'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            final timestamp = DateTime.parse(notification['timestamp'])
                .toLocal();
            final status = notification['status'] ?? 'pending';

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: Icon(
                  Icons.warning,
                  color: status == 'pending' ? Colors.red : Colors.grey,
                  size: 40,
                ),
                title: Text(
                  'User: ${notification['profiles']['username']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alcohol Level: ${notification['alcohol_level']}'),
                    Text('Time: ${timestamp.toString().substring(0, 16)}'),
                    Text('Status: ${status.toUpperCase()}'),
                    if (notification['location'] != null) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: const Text('View User Location'),
                        onPressed: () => _openMap(notification['location']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) =>
                  [
                    const PopupMenuItem(
                      value: 'responded',
                      child: Text('Mark as Responded'),
                    ),
                    const PopupMenuItem(
                      value: 'cleared',
                      child: Text('Mark as Cleared'),
                    ),
                  ],
                  onSelected: (value) =>
                      _updateStatus(
                        notification['id'],
                        value.toString(),
                      ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openMap(String location) {
    final coordinates = location.split(',');
    if (coordinates.length == 2) {
      final url = 'https://www.google.com/maps/search/?api=1&query=${coordinates[0]},${coordinates[1]}';
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}