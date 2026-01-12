import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:foodbridgeapp/verified_service.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'post_page.dart';
import 'nav_bar.dart';
import 'profile_page.dart';
import 'view_more_page.dart';

int? userIdUse;

String formatKilo(String? kiloText) {
  if (kiloText == null || kiloText.isEmpty) return '-';

  // strip " km" and try parse
  final numPart = double.tryParse(kiloText.replaceAll(' km', '').trim());
  if (numPart == null) return kiloText;

  if (numPart > 999) {
    return '999+ km';
  } else {
    return '${numPart.toStringAsFixed(0)} km';
  }
}

class OtherProfilePage extends StatefulWidget {
  final int userId;
  const OtherProfilePage({super.key, required this.userId});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? successData;
  List<Map<String, String>> allPosts = [];
  bool loadingPosts = true;
  final _storage = const FlutterSecureStorage();
  String? currentProvince;
  LatLng? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    await _loadUserProvinceAndPosition(); // cache user position first
    await fetchUserData();
    await fetchAllPosts();
    await _loadSuccess();
  }

  Future<void> fetchUserData() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      final res = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/users/${widget.userId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      userIdUse = widget.userId;

      if (res.statusCode == 200) {
        setState(() => userData = json.decode(res.body));
      } else {
        debugPrint('Error fetching user: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _loadSuccess() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse(
        'https://foodbridge1.onrender.com/users/${widget.userId}/stats/success',
      ),
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
          'https://foodbridge1.onrender.com/users/${widget.userId}/posts',
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
    showDialog(
      context: context,
      builder: (_) => ShareProfilePopup(userId: widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final successBoxWidth = (screenWidth - 56) / 3;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 244, 243, 243),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ผู้ใช้งาน',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _showSharePopup,
          ),
        ],
      ),
      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 90,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: NetworkImage(
                      userData?['avatar_url'] ??
                          'https://www.shutterstock.com/image-vector/avatar-gender-neutral-silhouette-vector-600nw-2470054311.jpg',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userData?['full_name'] ?? 'Unknown',
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
                  const SizedBox(height: 6),
                  Text(
                    userData?['bio'] ?? 'คำอธิบายตัวเองสั้นๆ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    // color: Colors.white,
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ความสำเร็จ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

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
                        _HeaderRow(name: 'โพสต์ของฉัน'),
                        PostPreviewSmall(items: allPosts),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String name;

  const _HeaderRow({required this.name, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ViewMorePage(type: 'user', ownerId: userIdUse.toString()),
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
    );
  }
}

class PostPreviewSmall extends StatelessWidget {
  final List<Map<String, String>> items;

  const PostPreviewSmall({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 226, 226, 226),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const SizedBox(height: 12),
          items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Text(
                      "ยังไม่มีโพสต์",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _ItemCard(item: items[index]);
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, String> item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostPage(postId: int.parse(item['id']!)),
          ),
          // MaterialPageRoute(builder: (_) => const PostPage()),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          // boxShadow: const [
          //   BoxShadow(
          //     // color: Colors.black12,
          //     blurRadius: 8,
          //     spreadRadius: 2,
          //     offset: Offset(0, 0),
          //   ),
          // ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildImage(), const SizedBox(height: 8), _buildDetails()],
        ),
      ),
    );
  }

  Widget _buildImage() => ClipRRect(
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    ),
    child: Image.network(
      item['image']!,
      width: 160,
      height: 80,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.network(
          'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445',
          width: 160,
          height: 80,
          fit: BoxFit.cover,
        );
      },
    ),
  );

  Widget _buildDetails() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140, // or whatever width fits your layout
          child: Text(
            item['title']!,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/location.svg',
              width: 12,
              height: 12,
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 130, // or whatever width fits your layout
              child: Text(
                item['location']!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 10, color: Colors.black),
              ),
            ),
          ],
        ),
        Row(
          children: [
            SvgPicture.asset('assets/icons/bike.svg', width: 10, height: 10),
            const SizedBox(width: 3),
            Text(
              item['kilo']!,
              // double.tryParse(item['kilo']?.replaceAll(' km', '') ?? '0') != null
              //     ? "${double.parse(item['kilo']!.replaceAll(' km', '')).clamp(0, 999).toStringAsFixed(0)} km"
              //     : item['kilo']!,
              style: const TextStyle(fontSize: 10, color: Color(0xff828282)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '|',
                style: TextStyle(fontSize: 10, color: Color(0xff828282)),
              ),
            ),
            SvgPicture.asset('assets/icons/owner.svg', width: 10, height: 10),
            const SizedBox(width: 3),
            Text(
              item['owner']!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xff828282)),
            ),
          ],
        ),
      ],
    ),
  );
}

class ShareProfilePopup extends StatefulWidget {
  final int userId;
  const ShareProfilePopup({super.key, required this.userId});

  @override
  State<ShareProfilePopup> createState() => _ShareProfilePopupState();
}

class _ShareProfilePopupState extends State<ShareProfilePopup> {
  late TextEditingController _linkController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController();
    _fetchShareLink();
  }

  Future<void> _fetchShareLink() async {
    final _storage = const FlutterSecureStorage();
    final token = await _storage.read(key: 'token');
    if (token == null) return;
    final url = Uri.parse(
      'https://foodbridge1.onrender.com/users/${widget.userId}/share-link',
    );
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final link = data['share_url'] ?? 'No link found';
        setState(() {
          _linkController.text = link;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการโหลดลิงก์ 😢';
        _loading = false;
      });
    }
  }

  void _copyLink() {
    if (_linkController.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _linkController.text));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("คัดลอกลิงก์แล้ว! 🚀")));
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // title row with back icon
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(Icons.arrow_back, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'แชร์โปรไฟล์นี้',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // orange divider line under title
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: const Color(0xFFF58319).withOpacity(0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 12),

            // loading / error / content
            _loading
                ? const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      const Text(
                        'ส่งลิงก์ในช่องทาง',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/facebook.svg',
                            width: 36,
                            height: 36,
                          ),
                          SvgPicture.asset(
                            'assets/icons/instagram.svg',
                            width: 36,
                            height: 36,
                          ),
                          SvgPicture.asset(
                            'assets/icons/twitter.svg',
                            width: 36,
                            height: 36,
                          ),
                          SvgPicture.asset(
                            'assets/icons/line.svg',
                            width: 36,
                            height: 36,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'หรือคัดลอกลิงก์',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      // capsule copy field
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: TextField(
                                  controller: _linkController,
                                  readOnly: true,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'ลิงก์ของคุณ',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: double.infinity,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF58319),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(24),
                                  bottomRight: Radius.circular(24),
                                ),
                              ),
                              child: TextButton(
                                onPressed: _copyLink,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 0,
                                  ),
                                ),
                                child: const Text(
                                  'คัดลอก',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 6),
            // no actions row — close only via back icon or tapping outside (if enabled)
          ],
        ),
      ),
    );
  }
}
