import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';

class MapPlaceholderScreen extends StatefulWidget {
  const MapPlaceholderScreen({super.key});

  @override
  State<MapPlaceholderScreen> createState() => _MapPlaceholderScreenState();
}

class _MapPlaceholderScreenState extends State<MapPlaceholderScreen> {
  Position? _currentPosition;
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    final position = await LocationService().getCurrentPosition();
    
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Map'),
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 80, color: AppColors.primaryBrown),
            const SizedBox(height: 16),
            const Text(
              'Interactive Map',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore heritage sites near you.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_currentPosition != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Your Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Get My Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}







