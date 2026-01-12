import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationDetailPage extends StatefulWidget {
  final int id;
  final int postId;

  const NotificationDetailPage({
    super.key,
    required this.id,
    required this.postId,
  });

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  final storage = const FlutterSecureStorage();
  Map<String, dynamic>? notificationData;
  Map<String, dynamic>? postData;
  bool isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  Future<void> loadDetails() async {
    final token = await storage.read(key: 'token');
    // final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyMjc0MDksInJvbGUiOiJVU0VSIiwidWlkIjoyfQ.wgxcI6YlrWBQS0TILjijFUygE4X_ZTz1OcU8T632Ru0';
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบ')),
        );
      }
      return;
    }

    try {
      final results = await Future.wait([
        fetchNotificationDetail(token),
        fetchPostDetail(token),
      ]);

      if (!mounted) return;
      setState(() {
        notificationData = results[0];
        postData = results[1];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> fetchNotificationDetail(String token) async {
    final url = Uri.parse('https://foodbridge1.onrender.com/notifications');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['items'] is List) {
        return (data['items'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (n) => n['notification_id'] == widget.id,
              orElse: () => {},
            );
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchPostDetail(String token) async {
    final url =
        Uri.parse('https://foodbridge1.onrender.com/posts/${widget.postId}');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return null;
  }

  Future<void> deleteNotification() async {
    if (_isDeleting) return;
    final token = await storage.read(key: 'token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนลบการแจ้งเตือน')),
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final url =
          Uri.parse('https://foodbridge1.onrender.com/notifications/${widget.id}');
      final res = await http.delete(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบการแจ้งเตือนเรียบร้อยแล้ว')),
        );
        Navigator.pop(context, true); // refresh parent
      } else {
        final body = jsonDecode(res.body);
        final msg = body['message'] ?? 'ไม่สามารถลบการแจ้งเตือนได้';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String normalizeType(String type) {
    if (type.isEmpty) return 'UNKNOWN';
    if (type.contains('.')) {
      final parts = type.split('.');
      if (parts.contains('cancelled')) return 'CANCELLED';
      return parts.length > 1 ? parts[1].toUpperCase() : parts.last.toUpperCase();
    }
    return type.toUpperCase();
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
    }
    if (value is String) {
      final dt = DateTime.tryParse(value);
      return dt?.toLocal();
    }
    return null;
  }

  String formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}, '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final n = notificationData;
    final p = postData;

    final rawType = (n?['type'] ?? '').toString();
    final type = normalizeType(rawType);
    final createdAt = parseDate(n?['created_at']);
    final expiresAt = (createdAt != null && (type == 'PENDING' || type == 'CREATED'))
        ? createdAt.add(const Duration(minutes: 30))
        : null;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 20, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            const Text(
              'การแจ้งเตือน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff2A2929),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'ลบการแจ้งเตือนนี้',
            onPressed: _isDeleting
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('ลบการแจ้งเตือนนี้?'),
                        content: const Text('คุณต้องการลบการแจ้งเตือนนี้หรือไม่'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('ยกเลิก'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('ลบ'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await deleteNotification();
                    }
                  },
            icon: _isDeleting
                ? const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.delete_outline, color: Colors.black54),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (n == null || p == null)
              ? const Center(child: Text('ไม่พบข้อมูล'))
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p['images'] != null && p['images'].isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            p['images'][0].toString(),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),

                      const SizedBox(height: 12),

                      Text(
                        '[${type}] ${p['title'] ?? '-'}',
                        style: const TextStyle(
                          color: Color(0xFF038263),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        (n['body'] ?? '').toString(),
                        style:
                            const TextStyle(fontSize: 14, color: Colors.black87),
                      ),

                      if (expiresAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'หมดเวลาถือคิว: ${formatDate(expiresAt)}',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],

                      const SizedBox(height: 18),

                      Text(
                        createdAt != null ? formatDate(createdAt) : '',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
    );
  }
}
