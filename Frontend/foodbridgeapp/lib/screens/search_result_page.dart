import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import 'post_page.dart';

class SearchResultPage extends StatefulWidget {
  final String keyword;
  const SearchResultPage({super.key, required this.keyword});

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  final _storage = const FlutterSecureStorage();

  bool loading = true;
  String? currentProvince; // ไม่ได้ใช้แล้วแต่ขอคงไว้
  LatLng? _currentUserPosition;

  List<Map<String, dynamic>> freePosts = [];
  List<Map<String, dynamic>> salePosts = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadUserProvinceAndPosition();
    await _fetchSearchPosts();
  }

  Future<void> _loadUserProvinceAndPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentProvince = placemarks.isNotEmpty
            ? placemarks.first.administrativeArea ?? "No Where"
            : "No Where";
        _currentUserPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint("Error reverse geocoding: $e");
      setState(() {
        currentProvince = "No Where";
        _currentUserPosition = const LatLng(13.7563, 100.5018);
      });
    }
  }

  Future<String> _getDistanceText(double? lat, double? lng) async {
    if (lat == null || lng == null || _currentUserPosition == null) {
      return '- km';
    }
    final distanceKm = Geolocator.distanceBetween(
          _currentUserPosition!.latitude,
          _currentUserPosition!.longitude,
          lat,
          lng,
        ) /
        1000.0;
    return distanceKm > 999
        ? '999+ km'
        : "${distanceKm.clamp(0, 999).toStringAsFixed(2)} km";
  }

  bool _isGiveaway(dynamic item) {
    final v = item['is_giveaway'] ?? item['isgiveaway'];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return false;
  }

  Future<void> _fetchSearchPosts() async {
    final token = await _storage.read(key: 'token');
    if (token == null) {
      setState(() => loading = false);
      return;
    }

    final q = Uri.encodeComponent(widget.keyword);

    final urls = [
      'https://foodbridge1.onrender.com/posts?q=$q',
      'https://foodbridge1.onrender.com/posts?status=CLOSED&q=$q',
    ];

    final List<Map<String, dynamic>> tmpFree = [];
    final List<Map<String, dynamic>> tmpSale = [];

    try {
      for (final url in urls) {
        final res = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (res.statusCode != 200) {
          debugPrint('❌ search fail ${res.statusCode} : $url');
          continue;
        }

        final data = jsonDecode(res.body);
        final List items = data['items'] ?? [];

        for (final item in items) {
          final images = item['images'] ?? [];
          final imageUrl = (images.isNotEmpty && images.first is String)
              ? images.first as String
              : 'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445';

          DateTime createdAt =
              DateTime.tryParse(item['created_at'].toString()) ?? DateTime(0);

          final lat = (item['lat'] as num?)?.toDouble();
          final lng = (item['lng'] as num?)?.toDouble();
          final kiloText = await _getDistanceText(lat, lng);

          // owner
          Map<String, dynamic> ownerData = {};
          final ownerRes = await http.get(
            Uri.parse(
              'https://foodbridge1.onrender.com/users/${item['provider_id']}',
            ),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (ownerRes.statusCode == 200) {
            ownerData = jsonDecode(ownerRes.body);
          }

          // booking
          Map<String, dynamic> bookingData = {};
          final bookingRes = await http.get(
            Uri.parse('https://foodbridge1.onrender.com/bookings?post_id=${item['post_id']}&status=PENDING,QUEUED,COMPLETED'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (bookingRes.statusCode == 200) {
            bookingData = jsonDecode(bookingRes.body);
          }

          String category;
          if (item['categories'] == null || item['categories'].isEmpty) {
            category = 'No categories';
          } else {
            category = (item['categories'] as List).join(', ');
          }

          int quantity =
              int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          int receiverCount =
              int.tryParse(bookingData['receiver_count']?.toString() ?? '0') ??
                  0;

          final leftText = 'คงเหลือ ${quantity - receiverCount} ที่';
          final queueText = 'กำลังรอคิว $receiverCount คน';

          final bool isOpen = item['status'] == 'OPEN';
          final bool isFree = _isGiveaway(item);

          final map = <String, dynamic>{
            'id': item['post_id'].toString(),
            'image': imageUrl,
            'title': item['title']?.toString() ?? '-',
            'location': (item['address'] == null ||
                    item['address'].toString().isEmpty)
                ? 'ไม่ระบุสถานที่'
                : item['address'].toString(),
            'kilo': kiloText,
            'owner': ownerData['full_name']?.toString() ?? '-',
            'created_at': createdAt.toIso8601String(),
            'price': item['price'] == null
                ? '฿-'
                : "฿${item['price'].toString()}",
            'queue': queueText,
            'left_queue': leftText,
            'isOpen': isOpen.toString(),
            'category': category,
          };

          if (isFree) {
            tmpFree.add(map);
          } else {
            tmpSale.add(map);
          }
        }
      }

      tmpFree.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });
      tmpSale.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });

      setState(() {
        freePosts = tmpFree;
        salePosts = tmpSale;
        loading = false;
      });
    } catch (e) {
      debugPrint("💥 search error: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalResults = freePosts.length + salePosts.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ผลการค้นหา: "${widget.keyword}"',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'จำนวนผลลัพธ์ทั้งหมด $totalResults ผลลัพธ์',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (freePosts.isEmpty && salePosts.isEmpty)
              ? const Center(
                  child: Text(
                    'ไม่พบรายการที่ค้นหา 😅',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ฟรีก่อน
                    ...freePosts.map((e) => _SearchCard(item: e)).toList(),
                    // แล้วค่อยรายการขาย (แต่ไม่ต้องมีหัวข้อแล้ว)
                    ...salePosts.map((e) => _SearchCard(item: e)).toList(),
                  ],
                ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _SearchCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isOpen = item['isOpen'] == 'true';

    // กันพื้นที่ให้ badge ด้านขวา
    final screenWidth = MediaQuery.of(context).size.width;
    // card มี padding ซ้าย 10 + รูป 100 + ช่องว่าง 12 + padding ขวา 10 + badge 70
    // เหลือพื้นที่ให้ title ประมาณนี้
    final titleMaxWidth = screenWidth - (10 + 100 + 12 + 10 + 70);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PostPage(postId: int.parse(item['id'].toString())),
          ),
        );
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: Colors.white,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['image']?.toString() ?? '',
                      width: 100,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return Image.network(
                          'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445',
                          width: 100,
                          height: 110,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // detail
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title ที่จะไม่ชน badge
                        SizedBox(
                          width: 180,
                          child: Text(
                            item['title']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/bike.svg',
                              width: 10,
                              height: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item['kilo']?.toString() ?? '- km',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SvgPicture.asset(
                              'assets/icons/owner.svg',
                              width: 10,
                              height: 10,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                item['owner']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['category']?.toString() ?? 'No categories',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item['price']?.toString() ?? '',
                              style: const TextStyle(
                                color: Color(0xFFED1429),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Color(0xFFF58319)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['left_queue']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF58319),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFF58319),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['queue']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
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

            // badge open/close
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFF038263) : Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOpen ? 'เปิดจอง' : 'ปิดจอง',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
