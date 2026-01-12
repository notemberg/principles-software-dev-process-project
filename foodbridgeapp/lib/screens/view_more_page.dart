import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'post_page.dart';

class ViewMorePage extends StatefulWidget {
  final String type;
  final String ownerId;
  const ViewMorePage({super.key, required this.type, required this.ownerId});

  @override
  State<ViewMorePage> createState() => _ViewMorePageState();
}

class _ViewMorePageState extends State<ViewMorePage> {
  String selectedFilter = 'ทั้งหมด';
  List<Map<String, String>> allPosts = [];
  bool loadingPosts = true;
  final _storage = const FlutterSecureStorage();
  String? currentProvince;
  LatLng? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserProvinceAndPosition();
    await fetchAllPosts();
  }

  Future<void> _loadUserProvinceAndPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
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
      if (!mounted) return;
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
        _currentUserPosition = LatLng(13.7563, 100.5018);
      });
    }
  }

  Future<String> _getDistanceText(double? lat, double? lng) async {
    if (lat == null || lng == null || _currentUserPosition == null)
      return '- km';
    final distance =
        Geolocator.distanceBetween(
          _currentUserPosition!.latitude,
          _currentUserPosition!.longitude,
          lat,
          lng,
        ) /
        1000;
    return distance > 999 ? '999+ km' : "${distance.toStringAsFixed(2)} km";
  }

  Future<void> fetchAllPosts() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    List<String> apiUrls = [];
    String postType = widget.type.toLowerCase(); // "free" / "sale" / "user"

    if (postType == 'user') {
      apiUrls = [
        'https://foodbridge1.onrender.com/users/${widget.ownerId}/posts',
      ];
    } else {
      apiUrls = [
        'https://foodbridge1.onrender.com/posts?status=CLOSED',
        'https://foodbridge1.onrender.com/posts',
      ];
    }

    List<Map<String, String>> postList = [];

    try {
      // Loop through all APIs
      for (String url in apiUrls) {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode != 200) {
          debugPrint(
            "❌ Failed to fetch posts from $url : ${response.statusCode}",
          );
          continue; // skip this API
        }

        final data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? [];

        for (final item in items) {
          final bool isGiveaway =
              item['is_giveaway'] == true || item['is_giveaway'] == 'true';
          if ((postType == 'free' && !isGiveaway) ||
              (postType == 'sale' && isGiveaway))
            continue;
          if (postType == 'category' &&
              (item['categories'] == null ||
                  item['categories'].isEmpty ||
                  item['categories'].first != widget.ownerId)) {
            continue;
          }

          final images = item['images'] ?? [];
          final imageUrl = (images.isNotEmpty && images.first is String)
              ? images.first
              : 'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445';

          DateTime createdAtDate =
              DateTime.tryParse(item['created_at'].toString()) ?? DateTime(0);

          double? lat = (item['lat'] as num?)?.toDouble();
          double? lng = (item['lng'] as num?)?.toDouble();
          String kiloText = await _getDistanceText(lat, lng);

          Map<String, dynamic> ownerData = {};
          final ownerRes = await http.get(
            Uri.parse(
              'https://foodbridge1.onrender.com/users/${item['provider_id']}',
            ),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (ownerRes.statusCode == 200) ownerData = jsonDecode(ownerRes.body);

          Map<String, dynamic> bookingData = {};
          final bookingRes = await http.get(
            Uri.parse(
              'https://foodbridge1.onrender.com/bookings?post_id=${item['post_id']}&status=PENDING,QUEUED,COMPLETED',
            ),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (bookingRes.statusCode == 200)
            bookingData = jsonDecode(bookingRes.body);

          String shop =
              (item['categories'] == null || item['categories'].isEmpty)
              ? 'No categories'
              : (item['categories'] as List).join(', ');

          String queue = 'กำลังรอคิว - คน';
          String leftQueue = '';
          int quantity = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          int receiverCount =
              int.tryParse(bookingData['receiver_count']?.toString() ?? '0') ??
              0;
          queue = 'กำลังรอคิว $receiverCount คน';
          leftQueue = 'คงเหลือ ${quantity - receiverCount} ที่';

          bool isOpen = item['status'] == 'OPEN';

          postList.add({
            'id': item['post_id'].toString(),
            'image': imageUrl,
            'title': item['title'] ?? '-',
            'location':
                (item['address'] == null || item['address'].toString().isEmpty)
                ? 'ไม่ระบุสถานที่'
                : item['address'].toString(),
            'kilo': kiloText,
            'owner': ownerData['full_name']?.toString() ?? '-',
            'created_at': createdAtDate.toIso8601String(),
            'price': item['price'] == null
                ? '฿-'
                : "฿${item['price'].toString()}",
            'queue': queue,
            'left_queue': leftQueue,
            'isOpen': isOpen.toString(),
            'category': shop,
          });
        }
      }

      // Sort by created_at descending
      postList.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        allPosts = postList;
        loadingPosts = false;
      });
    } catch (e) {
      debugPrint("💥 Error fetching posts: $e");
      if (!mounted) return;
      setState(() => loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredGiveaways = allPosts.where((item) {
      if (selectedFilter == 'ทั้งหมด') return true;
      if (selectedFilter == 'เปิดจอง') return item['isOpen'] == 'true';
      if (selectedFilter == 'ปิดจอง') return item['isOpen'] == 'false';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายการทั้งหมด',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.black54, size: 18),
                SizedBox(width: 4),
                Text(
                  'อ้างอิงจากสถานที่ของคุณ : ',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Flexible(
                  child: Text(
                    currentProvince ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: loadingPosts
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredGiveaways.isEmpty
                        ? const Center(
                            child: Text(
                              'ไม่มีรายการในตอนนี้ 😅',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredGiveaways.length,
                            itemBuilder: (context, index) {
                              final item = filteredGiveaways[index];
                              return GiveawayCard(
                                id: item['id'] ?? '1',
                                imageUrl:
                                    item['image'] ??
                                    'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445',
                                title: item['title'] ?? '-',
                                kilo: item['kilo'] ?? '- km',
                                owner: item['owner'] ?? '-',
                                leftQueue: item['left_queue'] ?? '',
                                queue: item['queue'] ?? '',
                                category: item['category'] ?? '',
                                isOpen: item['isOpen'] == 'true',
                                price: item['price'] ?? '฿-',
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

class GiveawayCard extends StatelessWidget {
  final String id;
  final String imageUrl;
  final String title;
  final String kilo;
  final String owner;
  final String leftQueue;
  final String queue;
  final String category;
  final bool isOpen;
  final String price;

  const GiveawayCard({
    super.key,
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.kilo,
    required this.owner,
    required this.leftQueue,
    required this.queue,
    required this.category,
    required this.isOpen,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostPage(postId: int.parse(id))),
        );
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.white,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 100,
                      height: 110,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 180,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                              kilo,
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
                            Text(
                              owner,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
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
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              price,
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
                                leftQueue,
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
                                queue,
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
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isOpen ? Color.fromARGB(255, 3, 130, 99) : Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOpen ? 'เปิดจอง' : 'ปิดจอง',
                  style: TextStyle(
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
