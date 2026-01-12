import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'notification_detail_page.dart';
import 'nav_bar.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final storage = const FlutterSecureStorage();
  final Map<int, String> postTitleList = {};
  bool _isDeletingAll = false;
  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  /// Fetch notifications
  Future<List<Map<String, dynamic>>> fetchNotifications(String token) async {
    final url = Uri.parse('https://foodbridge1.onrender.com/notifications');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is Map && data['items'] is List) {
        return List<Map<String, dynamic>>.from(data['items']);
      }
    }
    return [];
  }

  /// Fetch post title for clarity
  Future<String?> fetchPostTitle(int postId, String token) async {
    if (postTitleList.containsKey(postId)) return postTitleList[postId];
    try {
      final url = Uri.parse('https://foodbridge1.onrender.com/posts/$postId');
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final title = data['title'] ?? '-';
        postTitleList[postId] = title;
        return title;
      }
    } catch (e) {
      debugPrint('fetchPostTitle error: $e');
    }
    return null;
  }

  /// Load notifications
  Future<void> loadNotifications() async {
    final token = await storage.read(key: 'token');
    // final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyMjc0MDksInJvbGUiOiJVU0VSIiwidWlkIjoyfQ.wgxcI6YlrWBQS0TILjijFUygE4X_ZTz1OcU8T632Ru0';
    if (token == null) return;

    setState(() => isLoading = true);
    try {
      postTitleList.clear();
      final fetched = await fetchNotifications(token);
      setState(() {
        notifications = fetched;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('loadNotifications error: $e');
      setState(() => isLoading = false);
    }
  }

  /// Normalize type
  String normalizeType(String type) {
    if (type.isEmpty) return 'UNKNOWN';
    if (type.contains('.')) {
      final parts = type.split('.');
      if (parts.contains('cancelled')) return 'CANCELLED';
      return parts.length > 1 ? parts[1].toUpperCase() : parts.last.toUpperCase();
    }
    return type.toUpperCase();
  }

  /// Select icon
  String iconPathForType(String type) {
    switch (type.toUpperCase()) {
      case 'CREATED':
      case 'PENDING':
        return 'assets/icons/pending.svg';
      case 'CANCELLED':
        return 'assets/icons/cancelled.svg';
      case 'COMPLETED':
        return 'assets/icons/accept.svg';
      default:
        return 'assets/icons/expired.svg';
    }
  }

  /// Format Thai date
  String formatThaiDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    final sameDay = now.year == date.year && now.month == date.month && now.day == date.day;
    if (sameDay) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) {
      const weekdays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
      return weekdays[date.weekday - 1];
    }
    const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    return '${date.day} ${months[date.month - 1]}';
  }

  /// Delete all
  Future<void> _confirmAndDeleteAll() async {
    if (_isDeletingAll) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบการแจ้งเตือนทั้งหมด?'),
        content: const Text('คุณต้องการลบการแจ้งเตือนทั้งหมดหรือไม่'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบทั้งหมด'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = await storage.read(key: 'token');
    if (token == null) return;

    setState(() => _isDeletingAll = true);
    try {
      final url = Uri.parse('https://foodbridge1.onrender.com/notifications');
      final res = await http.delete(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() => notifications.clear());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบการแจ้งเตือนทั้งหมดแล้ว')));
      }
    } finally {
      if (mounted) setState(() => _isDeletingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('การแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff2A2929))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'ลบทั้งหมด',
            onPressed: _isDeletingAll ? null : _confirmAndDeleteAll,
            icon: _isDeletingAll
                ? const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.delete, color: Colors.black54),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text('ยังไม่มีการแจ้งเตือน'))
              : ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    final int id = n['notification_id'] ?? 0;
                    final String title = (n['title'] ?? '').toString();
                    final String body = (n['body'] ?? '').toString();
                    final bool isRead = (n['is_read'] ?? false) == true;
                    final String type = normalizeType(n['type'] ?? '');
                    final DateTime createdAt = DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now();
                    final int? postId = n['data']?['post_id'];
                    final iconPath = iconPathForType(type);

                    return InkWell(
                      onTap: () async {
                        final token = await storage.read(key: 'token');
                        if (token == null) return;

                        try {
                          // Mark as read
                          final url = Uri.parse('https://foodbridge1.onrender.com/notifications/$id/read');
                          final res = await http.patch(
                            url,
                            headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json',
                            },
                          );

                          if (res.statusCode == 200 || res.statusCode == 204) {
                            setState(() {
                              notifications[i]['is_read'] = true;
                            });
                          }
                        } catch (e) {
                          debugPrint('Mark as read failed: $e');
                        }

                        final refresh = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationDetailPage(id: id, postId: postId ?? 0),
                          ),
                        );

                        if (refresh == true) {
                          loadNotifications();
                        }
                      },

                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SvgPicture.asset(iconPath, width: 36, height: 36),
                                if (!isRead)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('[${type.toUpperCase()}] $title',
                                      style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Text(body, style: const TextStyle(color: Colors.black87)),
                                  if (postId != null)
                                    FutureBuilder<String?>(
                                      future: storage.read(key: 'token').then((token) => token != null ? fetchPostTitle(postId, token) : null),
                                      builder: (context, snap) {
                                        if (snap.connectionState == ConnectionState.waiting) {
                                          return const Text('กำลังโหลดโพสต์...', style: TextStyle(fontSize: 12, color: Colors.grey));
                                        }
                                        if ((snap.data ?? '').isNotEmpty) {
                                          return Text('โพสต์: ${snap.data}', style: const TextStyle(fontSize: 12, color: Colors.black54));
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 55,
                              child: Text(formatThaiDate(createdAt),
                                  textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: const NavBar(
          currentIndex: 2,
          hasNotification: false,
        ),
    );
  }
}
