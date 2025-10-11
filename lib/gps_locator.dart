import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:alchoholdetect/services/location_service.dart';


class LocationTrackingWidget extends StatefulWidget {
  const LocationTrackingWidget({super.key});

  @override
  State<LocationTrackingWidget> createState() => _LocationTrackingWidgetState();
}

class _LocationTrackingWidgetState extends State<LocationTrackingWidget> {
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() => _currentPosition = position);
      } else {
        // Handle location service disabled or permissions denied
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
        ElevatedButton(
          onPressed: _isLoading ? null : _getCurrentLocation,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Get Current Location'),
        ),
        if (_currentPosition != null) ...[
          const SizedBox(height: 16),
          Text(
            'Latitude: ${_currentPosition!.latitude}\n'
                'Longitude: ${_currentPosition!.longitude}',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}