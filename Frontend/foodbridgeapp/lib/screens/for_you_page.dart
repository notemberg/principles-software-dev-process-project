import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import 'post_page.dart';
import 'create_post.dart';
import 'view_more_page.dart';
import 'search_result_page.dart';

class ForYouPage extends StatefulWidget {
  const ForYouPage({super.key});

  @override
  State<ForYouPage> createState() => _ForYouPageState();
}

class _ForYouPageState extends State<ForYouPage> {
  // เก็บโพสต์
  List<Map<String, dynamic>> allFreePosts = [];
  List<Map<String, dynamic>> allSalePosts = [];

  bool loading = true;

  final _storage = const FlutterSecureStorage();
  LatLng? _currentUserPosition;
  final TextEditingController _searchCtrl = TextEditingController();

  final categories_4 = const [
    {'icon': 'assets/images/meal.png', 'label': 'ของคาว'},
    {'icon': 'assets/images/dessert.png', 'label': 'ของหวาน'},
    {'icon': 'assets/images/meat.png', 'label': 'เนื้อสด'},
    {'icon': 'assets/images/veggies.png', 'label': 'ผัก'},
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadUserLocation();
    await _fetchPostsLight();
  }

  Future<void> _loadUserLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      _currentUserPosition = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      _currentUserPosition = const LatLng(13.7563, 100.5018);
    }
  }

  // เช็กฟรี/ไม่ฟรี
  bool _isGiveaway(dynamic item) {
    final v = item['is_giveaway'] ?? item['isgiveaway'];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return false;
  }

  Future<String> _distanceText(dynamic latRaw, dynamic lngRaw) async {
    final lat = (latRaw as num?)?.toDouble();
    final lng = (lngRaw as num?)?.toDouble();
    if (lat == null || lng == null || _currentUserPosition == null) {
      return '- km';
    }
    final m = Geolocator.distanceBetween(
      _currentUserPosition!.latitude,
      _currentUserPosition!.longitude,
      lat,
      lng,
    );
    final km = m / 1000.0;
    return km > 999 ? '999+ km' : '${km.toStringAsFixed(2)} km';
  }

  // เวอร์ชันเบา: ดึงแค่ /posts ทีเดียว แล้วแยกในแอป
  Future<void> _fetchPostsLight() async {
    final token = await _storage.read(key: 'token');
    if (token == null) {
      setState(() => loading = false);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/posts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        setState(() => loading = false);
        return;
      }

      final data = jsonDecode(res.body);
      final List items = data['items'] ?? [];

      final List<Map<String, dynamic>> tmpFree = [];
      final List<Map<String, dynamic>> tmpSale = [];

      // ดึงระยะทางแบบ async ทั้งก้อน
      final futures = items.map<Future<void>>((item) async {
        final images = item['images'] ?? [];
        final imageUrl = (images.isNotEmpty && images.first is String)
            ? images.first as String
            : 'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445';

        final createdAt = DateTime.tryParse(item['created_at'].toString()) ??
            DateTime(0);

        final kiloText = await _distanceText(item['lat'], item['lng']);

        String cat;
        if (item['categories'] == null || item['categories'].isEmpty) {
          cat = 'No categories';
        } else {
          cat = (item['categories'] as List).join(', ');
        }

        Map<String, dynamic> ownerData = {};
        final responseUser = await http.get(
          Uri.parse(
            'https://foodbridge1.onrender.com/users/${item['provider_id']}',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (responseUser.statusCode == 200) {
            ownerData = jsonDecode(responseUser.body);
          } else {
            debugPrint('Failed to load user: ${responseUser.statusCode}');
          }

        final map = <String, dynamic>{
          'id': item['post_id'].toString(),
          'image': imageUrl,
          'title': item['title']?.toString() ?? '-',
          'location': (item['address'] == null ||
                  item['address'].toString().isEmpty)
              ? 'ไม่ระบุสถานที่'
              : item['address'].toString(),
          'kilo': kiloText,
          'owner': ownerData['full_name'] ?? "Unknown",
          'created_at': createdAt.toIso8601String(),
          'shop': cat,
          'price': item['price'] == null
              ? '฿-'
              : '฿${item['price'].toString()}',
        };

        if (_isGiveaway(item)) {
          tmpFree.add(map);
        } else {
          tmpSale.add(map);
        }
      }).toList();

      await Future.wait(futures);

      // sort ให้เหมือนเดิม
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

      if (!mounted) return;
      setState(() {
        allFreePosts = tmpFree;
        allSalePosts = tmpSale;
        loading = false;
      });
    } catch (e) {
      debugPrint('fetch error: $e');
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  void _goToSearch(String text) {
    if (text.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultPage(keyword: text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // search box
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: _goToSearch,
                decoration: InputDecoration(
                  hintText: 'ค้นหาสิ่งที่คุณต้องการ',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SvgPicture.asset(
                      'assets/icons/search_icon.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _goToSearch(_searchCtrl.text),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (loading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // free
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'รายการแจกฟรีใกล้ฉัน',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ViewMorePage(
                                type: 'free',
                                ownerId: '2',
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
                  PostPreviewSmall(items: allFreePosts),

                  const SizedBox(height: 20),

                  // sale
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Flash Sale ลดเดือดชั่วโมงนี้ ⚡',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ViewMorePage(
                                type: 'sale',
                                ownerId: '2',
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
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: allSalePosts.length,
                      itemBuilder: (context, index) {
                        final item = allSalePosts[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostPage(
                                  postId: int.parse(item['id'].toString()),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12, blurRadius: 8),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    topRight: Radius.circular(10),
                                  ),
                                  child: Image.network(
                                    item['image']?.toString() ?? '',
                                    width: 160,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) {
                                      return Image.network(
                                        'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445',
                                        width: 160,
                                        height: 140,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title']?.toString() ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      Text(
                                        item['shop']?.toString() ?? '',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xff828282)),
                                      ),
                                      Row(
                                        children: [
                                          SvgPicture.asset(
                                            'assets/icons/location.svg',
                                            width: 12,
                                            height: 12,
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              item['location']?.toString() ??
                                                  '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xff828282)),
                                            ),
                                          ),
                                        ],
                                      ),
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
                                                fontSize: 10,
                                                color: Color(0xff828282)),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        item['price']?.toString() ?? '฿-',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xffED1429),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "หมวดหมู่แนะนำ",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: categories_4.map((cat) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewMorePage(
                                type: 'category',
                                ownerId: cat['label']!,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Image.asset(cat['icon']!, width: 50, height: 50),
                            const SizedBox(height: 4),
                            Text(
                              cat['label']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFF58319),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostPage()),
          );
        },
        backgroundColor: const Color(0xFFF58319),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class PostPreviewSmall extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const PostPreviewSmall({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('ยังไม่มีโพสต์')),
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
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostPage(postId: int.parse(item['id'].toString())),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              child: Image.network(
                item['image']?.toString() ?? '',
                width: 160,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Image.network(
                    'https://genconnect.com.sg/cdn/shop/files/Display.jpg?v=1684741232&width=1445',
                    width: 160,
                    height: 80,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']?.toString() ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/location.svg',
                        width: 12,
                        height: 12,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          item['location']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
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
                            fontSize: 10, color: Color(0xff828282)),
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
            ),
          ],
        ),
      ),
    );
  }
}
