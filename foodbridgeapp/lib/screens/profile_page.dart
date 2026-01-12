import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:foodbridgeapp/verified_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'edit_profile_page.dart';
import 'post_page.dart';
import 'nav_bar.dart';
import 'other_profile_page.dart';
import 'setting_page.dart';
import 'history_order_page.dart';
import 'view_more_page.dart';

String formatThaiDate(String isoDate) {
  final dt = DateTime.parse(isoDate).toLocal();
  final thaiMonths = [
    '', // month index starts at 1
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];
  int day = dt.day;
  String month = thaiMonths[dt.month];
  int year = dt.year + 543; // Thai year
  return '$day $month $year';
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic>? userData;
  Map<String, dynamic>? dailyLimitData;
  Map<String, dynamic>? successData;
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, String>> allPosts = [];
  bool loadingPosts = true;
  String? currentProvince;
  LatLng? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    await _loadUserProvinceAndPosition(); // cache user position first
    await _loadUser(); // then load user data
    await fetchAllPosts(); // now safe to calculate distances
    await _loadDailyLimit();
    await _loadSuccess();
    await _loadBookings();
  }

  Future<void> _loadUser() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('https://foodbridge1.onrender.com/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        userData = jsonDecode(response.body);
      });
    } else {
      print('Failed to load user: ${response.statusCode}');
    }
  }

  Future<void> _loadDailyLimit() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('https://foodbridge1.onrender.com/bookings/daily-limit'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        dailyLimitData = jsonDecode(response.body);
      });
    } else {
      print('Failed to load daily limit: ${response.statusCode}');
    }
  }

  Future<void> _loadSuccess() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('https://foodbridge1.onrender.com/me/stats/success'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        successData = jsonDecode(response.body);
      });
    } else {
      print('Failed to load Success: ${response.statusCode}');
    }
  }

  Future<void> _loadBookings() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    List<String> statuses = ['PENDING', 'QUEUED'];
    List<Map<String, dynamic>> loadedBookings = [];

    // Fetch both status histories in parallel
    List<Future> futures = statuses.map((status) async {
      final resp = await http.get(
        Uri.parse(
          'https://foodbridge1.onrender.com/me/bookings/history?status=$status',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        List<dynamic> data = jsonDecode(resp.body);

        // Fetch post details concurrently for each booking
        await Future.wait(
          data.map((booking) async {
            final postResp = await http.get(
              Uri.parse(
                'https://foodbridge1.onrender.com/posts/${booking['post_id']}',
              ),
              headers: {'Authorization': 'Bearer $token'},
            );

            if (postResp.statusCode == 200) {
              var postData = jsonDecode(postResp.body);
              print("postData: $postData");
              var ownerId = postData['provider_id'];

              // Fetch owner profile data
              String? avatarUrl;
              final ownerResp = await http.get(
                Uri.parse('https://foodbridge1.onrender.com/users/$ownerId'),
                headers: {'Authorization': 'Bearer $token'},
              );
              if (ownerResp.statusCode == 200) {
                var ownerData = jsonDecode(ownerResp.body);
                print("ownerData : $ownerData");
                avatarUrl = ownerData['avatar_url'];
                print("avatarUrl : $avatarUrl");
                if (avatarUrl == null) {
                  avatarUrl =
                      "https://www.shutterstock.com/image-vector/avatar-gender-neutral-silhouette-vector-600nw-2470054311.jpg";
                }
              }

              loadedBookings.add({
                'title': postData['title'],
                'status': booking['status'] == 'PENDING'
                    ? 'กำลังต่อคิว'
                    : 'ได้คิวแล้ว',
                'open_time': postData['open_time'],
                'close_time': postData['close_time'],
                'expire_at': booking['expire_at'],
                'owner_image': avatarUrl,
              });
            }
          }),
        );
      }
    }).toList();

    await Future.wait(futures);

    setState(() {
      bookings = loadedBookings;
    });
  }

  Future<void> _loadUserProvinceAndPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled.');
      return null;
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied.');
        return null;
      }
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        setState(() {
          currentProvince = placemarks.first.administrativeArea ?? "No Where";
          _currentUserPosition = LatLng(position.latitude, position.longitude);
        });
      } else {
        setState(() {
          currentProvince = "No Where";
          _currentUserPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
      setState(() {
        currentProvince = "No Where";
        _currentUserPosition = LatLng(13.7563, 100.5018);
      });
    }
  }

  Future<double?> calculateDistance(double postLat, double postLng) async {
    if (_currentUserPosition == null) return null;
    // Calculate distance
    final distanceInMeters = Geolocator.distanceBetween(
      _currentUserPosition!.latitude,
      _currentUserPosition!.longitude,
      postLat,
      postLng,
    );

    final distanceKm = distanceInMeters / 1000; // convert to km

    debugPrint('📍 Post: $postLat, $postLng');
    debugPrint(
      '📍 Current: ${_currentUserPosition!.latitude}, ${_currentUserPosition!.longitude}',
    );
    debugPrint('📏 Distance: ${distanceKm.toStringAsFixed(2)} km');

    return distanceKm;
  }

  Future<void> fetchAllPosts() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://foodbridge1.onrender.com/users/${userData?['user_id']}/posts',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        debugPrint("Failed to fetch posts: ${response.statusCode}");
        setState(() => loadingPosts = false);
        return;
      }

      final data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];

      final futures = items.map<Future<Map<String, String>>>((item) async {
        final images = item['images'] ?? [];
        final imageUrl = (images.isNotEmpty && images.first is String)
            ? images.first as String
            : 'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445';

        final createdAt = item['created_at'];
        DateTime createdAtDate;
        if (createdAt is int) {
          createdAtDate = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
        } else if (createdAt is String) {
          createdAtDate = DateTime.tryParse(createdAt) ?? DateTime(0);
        } else {
          createdAtDate = DateTime(0);
        }

        double? lat = item['lat'];
        double? lng = item['lng'];

        String kiloText;
        double? distance;

        if (lat == null || lng == null) {
          kiloText = '- km';
        } else {
          final postLat = lat.toDouble();
          final postLng = lng.toDouble();

          distance = await calculateDistance(postLat, postLng);
          if (distance == null) {
            kiloText = '- km';
          } else {
            final clampedDistance = distance > 999 ? 999 : distance;
            kiloText = distance > 999
                ? '999+ km'
                : "${clampedDistance.toStringAsFixed(2)} km";
          }
        }
        print("kilitext: $kiloText");
        print("distancekm: $distance");

        return {
          'id': item['post_id'].toString(),
          'image': imageUrl,
          'title': item['title'] ?? 'ไม่ระบุชื่อโพสต์',
          'location':
              (item['address'] == null || item['address'].toString().isEmpty)
              ? 'ไม่ระบุสถานที่'
              : item['address'],
          'kilo': kiloText,
          'owner': userData?['full_name'] ?? "Unknown",
          'created_at': createdAtDate.toIso8601String(),
        };
      }).toList();

      // Wait all
      final mergedPosts = await Future.wait(futures);

      // 🕒 sort newest first
      mergedPosts.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      setState(() {
        allPosts = mergedPosts;
        loadingPosts = false;
      });
    } catch (e) {
      debugPrint("Error fetching posts: $e");
      setState(() => loadingPosts = false);
    }
  }

  void _showSharePopup() {
    if (userData == null) return;

    final int userId = userData!['user_id'];
    showDialog(
      context: context,
      builder: (_) => ShareProfilePopup(userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final successBoxWidth = (screenWidth - 56) / 3;

    if (userData == null || dailyLimitData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final fullName = userData!['full_name'] ?? 'Username';
    // final province = userData!['province'] ?? 'Bangkok, Thailand';
    final province = currentProvince ?? 'Loading...';
    print("province: $province");

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 244, 243, 243),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (userData?['avatar_url'] != null
                          ? NetworkImage(userData!['avatar_url'])
                          : null),
                      child: userData?['avatar_url'] == null
                          ? SvgPicture.asset(
                              'assets/images/profile1.png',
                              width: 180,
                              height: 180,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              fullName ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (userData?['is_vertify'] == true)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.verified,
                                  color: Color(0xFFF58319),
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              province,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color.fromARGB(255, 3, 130, 99),
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      iconSize: 30,
                      onPressed: _showSharePopup,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      iconSize: 30,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            // const SizedBox(height: 18),
            // Row(
            //   children: [
            //     const Icon(Icons.location_on, color: Colors.red, size: 28),
            //     const SizedBox(width: 4),
            //     Text(
            //       province,
            //       style: const TextStyle(
            //         fontSize: 20,
            //         color: Color.fromARGB(255, 3, 130, 99),
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 16),
            // 💡 Daily Limit Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(50, 245, 131, 25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'จำนวนสิทธิ์ที่เหลือ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dailyLimitData != null
                            ? formatThaiDate(dailyLimitData!['window_start'])
                            : '',
                        style: const TextStyle(
                          color: Color.fromARGB(255, 237, 20, 41),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Text(
                      dailyLimitData != null
                          ? '${dailyLimitData!['left_today']}/${dailyLimitData!['limit']}'
                          : '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // 📋 My Posts Section
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistoryOrderPage(),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'รายการของฉัน',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ดูทั้งหมด',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(80, 3, 130, 99),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SizedBox(
                height: 150,
                child: bookings.isNotEmpty
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        children: bookings.map((booking) {
                          final open = DateTime.fromMillisecondsSinceEpoch(
                            booking['open_time'] * 1000,
                          );
                          final close = DateTime.fromMillisecondsSinceEpoch(
                            booking['close_time'] * 1000,
                          );
                          String timeRange =
                              'เปิด ${open.hour}.${open.minute.toString().padLeft(2, '0')} - ${close.hour}.${close.minute.toString().padLeft(2, '0')}';
                          final expireAt = DateTime.parse(
                            booking['expire_at'],
                          ).toLocal();

                          return PreviewPostBox(
                            status: booking['status'],
                            title: booking['title'],
                            owner_image: booking['owner_image'],
                            openCloseTime: timeRange,
                            expireAt: expireAt,
                          );
                        }).toList(),
                      )
                    : const Center(
                        child: Text(
                          "ยังไม่มีรายการ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'ความสำเร็จ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SuccessBox(
                  width: successBoxWidth,
                  name: 'ประหยัดไป',
                  iconPath: 'assets/icons/coin.svg',
                  number: successData?['saving_baht'] ?? 0,
                  unit: 'บาท',
                ),
                const SizedBox(width: 12),
                SuccessBox(
                  width: successBoxWidth,
                  name: 'แบ่งบันไป',
                  iconPath: 'assets/icons/kindness_green.svg',
                  number: successData?['providing_count'] ?? 0,
                  unit: 'ครั้ง',
                ),
                const SizedBox(width: 12),
                SuccessBox(
                  width: successBoxWidth,
                  name: 'รับน้ำใจ',
                  iconPath: 'assets/icons/kindness_orange.svg',
                  number: successData?['receiving_count'] ?? 0,
                  unit: 'ครั้ง',
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (loadingPosts)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "โพสต์ของฉัน",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewMorePage(
                                type: 'user',
                                ownerId: userData!['user_id'].toString(),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF58319),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  PostPreviewSmall(items: allPosts),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: const NavBar(
        currentIndex: 3,
        hasNotification: false,
      ),
    );
  }
}

// ----- Updated PreviewPostBox -----
class PreviewPostBox extends StatelessWidget {
  final String status;
  final String title;
  final String owner_image;
  final String openCloseTime;
  final DateTime expireAt;

  const PreviewPostBox({
    super.key,
    required this.status,
    required this.title,
    required this.owner_image,
    required this.openCloseTime,
    required this.expireAt,
  });

  Color getStatusColor() {
    switch (status) {
      case "กำลังต่อคิว":
        return const Color.fromARGB(255, 245, 131, 25);
      case "ได้คิวแล้ว":
        return const Color.fromARGB(255, 3, 130, 99);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: getStatusColor()),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(color: getStatusColor(), fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey[200],
                backgroundImage: NetworkImage(owner_image),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 125,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    openCloseTime,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          CountdownBox(expireAt: expireAt, status: status),
        ],
      ),
    );
  }
}

class CountdownTicker {
  static final CountdownTicker _instance = CountdownTicker._internal();
  factory CountdownTicker() => _instance;
  CountdownTicker._internal() {
    _ticker = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    ).asBroadcastStream(); // multiple listeners
  }

  late Stream<DateTime> _ticker;
  Stream<DateTime> get ticker => _ticker;
}

