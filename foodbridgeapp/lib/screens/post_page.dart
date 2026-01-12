import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:foodbridgeapp/verified_service.dart';
import 'package:foodbridgeapp/screens/vertify_id_page.dart';
import 'package:foodbridgeapp/screens/other_profile_page.dart';


// Enum to track user verification and reservation status
enum UserStatus {
  notVerified,
  verifiedNoReservation,
  verifiedWithReservation,
}

class PostPage extends StatefulWidget {
  // final int postId = 20; // example post id
  // const PostPage({super.key});

  final int postId;
  const PostPage({super.key, required this.postId});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  GoogleMapController? _mapController;
  // Simulate user status - change this to test different popups
  String userId = "USER001"; // from backend or auth system
  String? reservationId;
  UserStatus userStatus = UserStatus.verifiedNoReservation;

  // location data
  double latitude = 13.7563;  // initiarl value
  double longitude = 100.5018; // initial value
  double? _distanceKm;

  final String imagePath = 'assets/images/savory_img.png';
  String? status;

  int remainingCount = 0;
  int receiverCount = 0;
  int totalQuantity = 0 ; // backend total quantity
  
  bool isGiveaway = false;
  int? price;
  int? providerId;
  String? providerName;
  String? providerPhone;
  String? imageUrl;
  String? menuName;
  String? address;
  String? openTime;
  String openDateFormatted = '-';
  String openTimeFormatted = '-';
  String closeTimeFormatted = '-';
  String? contactPhone;
  double? postLat;
  double? postLng;
  String? district;
  String? province;
  String? description;

  Duration? _timeRemaining;
  Timer? _countdownTimer;
  int? userQuotaLeft;

  int? currentBookingId;
  String? currentQrToken;
  int? postCloseTimeUnix;

  Future<void> _fetchPostData() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    try {
      final response = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/posts/${widget.postId}'),
        headers: {"Content-Type": "application/json",
        "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('${widget.postId}');
        setState(() {
          status = data['status'] ?? 'เปิดจอง';
          isGiveaway = data['is_giveaway'] ?? false;
          price = data['price'];
          totalQuantity = data['quantity'] ?? 0;
          menuName = data['title'] ?? '-';
          address = data['address'] ?? '-';
          providerId = data['provider_id'];
          if (data['images'] != null && data['images'].isNotEmpty) {
            imageUrl = data['images'][0];
          } else {
            imageUrl = null;
  }
          description = data['description'] ?? '-';
          openTime = _formatTimeRange(data['open_time'], data['close_time']);
          openDateFormatted = _formatDate(data['open_time']);
          postCloseTimeUnix = data['close_time'];
          contactPhone = data['phone'] ?? '-';
          // imageUrl = (data['images'] != null && data['images'].isNotEmpty)
          //     ? data['images'][0]
          //     : null;
          postLat = data['lat'];
          postLng = data['lng'];
          district = data['district'] ?? 'ไม่ทราบ';
          province = data['province'] ?? 'ไม่ทราบ';
        });

        await _fetchReceiverCount();
        await _checkExistingBooking();
        await _fetchProviderData(providerId!);
        final closeTime = DateTime.fromMillisecondsSinceEpoch(postCloseTimeUnix! * 1000);
        _startCountdown(closeTime);

        // Move map to post location
        if (postLat != null && postLng != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(postLat!, postLng!),
            ),
          );
        }

