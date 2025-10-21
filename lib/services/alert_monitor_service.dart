import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';
import 'location_service.dart';

class AlertMonitorService {
  final SupabaseClient _supabase;
  final LocationService _locationService;

  AlertMonitorService()
      : _supabase = Supabase.instance.client,
        _locationService = LocationService();

  Future<void> startMonitoring() async {
    print('Starting alert monitoring...');

    _supabase
        .channel('alcohol_status_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'alcohol_status',
      callback: (payload) async {
        print('Received new alcohol status: ${payload.toString()}');
        if (payload.newRecord != null && payload.newRecord!['alert'] == true) {
          await _handleAlert(Map<String, dynamic>.from(payload.newRecord!));
        }
      },
    )
        .subscribe();
  }

  Future<void> _handleAlert(Map<String, dynamic> alert) async {
    try {
      final List<dynamic> profiles = await _supabase
          .from('profiles')
          .select()
          .eq('device_id', alert['device_id']);

      if (profiles.isEmpty) {
        print('No profile found for device_id: ${alert['device_id']}');
        return;
      }

      final Map<String, dynamic> userProfile = profiles.first;
      // Get current location
      final Position? location = await _locationService.getCurrentLocation();

      // Create a location string for the database
      final String? locationString = location != null
          ? '${location.latitude},${location.longitude}'
          : null;

      // Insert into police_notifications with location
      await _supabase.from('police_notifications').insert({
        'user_id': userProfile['id'],
        'username': userProfile['username'],
        'alcohol_level': alert['alcohol_level'],
        'timestamp': DateTime.now().toIso8601String(),
        'location': locationString, // Make sure this is being set
      });

      // Show notification
      final String notificationBody = '''User: ${userProfile['username']}
Alcohol Level: ${alert['alcohol_level']}
Location: ${locationString ?? 'Unavailable'}''';

      await NotificationService.showNotification(
        title: 'High Alcohol Level Alert',
        body: notificationBody,
      );

      print('Police notification created with location: $locationString');
    } catch (e) {
      print('Error handling alert: $e');
    }
  }

  Future<void> recordDetection({
    required String deviceId,
    required int alcoholLevel,
    required bool alert,
  }) async {
    try {
      final userProfile = await _supabase
          .from('profiles')
          .select()
          .eq('device_id', deviceId)
          .single();

      await _supabase.from('alcohol_status').insert({
        'device_id': deviceId,
        'user_id': userProfile['id'],
        'alcohol_level': alcoholLevel,
        'alert': alert,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (alert) {
        final Position? location = await _locationService.getCurrentLocation();

        // Create police notification
        await _supabase.from('police_notifications').insert({
          'user_id': userProfile['id'],
          'username': userProfile['username'],
          'alcohol_level': alcoholLevel,
          'timestamp': DateTime.now().toIso8601String(),
          'location': location != null
              ? '${location.latitude},${location.longitude}'
              : null,
        });

        final String locationInfo = location != null
            ? '\nLocation: https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}'
            : '\nLocation: Unavailable';

        await NotificationService.showNotification(
          title: 'High Alcohol Level Detected',
          body: '''User: ${userProfile['username']}
Alcohol Level: $alcoholLevel$locationInfo''',
        );
      }
    } catch (e) {
      print('Error recording detection: $e');
    }
  }
}