class CountdownBox extends StatelessWidget {
  final String status;
  final DateTime expireAt;
  const CountdownBox({super.key, required this.status, required this.expireAt});

  Color getColor() {
    switch (status) {
      case "ได้คิวแล้ว":
        return Colors.green;
      case "กำลังต่อคิว":
        return const Color.fromARGB(255, 245, 131, 25);
      default:
        return Colors.grey;
    }
  }

  String formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
    } else {
      return "00:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    var color = getColor();
    var textshow = "รับอาหารภายใน ";

    return StreamBuilder<DateTime>(
      stream: CountdownTicker().ticker,
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        Duration duration = expireAt.difference(now);
        bool isExpired = duration.isNegative || duration.inSeconds <= 0;
        if (isExpired) {
          duration = Duration.zero;
          color = Colors.grey;
          textshow = "หมดเวลารับ";
        }

        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(textshow, style: TextStyle(fontSize: 12, color: color)),
              const SizedBox(width: 4),
              if (!isExpired) ...[
                const SizedBox(width: 4),
                Text(
                  formatDuration(duration),
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Horizontal success boxes
class SuccessBox extends StatelessWidget {
  final double width;
  final String name;
  final String iconPath;
  final int number;
  final String unit;

  const SuccessBox({
    super.key,
    required this.width,
    required this.name,
    required this.iconPath,
    required this.number,
    required this.unit,
  });

  Color getSuccessColor() {
    switch (name) {
      case "ประหยัดไป":
        return const Color.fromARGB(255, 237, 20, 41);
      case "แบ่งบันไป":
        return const Color.fromARGB(255, 3, 130, 99);
      case "รับน้ำใจ":
        return const Color.fromARGB(255, 245, 131, 25);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: getSuccessColor(),
              fontSize: 20,
            ),
          ),
          SizedBox(height: 10),
          SvgPicture.asset(iconPath, width: 47, height: 47),
          SizedBox(height: 10),
          Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: getSuccessColor(),
            ),
          ),
          SizedBox(height: 5),
          Text(unit, style: TextStyle(color: getSuccessColor(), fontSize: 20)),
        ],
      ),
    );
  }
}