        // calculate distance using coordinates
        if (postLat != null && postLng != null) {
          await _calculateDistance(
            LatLng(postLat!, postLng!),
            district ?? '-',
            province ?? '-',
          );
        }
      } else {
        print('Failed to load post: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching post: $e');
    }
  }
  Future<void> _fetchProviderData(int id) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    try {
      final response = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/users/$id'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        setState(() {
          providerName = userData['full_name'] ?? 'ไม่ทราบชื่อผู้ให้';
          providerPhone = userData['phone'] ?? '-';
        });
      } else {
        print('Failed to load provider data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching provider data: $e');
    }
  }

  Future<void> _fetchReceiverCount() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    try {
      final response = await http.get(
        //get only bookings with specific statuses
        Uri.parse('https://foodbridge1.onrender.com/bookings?post_id=${widget.postId}&status=PENDING,QUEUED,COMPLETED'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['receiver_count'] ?? 0;
        print('totalQuantity: $totalQuantity');
        setState(() { 
          receiverCount = count;
          remainingCount = (totalQuantity - receiverCount).clamp(0, totalQuantity);
     
        });

        print('Updated receiver count: $count');
        print('remaining Food: $remainingCount');
      } else {
        print('Failed to fetch receiver count: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching receiver count: $e');
    }
  }

  Future<void> _fetchQrToken(int bookingId, int? closeTimeUnix) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    if (token == null) return;
    try {
      int ttlSeconds = 600; // default 10 minutes

      if (closeTimeUnix != null) {
        final closeTime = DateTime.fromMillisecondsSinceEpoch(closeTimeUnix * 1000);
        _startCountdown(closeTime);
        final now = DateTime.now();
        final diff = closeTime.difference(now).inSeconds;
        if (diff > 0) {
          ttlSeconds = diff;
        }
      }

      final response = await http.post(
        Uri.parse('https://foodbridge1.onrender.com/bookings/$bookingId/qr'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"ttl_seconds": ttlSeconds}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'];
        setState(() {
          currentQrToken = newToken;
        });
        print("QR Token refreshed: $newToken");
      } else {
        print("Failed to refresh QR token: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching QR token: $e");
    }
  }


  Future<void> _fetchUserVerificationStatus() async {
    final user = await VerifiedService.getCurrentUser();
    if (user == null) return;

    setState(() {
      userId = user['user_id'].toString();
      userStatus = user['is_verified'] == true
          ? UserStatus.verifiedNoReservation
          : UserStatus.notVerified;
    });
  }

  Future<void> _checkExistingBooking() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    if (token == null) return;

    try {
      // ✅ filter by post_id and current logged-in user
      final response = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/bookings?post_id=${widget.postId}&receiver_user_id=$userId'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>;

        // ✅ find the most recent active booking (not cancelled/expired)
        final activeBooking = items.firstWhere(
          (item) => item['status'] == 'PENDING' || item['status'] == 'QUEUED',
          orElse: () => {},
        );

        if (activeBooking.isNotEmpty) {
          final bookingId = activeBooking['booking_id'];
          final qrToken = activeBooking['qr_token'];
          final expireAt = activeBooking['expire_at'];

          setState(() {
            currentBookingId = bookingId;
            userStatus = UserStatus.verifiedWithReservation;
            currentQrToken = qrToken;
          });

          // ✅ Restore countdown if expire_at is known
          if (expireAt != null) {
            final closeTime = DateTime.tryParse(expireAt);
            if (closeTime != null) _startCountdown(closeTime);
          }

          print("✅ Restored booking ID: $bookingId");
          print("✅ Restored QR token: $qrToken");
        } else {
          // no active booking found
          setState(() {
            userStatus = UserStatus.verifiedNoReservation;
            currentBookingId = null;
            currentQrToken = null;
          });
          print("ℹ No active booking found for user $userId");
        }
      } else {
        print("Failed to check booking: ${response.statusCode}");
      }
    } catch (e) {
      print("Error checking existing booking: $e");
    }
  }
  
  String _formatTimeRange(int? open,  int? close) {
    if (open == null || close == null) return '-';

    // Convert from UNIX seconds to DateTime (local time)
    final openTime =
        DateTime.fromMillisecondsSinceEpoch(open * 1000, isUtc: true).toLocal();
    final closeTime =
        DateTime.fromMillisecondsSinceEpoch(close * 1000, isUtc: true).toLocal();

    // Format as HH:mm
    final openStr =
        '${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}';
    final closeStr =
        '${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}';

    return '$openStr - $closeStr';
  }

  String _formatDate(int? unixTime) {
    if (unixTime == null) return '-';

    final date =
        DateTime.fromMillisecondsSinceEpoch(unixTime * 1000, isUtc: true).toLocal();

    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return "$hours ชั่วโมง ${minutes.toString().padLeft(2, '0')} นาที";
    } else if (minutes > 0) {
      return "$minutes นาที ${seconds.toString().padLeft(2, '0')} วินาที";
    } else {
      return "$seconds วินาที";
    }
  }

  Future<void> _calculateDistance(LatLng destination, String districtName, String provinceName) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      if (mounted) {
        setState(() {
          _distanceKm = null;
          district = districtName;
          province = provinceName;
        });
      }
      return;
    }
    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _distanceKm = null;
            district = districtName;
            province = provinceName;
          });
        }
        return;
      }
    }
    // get current position
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high,);

    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (mounted) {
      setState(() {
        _distanceKm = distanceInMeters / 1000; // convert to km
        district = districtName;
        province = provinceName;

        print('Destination: ${destination.latitude}, ${destination.longitude}');
        print('Current Position: ${position.latitude}, ${position.longitude}');
        print('Distance: ${_distanceKm!.toStringAsFixed(2)} km');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchPostData();
    _fetchUserVerificationStatus();
    _fetchReceiverCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // To allow bottom button to float over content
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Header with food image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: (imageUrl != null && imageUrl!.isNotEmpty)
                          ? Image.network(
                              imageUrl!, // from backend
                              width: double.infinity,
                              height: 280,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/savory_img.png', // fallback local image
                                  width: double.infinity,
                                  height: 280,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/savory_img.png', // fallback when no URL
                              width: double.infinity,
                              height: 280,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Top navigation
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(
                                    Icons.arrow_back_ios,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const Icon(
                              Icons.share,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Content section
                Container(
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      // Promotional banner
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isGiveaway
                                            ? 'ฟรี'
                                            : (price != null && price! > 0
                                                ? '฿$price'
                                                : '-'), // fallback if no price
                                        style: TextStyle(
                                          color: Colors.red ,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'จำนวน',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFFF58319),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:  remainingCount > 0 ? Color(0xFF038263): Colors.red[600],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          remainingCount > 0 ? '$remainingCount' : 'เต็มแล้ว', // backend
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'ที่',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFFF58319),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              menuName ?? '', // backend
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              address ?? '', // backend
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                          alignment: Alignment.centerRight,
                                          height: 40, 
                                          child: Text(
                                            status ?? '', // backend text
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: status == 'OPEN'
                                              ? Colors.green
                                              : Colors.red,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Restaurant info cards
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF038263).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.access_time,
                                      color: Color(0xFF038263),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'วันที่ $openDateFormatted',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'เวลา $openTime',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.red[600],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _distanceKm != null
                                          ? 'ระยะทาง ${_distanceKm!.toStringAsFixed(1)} กม' // backend
                                          : 'กำลังคำนวณระยะทาง...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        district != null && province != null 
                                        ? '$district, $province' 
                                        : 'กำลังดึงข้อมูลที่ตั้ง...',// backend
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (providerId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OtherProfilePage(userId: providerId!),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.blue[600],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          providerName ?? 'ไม่ทราบชื่อผู้ให้',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          providerPhone ?? '-',
                                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),  
                          ],
                        ),
                      ),
                      
                      // Map section
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[300],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  postLat ?? latitude,     // from backend
                                  postLng ?? longitude,     // from backend
                                ),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('location'),
                                  position: LatLng(
                                    postLat ?? latitude,     // from backend
                                    postLng ?? longitude,     // from backend
                                  ),
                                ),
                              },
                              onMapCreated: (controller) {
                                _mapController = controller;
                              },
                              myLocationButtonEnabled: false, // static preview
                              zoomControlsEnabled: false, // static preview
                              scrollGesturesEnabled: false, // static preview
                              rotateGesturesEnabled: false, // static preview
                              tiltGesturesEnabled: false, // static preview
                            ),
                          ),
                      ),

                      const SizedBox(height: 20),
                      // extra Details section

                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(), // remove default divider
                          tilePadding: EdgeInsets.zero,
                          title: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'รายละเอียด',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey[600],
                          ),
                          childrenPadding: const EdgeInsets.only(top: 12),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                description ?? '',
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                const SizedBox(height: 360), // extra space for bottom overlay
              ], 
            ),
          ),
        // Floating QR section (only when reserved)
        if (userStatus == UserStatus.verifiedWithReservation)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'แสดง QR CODE เพื่อยืนยันการจอง',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      QrImageView(
                        data: currentQrToken ?? '',
                        version: QrVersions.auto,
                        size: 150,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      if (_timeRemaining != null)
                        Text(
                          _timeRemaining!.inSeconds > 0
                            ? "QR หมดอายุใน ${_formatDuration(_timeRemaining!)}"
                            : "QR หมดอายุแล้ว",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'รหัสจอง: $currentQrToken',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _handleReservationAction(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'ยกเลิกการจอง',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),          
        ], 
      ),

      // Regular reservation button (when not reserved)
      bottomNavigationBar: userStatus != UserStatus.verifiedWithReservation
          ? Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _handleReservationAction(context), // reservation action
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF038263),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'จองสิทธิ์',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  //  method to validate booking conditions
  Future<bool> _validateBookingConditions() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนทำการจอง')),
      );
      return false;
    }

    try {
      // Get current user info
      final meResponse = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/me'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (meResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถดึงข้อมูลผู้ใช้ได้')),
        );
        return false;
      }

      final userData = jsonDecode(meResponse.body);
      final userId = userData['user_id'];

      // Get post details
      final postResponse = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/posts/${widget.postId}'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (postResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถดึงข้อมูลโพสต์ได้')),
        );
        return false;
      }

      final postData = jsonDecode(postResponse.body);
      final providerId = postData['provider_id'];
      final totalQuantity = postData['quantity'] ?? 0;
      final bookedCount = postData['booked_count'] ?? 0;
      final openTimeUnix = postData['open_time'];
      final closeTimeUnix = postData['close_time'];

      // Convert UNIX timestamps to DateTime
      final now = DateTime.now().toUtc();
      final openTime = DateTime.fromMillisecondsSinceEpoch(openTimeUnix * 1000, isUtc: true);
      final closeTime = DateTime.fromMillisecondsSinceEpoch(closeTimeUnix * 1000, isUtc: true);

      // Check ownership
      if (providerId == userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถจองโพสต์ของตัวเองได้'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      // Check available slots
      if (bookedCount >= totalQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สิทธิ์การจองเต็มแล้ว'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      
      // Check open/close window
      final nowLocal = DateTime.now();
      final openLocal = openTime.toLocal();
      final closeLocal = closeTime.toLocal();
      final sameDay = nowLocal.year == openLocal.year &&
                    nowLocal.month == openLocal.month &&
                    nowLocal.day == openLocal.day;

      if (sameDay) {
      // On the same day → check within time window
        if (nowLocal.isBefore(openLocal) || nowLocal.isAfter(closeLocal)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'สามารถจองได้เฉพาะช่วงเวลา ${openLocal.hour}:${openLocal.minute.toString().padLeft(2, '0')} - ${closeLocal.hour}:${closeLocal.minute.toString().padLeft(2, '0')}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }
      } else if (nowLocal.isAfter(closeLocal)) {
        // The event has passed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('โพสต์นี้หมดเวลาการจองแล้ว'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      // else if (future day → allow booking freely)

      // All checks passed
      return true;
    } catch (e) {
      print("Error validating booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดระหว่างตรวจสอบ')),
      );
      return false;
    }
  }

  // method to start countdown timer for QR expiration
  void _startCountdown(DateTime closeTime) {
    _countdownTimer?.cancel();

    void updateTimer() {
      final now = DateTime.now().toUtc();
      final diff = closeTime.difference(now);
      if (diff.isNegative) {
        _countdownTimer?.cancel();
        setState(() => _timeRemaining = Duration.zero);
      } else {
        setState(() => _timeRemaining = diff);
      }
    }

    updateTimer();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => updateTimer());
  }

  // method to generate unique reservation ID
  Future<void> _generateQrToken(int bookingId, int? closeTimeUnix) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    // Compute TTL
    int ttlSeconds = 600; // default 10 minutes
    if (closeTimeUnix != null) {
      final closeTime = DateTime.fromMillisecondsSinceEpoch(closeTimeUnix * 1000);
      final now = DateTime.now().toUtc();
      final diff = closeTime.difference(now).inSeconds;
      if (diff > 0) ttlSeconds = diff;
      _startCountdown(closeTime);
    }

    try {
      final response = await http.post(
        Uri.parse('https://foodbridge1.onrender.com/bookings/$bookingId/qr'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "ttl_seconds": ttlSeconds,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          reservationId = data['token'] ?? 'unknown_token';
          currentQrToken = reservationId;
        });
        print("QR Token received: $reservationId");
      } else {
        print("Failed to generate QR: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error generating QR: $e");
    }
  }

  // method to handle reservation actions based on user status
  void _handleReservationAction(BuildContext context) {
    switch (userStatus) {
      case UserStatus.notVerified:
        _showVerificationRequiredDialog(context);
        break;
      case UserStatus.verifiedNoReservation:
        _showConfirmReservationDialog(context);
        break;
      case UserStatus.verifiedWithReservation:
        _showCancelReservationDialog(context);
        break;
    }
  }
  
  // method to check daily quota before allowing reservation
  Future<bool> _checkDailyQuota() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    try {
      final response = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/bookings/daily-limit'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final left = data['left_today'] ?? 0;

        if (mounted) {
          setState(() {
            userQuotaLeft = left;
          });
        }
        print("User quota left today: $left");
        if (left > 0) return true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('คุณใช้สิทธิ์ครบแล้วสำหรับวันนี้'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      } else {
        print("Failed to fetch quota: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error checking quota: $e");
      return false;
    }
  }

  // dialog for users who need to verify identity
  void _showVerificationRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'กรุณายืนยันตัวตน',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00897B),
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'คุณยังไม่ได้ยืนยันตัวตน\n',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(
                        text: 'กรุณายืนยันตัวตนก่อนรับสิทธิ์',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Navigate to VerifyIDPage
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VerifyIDPage()),
                      );
                      setState(() {
                        userStatus = UserStatus.verifiedNoReservation;
                      });
                      // mock up update verification status if verified
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ยืนยันตัวตนสำเร็จ!'),
                            backgroundColor: Color(0xFF038263),
                        ),
                      );
                      
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'ยืนยันตัวตน',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // method to create booking
  Future<void> _createBooking() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    try {
      final response = await http.post(
        Uri.parse('https://foodbridge1.onrender.com/posts/${widget.postId}/bookings'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final bookingId = data['booking_id'];
        
        print("Booking created with ID: $bookingId");

        // Generate QR token for this booking
        await _generateQrToken(bookingId, postCloseTimeUnix);
        await _fetchReceiverCount();
        setState(() {
          currentBookingId = bookingId;
          userStatus = UserStatus.verifiedWithReservation;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('จองสิทธิ์สำเร็จ!'),
            backgroundColor: Color(0xFF038263),
          ),
        );
      } else {
        print("Booking failed: ${response.statusCode}");
        print("Response: ${response.body}");
      }
    } catch (e) {
      print("Error creating booking: $e");
    }
  }

  // dialog for confirming reservation
  void _showConfirmReservationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ยืนยันสิทธิ?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00897B),
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'คุณต้องการรับสิทธิ์จองคิว\n',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: menuName,
                      ),
                      TextSpan(
                        text: ' ใช่หรือไม่',
                        style: TextStyle(
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.grey,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'ยกเลิก',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16, 
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final isValid = await _validateBookingConditions(); // Validate conditions
                          if (!isValid) return;
                          final hasQuota = await _checkDailyQuota(); // Check daily quota
                          if (!hasQuota) return;
                          await _createBooking(); // Generate reservation ID
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('จองสิทธิ์สำเร็จ!'),
                              backgroundColor: Color(0xFF038263),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'จองสิทธิ์',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  } 

  // method to cancel reservation
  Future<void> _cancelReservation(int bookingId) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    try {
      final response = await http.patch(
        Uri.parse('https://foodbridge1.onrender.com/bookings/$bookingId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"status": "CANCELLED"}),
      );

      if (response.statusCode == 204) {
        print("Booking cancelled successfully.");
        await _fetchReceiverCount();
        if (mounted) {
          await _checkDailyQuota();
          setState(() {
            userStatus = UserStatus.verifiedNoReservation;
            reservationId = null;
            currentBookingId = null;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยกเลิกสิทธิ์แล้ว'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print("Failed to cancel booking: ${response.statusCode}");
        print("Response: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error cancelling booking: $e");
    }
  }
  // dialog for canceling reservation
  void _showCancelReservationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ยกเลิกสิทธิ?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'คุณต้องการยกเลิกสิทธิ์จองคิว\n',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: menuName,
                      ),
                      TextSpan(
                        text: ' ใช่หรือไม่',
                        style: TextStyle(
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.grey,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'จองต่อ',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _cancelReservation(currentBookingId!); // Pass booking ID
                          // setState(() {
                          //   userStatus = UserStatus.verifiedNoReservation;
                          // });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ยกเลิกสิทธิ์แล้ว'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'ยกเลิกสิทธิ์',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  } 


} // End of PostPage class