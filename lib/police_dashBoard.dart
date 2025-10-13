import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PoliceDashboardScreen extends StatefulWidget {
  const PoliceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<PoliceDashboardScreen> createState() => _PoliceDashboardScreenState();
}

class _PoliceDashboardScreenState extends State<PoliceDashboardScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> alerts = [];
  DateTime? _lastCheckedTime;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadAlerts();
    _startPolling();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);
    _lastCheckedTime = DateTime.now();
  }

  Future<void> _loadAlerts() async {
    final response = await supabase
        .from('drunk_monitor')
        .select('*, profiles!drunk_monitor_user_id_fkey(*)')
        .order('timestamp', ascending: false);

    if (mounted) {
      setState(() {
        alerts = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  void _startPolling() {
    // Check for new alerts every 30 seconds
    Future.delayed(const Duration(seconds: 30), () async {
      if (mounted) {
        await _checkNewAlerts();
        _startPolling();
      }
    });
  }

  Future<void> _checkNewAlerts() async {
    try {
      final response = await supabase
          .from('drunk_monitor')
          .select('*, profiles!drunk_monitor_user_id_fkey(*)')
          .eq('alert', true)
          .gt('timestamp', _lastCheckedTime!.toIso8601String())
          .order('timestamp');

      if (response != null) {
        final newAlerts = List<Map<String, dynamic>>.from(response);

        for (final alert in newAlerts) {
          await _showNotification(
            title: 'Alcohol Alert!',
            body: 'Alert from user: ${alert['profiles']['username']}\n'
                'Alcohol Level: ${alert['alcohol_level']}',
          );
        }

        if (newAlerts.isNotEmpty) {
          _lastCheckedTime = DateTime.now();
          _loadAlerts(); // Refresh the list
        }
      }
    } catch (e) {
      print('Error checking alerts: $e');
    }
  }

  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'alcohol_alerts',
      'Alcohol Alerts',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Dashboard'),
        backgroundColor: Colors.blue[900],
      ),
      body: ListView.builder(
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          final mapLink = 'https://www.google.com/maps/search/?api=1&query=${alert['latitude']},${alert['longitude']}';

          return Card(
            margin: const EdgeInsets.all(8),
            color: alert['alert'] == true ? Colors.red[50] : Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.warning,
                color: Colors.red,
                size: 40,
              ),
              title: Text(
                'User: ${alert['profiles']['username']} - Level: ${alert['alcohol_level']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Time: ${alert['timestamp']}'),
                  const SizedBox(height: 4),
                  if (alert['latitude'] != null)
                    InkWell(
                      onTap: () => _openMap(mapLink),
                      child: const Text(
                        '📍 View Location',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openMap(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}