import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class AlertMonitorService {
  final _supabase = Supabase.instance.client;
  DateTime? _lastAlertTime;

  Future<void> startMonitoring() async {
    _supabase
        .from('drunk_monitor')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(1)
        .listen((List<Map<String, dynamic>> data) async {
      if (data.isNotEmpty) {
        final alert = data.first;

        // Check if this is a new alert and if alert is true
        if (alert['alert'] == true &&
            (_lastAlertTime == null ||
                DateTime.parse(alert['timestamp']).isAfter(_lastAlertTime!))) {

          _lastAlertTime = DateTime.parse(alert['timestamp']);

          // Fetch user details
          final userProfile = await _supabase
              .from('profiles')
              .select()
              .eq('id', alert['user_id'])
              .single();

          // Fetch device details
          final device = await _supabase
              .from('devices')
              .select()
              .eq('device_id', alert['device_id'])
              .single();

          await NotificationService.showNotification(
            title: 'Alcohol Alert!',
            body: 'User ${userProfile['username']} has triggered an alert.\n'
                'Alcohol Level: ${alert['alcohol_level']}\n'
                'Device: ${device['device_name']}',
          );
        }
      }
    });
  }
}