import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapPickerResult {
  final LatLng latLng;
  final Placemark placemark;
  MapPickerResult(this.latLng, this.placemark);
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key, this.initial});
  final LatLng? initial;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? _controller;
  LatLng _picked = const LatLng(13.7563, 100.5018); // default: Bangkok
  Marker _marker = const Marker(
    markerId: MarkerId('picked'),
    position: LatLng(13.7563, 100.5018),
  );
  bool _confirming = false;

  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;


  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _picked = widget.initial!;
      _marker = Marker(markerId: const MarkerId('picked'), position: _picked);
    }
  }
  
  Future<void> _searchPlace() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    const apiKey = 'AIzaSyC4dBWyUoZKWYYMSdRgtaXIxRE_rMu8GSM'; // Replace with your Google Places API key

    try {
      // Get current user location
      final position = await Geolocator.getCurrentPosition();

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent(query)}'
        '&location=${position.latitude},${position.longitude}'
        '&radius=3000'
        '&language=th'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final place = data['results'][0];
          final lat = place['geometry']['location']['lat'];
          final lng = place['geometry']['location']['lng'];
          final name = place['name'];

          setState(() {
            _picked = LatLng(lat, lng);
            _marker = Marker(
              markerId: const MarkerId('picked'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: name),
            );
          });

          await _controller?.animateCamera(CameraUpdate.newLatLngZoom(_picked!, 15));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบสถานที่ที่ค้นหา')),
          );
        }
      } else {
        print('Google API error: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ข้อผิดพลาดจาก Google API: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error searching place: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการค้นหา: $e')),
      );
    }
  }


  

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        _picked.latitude,
        _picked.longitude,
        localeIdentifier: 'th_TH', // Thai labels where possible
      );
      final place = placemarks.isNotEmpty ? placemarks.first : Placemark();
      if (!mounted) return;
      Navigator.pop(context, MapPickerResult(_picked, place));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถระบุที่อยู่ได้: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกตำแหน่งบนแผนที่')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _picked, zoom: 15),
            onMapCreated: (c) => _controller = c,
            onTap: (pos) {
              setState(() {
                _picked = pos;
                _marker = Marker(markerId: const MarkerId('picked'), position: pos);
              });
            },
            markers: {_marker},
            myLocationButtonEnabled: true,
            myLocationEnabled: false,
          ),
          // Search box at top
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'ค้นหาสถานที่...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _searchPlace(),
                      ),
                    ),
                    IconButton(
                      icon: _searching
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      onPressed: _searching ? null : _searchPlace,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirming ? null : _confirm,
        label: _confirming
            ? const Text('กำลังยืนยัน...')
            : const Text('ยืนยันตำแหน่ง'),
        icon: const Icon(Icons.check),
        backgroundColor: Color(0xFF038263),
        foregroundColor: Colors.white,
      ),
    );
  }
}