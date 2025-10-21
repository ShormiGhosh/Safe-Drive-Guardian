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
  List<Map<String, dynamic>> alerts = [];
  late RealtimeChannel _subscription;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _subscription = supabase
        .channel('police_alerts')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'police_notifications',
      callback: (payload) async {
        print('New police notification: ${payload.toString()}');
        await _loadAlerts();
        if (mounted) setState(() {});
      },
    )
        .subscribe((status, [error]) {
      print('Subscription status: $status');
      if (error != null) print('Subscription error: $error');
    });
  }

  Future<void> _loadAlerts() async {
    try {
      final response = await supabase
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
          alerts = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading alerts: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Dashboard'),
        backgroundColor: Colors.blue[900],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            // Safely handle location data
            String? mapLink;
            if (alert['location'] != null && alert['location'].toString().contains(',')) {
              final location = alert['location'].toString().split(',');
              if (location.length == 2) {
                mapLink = 'https://www.google.com/maps/search/?api=1&query=${location[0]},${location[1]}';
              }
            }

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
                    if (mapLink != null)
                      InkWell(
                        onTap: () => _openMap(mapLink!),
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
    supabase.removeChannel(_subscription);
    super.dispose();
  }
}