import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ของโปรเจกต์เธอเอง
import 'nav_bar.dart';
import 'show_history_detail_page.dart';

/// ===========================================================
/// 1) SERVICE: เอา token จาก storage + /me
/// ===========================================================
class VerifiedService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'token';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// คืนเป็น map ของ user เช่น { "user_id": 9, "email": "...", ... }
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    final res = await http.get(
      Uri.parse('https://foodbridge1.onrender.com/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }
}

/// ===========================================================
/// 2) API SERVICE สำหรับ history/booking
/// ===========================================================
class HistoryApiService {
  static const String baseUrl = 'https://foodbridge1.onrender.com';

  /// GET /bookings?receiver_user_id=...
  static Future<List<Map<String, dynamic>>> getBookings(
    String token,
    int receiverUserId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/bookings?receiver_user_id=$receiverUserId',
    );

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      // เคสปกติ
      if (data is Map && data['items'] is List) {
        return (data['items'] as List)
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      }

      // เผื่อ backend ส่งเป็น list ตรงๆ
      if (data is List) {
        return data.map<Map<String, dynamic>>((e) {
          return Map<String, dynamic>.from(e as Map);
        }).toList();
      }

      return [];
    } else {
      debugPrint('getBookings error: ${res.statusCode} ${res.body}');
      return [];
    }
  }

  /// GET /posts/:postId → เอาไว้ดึงชื่อโพสต์ ราคา ที่อยู่ is_giveaway ฯลฯ
  static Future<Map<String, dynamic>?> getPostDetails(
    String token,
    int postId,
  ) async {
    final url = Uri.parse('$baseUrl/posts/$postId');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body);

      // แบบ 1: ส่งมาเป็น object ตรงๆ
      if (raw is Map && raw['post_id'] != null) {
        return raw as Map<String, dynamic>;
      }

      // แบบ 2: ห่อใน data
      if (raw is Map && raw['data'] is Map) {
        return raw['data'] as Map<String, dynamic>;
      }

      if (raw is Map<String, dynamic>) {
        return raw;
      }

      return null;
    } else {
      debugPrint('getPostDetails error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  /// ดึง booking แล้วผูก post ให้แต่ละตัว
  static Future<List<Map<String, dynamic>>> getBookingsWithPost(
    String token,
    int receiverUserId,
  ) async {
    final bookings = await getBookings(token, receiverUserId);

    // ทำ parallel ทีละ booking
    final futures = bookings.map<Future<Map<String, dynamic>>>((b) async {
      final rawPostId = b['post_id'];
      Map<String, dynamic>? postData;

      if (rawPostId != null) {
        final int postId = rawPostId is int
            ? rawPostId
            : int.tryParse(rawPostId.toString()) ?? 0;

        if (postId != 0) {
          postData = await getPostDetails(token, postId);
        }
      }

      return {...b, 'post': postData};
    }).toList();

    return await Future.wait(futures);
  }
}

/// ===========================================================
/// 3) HISTORY PAGE หลัก
/// ===========================================================
class HistoryOrderPage extends StatefulWidget {
  const HistoryOrderPage({super.key});

  @override
  State<HistoryOrderPage> createState() => _HistoryOrderPageState();
}

class _HistoryOrderPageState extends State<HistoryOrderPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // 1) เอา token
    final token = await VerifiedService.getToken();
    if (token == null) {
      throw Exception('ยังไม่ได้ล็อกอิน');
    }

    // 2) เอา /me ก่อนเพื่อรู้ id
    final me = await VerifiedService.getCurrentUser();
    if (me == null) {
      throw Exception('โหลดข้อมูลผู้ใช้ไม่สำเร็จ');
    }

    // ปกติ backend จะส่ง user_id, แต่ถ้าเธอใช้ "id" ก็ลองทั้งคู่
    final dynamic rawId = me['user_id'] ?? me['id'];
    if (rawId == null) {
      throw Exception('ไม่พบ user id ใน /me');
    }

    final int receiverUserId =
        rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    if (receiverUserId == 0) {
      throw Exception('user id ไม่ถูกต้อง');
    }

    // 3) เอา id ไปยิง /bookings?receiver_user_id=...
    final bookings = await HistoryApiService.getBookingsWithPost(
      token,
      receiverUserId,
    );

    return bookings;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const NavBar(
          currentIndex: 1,
          hasNotification: false,
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xff2A2929),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'ประวัติการทำรายการ',
            style: TextStyle(
              color: Color(0xff2A2929),
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          top: false, // เรามี AppBar แล้ว
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ถ้าไม่อยากให้มี title ซ้ำกับ AppBar เอา block นี้ออกได้


                // Tab header
                const SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TabBar(
                    isScrollable: true,
                    indicatorColor: Color(0xff038263),
                    labelColor: Color(0xff038263),
                    unselectedLabelColor: Color(0xff696969),
                    labelStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IBMPlexSansThai',
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'IBMPlexSansThai',
                    ),
                    tabs: [
                      Tab(text: 'กำลังทำ'),
                      Tab(text: 'เสร็จแล้ว'),
                      Tab(text: 'ยกเลิก/ล้มเหลว'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final all = snapshot.data ?? [];

                      // แยกตาม status
                      final doing = all.where((e) {
                        final s = (e['status'] ?? '').toString().toUpperCase();
                        return s == 'PENDING' || s == 'QUEUED';
                      }).toList();

                      final done = all.where((e) {
                        final s = (e['status'] ?? '').toString().toUpperCase();
                        return s == 'COMPLETED';
                      }).toList();

                      final failed = all.where((e) {
                        final s = (e['status'] ?? '').toString().toUpperCase();
                        return s == 'CANCELLED' ||
                            s == 'FAILED' ||
                            s == 'REJECTED' ||
                            s == 'EXPIRED';
                      }).toList();

                      return TabBarView(
                        children: [
                          _BookingList(data: doing),
                          _BookingList(data: done),
                          _BookingList(data: failed),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===========================================================
/// 4) LIST แต่ละแท็บ
/// ===========================================================
class _BookingList extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _BookingList({required this.data});

  String _formatThaiDateTime(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const thMonths = [
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.',
      ];
      final day = dt.day;
      final monthName = thMonths[dt.month - 1];
      final year2 = dt.year % 100;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$day $monthName $year2, $hh:$mm';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('ยังไม่มีรายการ'));
    }

    return ListView.separated(
      itemCount: data.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = data[index];

        final bookingId = item['booking_id']?.toString() ?? '-';
        final postIdRaw = item['post_id'];
        final int postId = postIdRaw is int
            ? postIdRaw
            : int.tryParse(postIdRaw.toString()) ?? 0;

        final status = (item['status'] ?? '').toString();
        final createdAtRaw = item['created_at']?.toString() ?? '';
        final createdAt = _formatThaiDateTime(createdAtRaw);

        // post ที่เราแมปมาจาก /posts/:id
        final post = item['post'] as Map<String, dynamic>?;

        final price = post?['price'];
        final isGiveaway = post?['is_giveaway'];
        final address = post?['address'];
        final postName = post?['title'] ?? 'โพสต์ #$postId'; // กัน null

        // แปลงสถานะเป็นไทย
        String textStatus = '';
        switch (status) {
          case 'QUEUED':
            textStatus = 'กำลังรอคิว';
            break;
          case 'PENDING':
            textStatus = 'กำลังดำเนินการ';
            break;
          case 'COMPLETED':
            textStatus = 'รายการสำเร็จแล้ว';
            break;
          case 'CANCELLED':
            textStatus = 'ยกเลิกรายการแล้ว';
            break;
          case 'EXPIRED':
            textStatus = 'รายการหมดเวลาแล้ว';
            break;
          default:
            textStatus = status;
        }

        return ListTile(
          onTap: () {
            // ถ้ามี postId ค่อยไปหน้า detail
            if (postId != 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShowHistoryDetailPage(
                    bookingId: int.tryParse(bookingId) ?? 0,
                  ),
                ),
              );
            }
          },
          leading: SizedBox(
            width: 45,
            height: 45,
            child: SvgPicture.asset(
              'assets/icons/order_list.svg',
              fit: BoxFit.contain,
            ),
          ),
          subtitle: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ซ้าย
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(createdAt),
                    Text(
                      postName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff000000),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (address != null && address.toString().isNotEmpty)
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/red_location.svg',
                            width: 12,
                            height: 12,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xff828282),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Text(
                      textStatus,
                      style: const TextStyle(
                        color: Color(0xff038263),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ขวา
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 4),
                  if (isGiveaway != null)
                    Text(
                      isGiveaway == true ? 'ไม่มีค่าใช้จ่าย' : 'มีค่าใช้จ่าย',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xffF58319),
                      ),
                    ),
                  if (price != null)
                    Text(
                      '${price}฿',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffED1429),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
