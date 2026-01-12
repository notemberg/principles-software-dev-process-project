// show_history_detail_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'report_page.dart'; // ไว้สร้างทีหลัง

// (ยังเก็บไว้ เผื่อหน้า report เอาไปใช้)
const List<Map<String, String>> reportTypeOptions = [
  {'code': 'PRIVACY', 'label': 'ขอข้อมูลส่วนตัว'},
  {'code': 'SPAM', 'label': 'สแปม / โปรโมต'},
  {'code': 'SCAM', 'label': 'หลอกลวง / เรียกโอนเงิน'},
  {'code': 'INAPPROPRIATE', 'label': 'เนื้อหาไม่เหมาะสม'},
  {'code': 'OTHER', 'label': 'อื่น ๆ'},
];

const Set<String> allowedReportTypes = {
  'PRIVACY',
  'SPAM',
};

class VerifiedService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'token';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }
}

class HistoryApi {
  static const String baseUrl = 'https://foodbridge1.onrender.com';

  static Future<Map<String, dynamic>?> getPost({
    required String token,
    required int postId,
  }) async {
    final url = Uri.parse('$baseUrl/posts/$postId');
    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is Map && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      return data as Map<String, dynamic>;
    } else {
      debugPrint('getPost error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getBooking({
    required String token,
    required int bookingId,
  }) async {
    final url = Uri.parse('$baseUrl/bookings/$bookingId');
    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    // เคส render db full
    if (res.statusCode == 404 &&
        res.body.contains('remaining connection slots are reserved')) {
      debugPrint('getBooking → DB full, return null');
      return null;
    }

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is Map && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      if (data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } else {
      debugPrint('getBooking error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  static Future<String?> getBookingQr({
    required String token,
    required int bookingId,
  }) async {
    final url = Uri.parse('$baseUrl/bookings/$bookingId/qr');
    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is Map && data['token'] != null) {
        return data['token'].toString();
      }
      return null;
    } else {
      debugPrint('getBookingQr error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  static Future<bool> cancelBooking({
    required String token,
    required int bookingId,
  }) async {
    final url = Uri.parse('$baseUrl/bookings/$bookingId');
    final res = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "status": "CANCELLED",
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      return true;
    }

    debugPrint('cancelBooking error: ${res.statusCode} ${res.body}');
    return false;
  }

  // ไว้ให้หน้า report ใช้
  static Future<bool> sendReport({
    required String token,
    required Map<String, dynamic> body,
    int? postId,
    int? bookingId,
  }) async {
    Uri url;
    if (postId != null) {
      url = Uri.parse('$baseUrl/posts/$postId/reports');
    } else if (bookingId != null) {
      url = Uri.parse('$baseUrl/bookings/$bookingId/reports');
    } else {
      url = Uri.parse('$baseUrl/reports');
    }

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 ||
        res.statusCode == 201 ||
        res.statusCode == 204) {
      return true;
    } else {
      debugPrint('sendReport error: ${res.statusCode} ${res.body}');
      return false;
    }
  }
}

class ShowHistoryDetailPage extends StatefulWidget {
  final int? postId;
  final int? bookingId;

  final bool? isGiveaway;
  final String? createdAtIso;
  final num? price;
  final String? address;
  final String? orderCode;

  const ShowHistoryDetailPage({
    super.key,
    this.postId,
    this.bookingId,
    this.isGiveaway,
    this.createdAtIso,
    this.price,
    this.address,
    this.orderCode,
  });

  @override
  State<ShowHistoryDetailPage> createState() => _ShowHistoryDetailPageState();
}

class _ShowHistoryDetailPageState extends State<ShowHistoryDetailPage> {
  bool _loading = true;
  bool _cancelling = false;
  String? _error;

  Map<String, dynamic>? _post;
  Map<String, dynamic>? _booking;
  String? _qrTokenFromApi;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final token = await VerifiedService.getToken();
      if (token == null) {
        setState(() {
          _error = 'ยังไม่ได้ล็อกอิน';
          _loading = false;
        });
        return;
      }

