import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class LocationTrackingWidget extends StatefulWidget {
  const LocationTrackingWidget({super.key});

  @override
  State<LocationTrackingWidget> createState() => _LocationTrackingWidgetState();
}

class _LocationTrackingWidgetState extends State<LocationTrackingWidget> {
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isTracking = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() => _currentPosition = position);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Please check settings.'),
            ),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Single location update button
        ElevatedButton(
          onPressed: _isLoading ? null : _getCurrentLocation,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Get Current Location'),
        ),
        const SizedBox(height: 16),

        // Display single location update
        if (_currentPosition != null) ...[
          Text(
            'Current Location:\n'
                'Latitude: ${_currentPosition!.latitude}\n'
                'Longitude: ${_currentPosition!.longitude}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],

        // Toggle continuous tracking
        ElevatedButton(
          onPressed: () {
            setState(() => _isTracking = !_isTracking);
          },
          child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
        ),
        const SizedBox(height: 16),

        // Continuous location updates
        if (_isTracking)
          StreamBuilder<Position>(
            stream: _locationService.getLocationStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }

              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Live Location Updates:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latitude: ${snapshot.data!.latitude}\n'
                          'Longitude: ${snapshot.data!.longitude}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  void dispose() {
    _isTracking = false;
    super.dispose();
  }
}