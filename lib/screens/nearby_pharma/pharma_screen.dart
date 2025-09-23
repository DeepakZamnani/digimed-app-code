import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_translate/flutter_translate.dart';

String api_key = 'AIzaSyC7hzH8DbEQetBh4y3u7Hdc6bI_y2dij1c';

class NearbyPharmacies extends StatefulWidget {
  const NearbyPharmacies({super.key});

  @override
  State<NearbyPharmacies> createState() => _NearbyPharmaciesState();
}

class _NearbyPharmaciesState extends State<NearbyPharmacies> {
  List pharmacies = [];
  bool isLoading = false;
  String? errorMessage;
  String currentLocation = '';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndFetch();
  }

  Future<void> _checkPermissionsAndFetch() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          errorMessage = 'Location services are disabled';
          isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            errorMessage = 'Location permissions denied';
            isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          errorMessage = 'Location permissions permanently denied';
          isLoading = false;
        });
        return;
      }

      await _fetchPharmacies();
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchPharmacies() async {
    try {
      Position current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update current location display
      setState(() {
        currentLocation =
            '${current.latitude.toStringAsFixed(4)}, ${current.longitude.toStringAsFixed(4)}';
      });

      // Use a CORS proxy for web
      final baseUrl =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
      final params =
          '?location=${current.latitude},${current.longitude}&radius=1500&type=pharmacy&key=$api_key';

      // For web, use a CORS proxy
      final url =
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(baseUrl + params)}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            pharmacies = data['results'] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'API Error: ${data['status']}';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Network Error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'CORS Error: Use mobile app or proxy server';
        isLoading = false;
      });
      print('Detailed error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('pharma.nearby_pharmacies'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          currentLocation.isEmpty
                              ? 'Getting location...'
                              : currentLocation,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (!isLoading)
                        GestureDetector(
                          onTap: _checkPermissionsAndFetch,
                          child: Icon(
                            Icons.refresh,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              child:
                  isLoading
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black87,
                            ),
                            SizedBox(height: 16),
                            Text(
                              translate('pharma.finding_pharmacies'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                      : errorMessage != null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextButton(
                              onPressed: _checkPermissionsAndFetch,
                              child: Text(
                                translate('pharma.try_again'),
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      : pharmacies.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_pharmacy_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              translate('pharma.no_pharmacies'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount:
                            pharmacies.length > 6 ? 6 : pharmacies.length,
                        separatorBuilder:
                            (context, index) => SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final place = pharmacies[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.local_pharmacy,
                                  color: Colors.green[600],
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                place['name'] ?? 'Unknown Pharmacy',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text(
                                    place['vicinity'] ?? 'No address',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (place['rating'] != null) ...[
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 14,
                                          color: Colors.amber[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          translate('pharma.rating').replaceAll(
                                            '\${place[\'rating\']}',
                                            '${place['rating']}',
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                              onTap: () {
                                // Add navigation or details functionality here
                              },
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