      Map<String, dynamic>? booking;
      Map<String, dynamic>? post;
      String? qrToken;

      // 1) ดึง booking
      if (widget.bookingId != null) {
        booking = await HistoryApi.getBooking(
          token: token,
          bookingId: widget.bookingId!,
        ).catchError((_) => null);

        final existingQr = booking?['qr_token']?.toString();
        if (existingQr != null && existingQr.isNotEmpty) {
          qrToken = existingQr;
        } else {
          // ขอใหม่จาก /bookings/:id/qr
          qrToken = await HistoryApi.getBookingQr(
            token: token,
            bookingId: widget.bookingId!,
          );
        }
      }

      // 2) ดึง post ถ้ารู้ postId
      if (widget.postId != null) {
        post = await HistoryApi.getPost(
          token: token,
          postId: widget.postId!,
        );
      }

      // 3) ถ้ายังไม่มี post แต่ booking มี post_id
      if (post == null && booking != null && booking['post_id'] != null) {
        final pid = booking['post_id'];
        post = await HistoryApi.getPost(
          token: token,
          postId: pid is int ? pid : int.parse(pid.toString()),
        );
      }

      setState(() {
        _booking = booking;
        _post = post;
        _qrTokenFromApi = qrToken;
        _loading = false;
        _cancelling = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  
void _goToReportPage() {
  // 1) ลองเอาจากโพสต์ที่โหลดมา
  dynamic rawPostId = _post?['id'] ?? _post?['post_id'];

  // 2) ถ้ายังไม่มี ลองเอาจาก booking (บาง backend ส่งเป็น post_id ใน booking)
  if (rawPostId == null) {
    rawPostId = _booking?['post_id'];
  }

  // 3) ถ้ายังไม่มีอีก ลองเอาจากตัวที่ส่งมาตอนเปิดหน้านี้
  if (rawPostId == null) {
    rawPostId = widget.postId;
  }

  // แปลงให้เป็น int
  int? finalPostId;
  if (rawPostId is int) {
    finalPostId = rawPostId;
  } else if (rawPostId is String) {
    finalPostId = int.tryParse(rawPostId);
  }

  if (finalPostId == null) {
    // กรณีไม่มีจริงๆ
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ไม่พบโพสต์ที่จะรายงาน')),
    );
    return;
  }

  // 4) ส่งไปหน้า report ด้วย postId ตัวเดียว
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReportPage(postId: finalPostId!),
    ),
  );
}


  // ---------- utils ----------
  String _buildOrderCode({
    required DateTime createdAt,
    required bool isGiveaway,
    required int runningNumber,
  }) {
    final type = isGiveaway ? 'GV' : 'FS';
    final yy = (createdAt.year % 100).toString().padLeft(2, '0');
    final mm = createdAt.month.toString().padLeft(2, '0');
    final dd = createdAt.day.toString().padLeft(2, '0');
    final datePart = '$yy$mm$dd';
    final runPart = runningNumber.toString().padLeft(5, '0');
    return '$type-$datePart-$runPart';
  }

  String _formatThai(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
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
      final m = thMonths[dt.month - 1];
      final y = dt.year % 100;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$day $m $y, $hh:$mm';
    } catch (_) {
      return iso;
    }
  }

  String _formatTimeOnly(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm น.';
    } catch (_) {
      return '-';
    }
  }

  String _getExpireIsoOrPlus30({
    required String? expireAtIso,
    required String? createdAtIso,
  }) {
    if (expireAtIso != null && expireAtIso.isNotEmpty) {
      return expireAtIso;
    }

    if (createdAtIso != null && createdAtIso.isNotEmpty) {
      try {
        final base = DateTime.parse(createdAtIso).toLocal();
        final plus30 = base.add(const Duration(minutes: 30));
        return plus30.toUtc().toIso8601String();
      } catch (_) {}
    }

    final nowPlus30 = DateTime.now().add(const Duration(minutes: 30));
    return nowPlus30.toUtc().toIso8601String();
  }

  bool _isQrExpired(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    try {
      final exp = DateTime.parse(iso).toLocal();
      return DateTime.now().isAfter(exp);
    } catch (_) {
      return false;
    }
  }

  String _formatRemain(String expireIso) {
    try {
      final exp = DateTime.parse(expireIso).toLocal();
      final now = DateTime.now();
      final diff = exp.difference(now);
      if (diff.isNegative) return '00:00:00';
      final hh = diff.inHours.toString().padLeft(2, '0');
      final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    } catch (_) {
      return '00:00:00';
    }
  }

  String _formatPickupFull(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
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
      final m = thMonths[dt.month - 1];
      final y = dt.year % 100;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return 'สามารถรับอาหารได้ถึง \nวันที่ $day $m $y เวลา $hh:$mm น.';
    } catch (_) {
      return 'สามารถรับอาหารได้ถึง -';
    }
  }

  Future<void> _handleCancel(int bookingId) async {
    setState(() {
      _cancelling = true;
    });

    final token = await VerifiedService.getToken();
    if (token == null) {
      setState(() {
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่ได้ล็อกอิน')),
      );
      return;
    }

    debugPrint('👉 PATCH cancel booking_id=$bookingId');

    final ok = await HistoryApi.cancelBooking(
      token: token,
      bookingId: bookingId,
    );

    if (!mounted) return;

    if (ok) {
      await _loadDetail();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกรายการแล้ว')),
      );
    } else {
      setState(() {
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถยกเลิกได้')),
      );
    }
  }

  // ---------- ปุ่มสไตล์ ----------
  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xffF4F4F4)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xffED1429),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    final isLoading = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xffED1429),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffED1429).withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appbar แบบ commu
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
          'รายละเอียดรายการ',
          style: TextStyle(
            color: Color(0xff2A2929),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final post = _post;
    final booking = _booking;

    final String? createdAtIso = widget.createdAtIso ??
        booking?['created_at']?.toString() ??
        post?['created_at']?.toString();

    final String? rawExpireAtIso = booking?['expire_at']?.toString();
    final String finalExpireAtIso = _getExpireIsoOrPlus30(
      expireAtIso: rawExpireAtIso,
      createdAtIso: createdAtIso,
    );

    final String pickupTime = _formatTimeOnly(finalExpireAtIso);
    final String createdAtDisplay = _formatThai(createdAtIso);
    final String pickupFullText = _formatPickupFull(finalExpireAtIso);
    final String remainText = _formatRemain(finalExpireAtIso);

    final bool isGiveaway = widget.isGiveaway ??
        (post?['is_giveaway'] == true) ||
        (post?['is_giveaway']?.toString() == 'true');

    final price = widget.price ?? post?['price'];
    final address = widget.address ?? post?['address'] ?? '-';

    final int? finalBookingId = widget.bookingId ??
        (booking != null && booking['booking_id'] != null
            ? (booking['booking_id'] is int
                ? booking['booking_id']
                : int.tryParse(booking['booking_id'].toString()))
            : null);

    final DateTime createdAtForCode = (() {
      try {
        return DateTime.parse(createdAtIso ?? '').toLocal();
      } catch (_) {
        return DateTime.now();
      }
    })();

    final String orderCode = widget.orderCode ??
        _buildOrderCode(
          createdAt: createdAtForCode,
          isGiveaway: isGiveaway,
          runningNumber: finalBookingId ?? 1,
        );

    final String? qrToken = _qrTokenFromApi ?? booking?['qr_token']?.toString();
    final bool qrReallyExpired = _isQrExpired(finalExpireAtIso);

    final String rawStatus = booking?['status']?.toString() ?? '-';
    String textStatus;
    Color statusColor;
    switch (rawStatus) {
      case 'QUEUED':
        textStatus = 'กำลังรอคิว';
        statusColor = const Color(0xffF58319);
        break;
      case 'PENDING':
        textStatus = 'กำลังดำเนินการ';
        statusColor = const Color(0xffF58319);
        break;
      case 'COMPLETED':
        textStatus = 'รายการสำเร็จแล้ว';
        statusColor = const Color(0xff038263);
        break;
      case 'CANCELLED':
        textStatus = 'ยกเลิกรายการแล้ว';
        statusColor = const Color(0xffED1429);
        break;
      case 'EXPIRED':
        textStatus = 'รายการหมดเวลาแล้ว';
        statusColor = const Color(0xffED1429);
        break;
      default:
        textStatus = rawStatus;
        statusColor = const Color(0xff2A2929);
    }

    final bool canCancel = rawStatus == 'QUEUED' || rawStatus == 'PENDING';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GREEN HEADER
          Container(
            width: double.infinity,
            color: const Color(0xff038263),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "หมายเลขรายการ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  orderCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // TITLE + TIME
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post != null && post['title'] != null) ...[
                  Text(
                    post['title'].toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff2A2929),
                    ),
                  ),
                ],
                Text(
                  createdAtDisplay,
                  style: const TextStyle(color: Color(0xff2A2929)),
                ),
              ],
            ),
          ),

          const Divider(),

          // LIST
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รายการ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff2A2929),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xffF58319),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '1',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffED1429),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ((post?['categories']) is List)
                            ? (post!['categories'] as List)
                                .map((e) => e.toString())
                                .join(', ')
                            : (post?['categories']?.toString() ?? '-'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xff2A2929),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isGiveaway)
                      const Text(
                        'ฟรี',
                        style: TextStyle(color: Color(0xffED1429)),
                      )
                    else
                      Text(
                        price != null ? '$price฿' : 'ไม่พบราคา',
                        style: const TextStyle(color: Color(0xffED1429)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // PICKUP
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'การรับสินค้า',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff2A2929),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "คุณต้องมารับสินค้าด้วยตัวเองในเวลา ",
                        style: TextStyle(color: Color(0xff2A2929)),
                      ),
                    ),
                    Text(
                      _formatTimeOnly(finalExpireAtIso),
                      style: const TextStyle(color: Color(0xff2A2929)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                        style: const TextStyle(color: Color(0xff2A2929)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const Divider(),

          // STATUS
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'สถานะการทำรายการของคุณ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff2A2929),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        textStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // QR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'โปรดแสดง QR Code\nให้กับผู้แจกภายในเวลา',
                    style: TextStyle(
                      color: Color(0xffED1429),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (qrToken != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrToken,
                        version: QrVersions.auto,
                        size: 260,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (qrReallyExpired)
                      const Text(
                        'QR Code\nหมดอายุแล้ว',
                        style: TextStyle(
                          color: Color(0xffED1429),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ] else ...[
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        qrReallyExpired
                            ? 'QR Code หมดอายุแล้ว'
                            : 'ยังไม่มี QR Code',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!qrReallyExpired)
                      const Text(
                        'ระบบยังไม่ส่ง QR มา',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'เหลือเวลาอีก',
                    style: TextStyle(
                      color: Color(0xff2A2929),
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    remainText,
                    style: const TextStyle(
                      color: Color(0xffED1429),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pickupFullText,
                    style: const TextStyle(
                      color: Color(0xff2A2929),
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const Divider(),

          // HOW TO
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'วิธีการรับสินค้า',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff2A2929),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '1. แสดง QR Code ให้แก่เจ้าของโพสต์\n'
                  '2. Scan QR Code ที่ปรากฏในหน้าจอของคุณ\n'
                  '3. ทำรายการเสร็จสิ้น',
                  style: TextStyle(color: Color(0xff2A2929)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // BOTTOM BUTTONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Builder(
              builder: (context) {
                if (canCancel) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryButton(
                          label: 'รายงานปัญหา',
                          onTap: _goToReportPage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPrimaryButton(
                          label: 'ยกเลิกรายการ',
                          onTap: (_cancelling || finalBookingId == null)
                              ? null
                              : () => _handleCancel(finalBookingId),
                        ),
                      ),
                    ],
                  );
                } else {
                  return _buildSecondaryButton(
                    label: 'รายงานปัญหา',
                    onTap: _goToReportPage,
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
 