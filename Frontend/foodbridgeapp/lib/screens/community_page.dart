// community_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

// ถ้ามี bottom nav ของโปรเจกต์ ให้ import ด้วย (ไม่มีก็ลบออก)
// import 'nav_bar.dart';

/// ===================================================================
/// 1) SERVICE สำหรับ token + /me
/// ===================================================================
class VerifiedService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'token';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

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

/// ===================================================================
/// 2) API SERVICE (posts / likes / comments / upload / bundle)
/// ===================================================================
class ApiService {
  static const String baseUrl = 'https://foodbridge1.onrender.com';

  /// โหลดโพสต์ทั้งหมดแล้วกรองเฉพาะ COMMUNITY
  static Future<List<Map<String, dynamic>>> getCommunityPosts(
    String token,
  ) async {
    final url = Uri.parse('$baseUrl/posts');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = (data['items'] as List?) ?? [];
      return items
          .where((e) =>
              (e['post_type'] ?? '').toString().toUpperCase() == 'COMMUNITY')
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      debugPrint('getCommunityPosts error: ${res.statusCode} ${res.body}');
      return [];
    }
  }

  /// สร้างโพสต์ COMMUNITY (description บังคับ, images ไม่บังคับ)
  static Future<bool> createCommunityPost({
    required String token,
    required String description,
    String? imageUrl,
  }) async {
    final url = Uri.parse('$baseUrl/posts');

    final bodyMap = {
      "post_type": "COMMUNITY",
      "title": "-",
      "description": description,
      "categories": ["ของคาว"],
      "images": (imageUrl != null && imageUrl.trim().isNotEmpty)
          ? [imageUrl.trim()]
          : <String>[],
    };

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(bodyMap),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return true;
    } else {
      debugPrint('createCommunityPost error: ${res.statusCode} ${res.body}');
      return false;
    }
  }

  /// อัปโหลดรูป: เปลี่ยน path/field ให้ตรง backend
  /// - สมมติ backend: POST /upload  -> { "url": "https://..." }
  /// - ชื่อฟิลด์ไฟล์: "file"
  static Future<String?> uploadImage({
    required String token,
    required File file,
  }) async {
    final uri = Uri.parse('$baseUrl/upload'); // <- แก้ให้ตรง backend

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      if (data is Map && data['url'] != null) {
        return data['url'].toString();
      }
      if (data is Map &&
          data['data'] is Map &&
          data['data']['url'] != null) {
        return data['data']['url'].toString();
      }
    } else {
      debugPrint('uploadImage error: ${res.statusCode} ${res.body}');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUser(
    String token,
    int userId,
  ) async {
    final url = Uri.parse('$baseUrl/users/$userId');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } else {
      debugPrint('getUser error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPostLikes(
    String token,
    int postId,
  ) async {
    final url = Uri.parse('$baseUrl/posts/$postId/likes');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : null;
    } else {
      debugPrint('getPostLikes error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPostComments(
    String token,
    int postId,
  ) async {
    final url =
        Uri.parse('$baseUrl/posts/$postId/comments?include_children=true');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : null;
    } else {
      debugPrint('getPostComments error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  static Future<bool> createComment({
    required String token,
    required int postId,
    required String body,
    int? parentId,
  }) async {
    final url = Uri.parse('$baseUrl/posts/$postId/comments');

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'body': body,
        'parent_id': parentId,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return true;
    } else {
      debugPrint('createComment error: ${res.statusCode} ${res.body}');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> toggleLike({
    required String token,
    required int postId,
  }) async {
    final url = Uri.parse('$baseUrl/posts/$postId/like');

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data is Map<String, dynamic> ? data : null;
    } else {
      debugPrint('toggleLike error: ${res.statusCode} ${res.body}');
      return null;
    }
  }

  /// รวมชิ้นส่วนของโพสต์เดียว (owner / likes / comments + enrich user)
  static Future<Map<String, dynamic>> getFullPostBundle({
    required String token,
    required Map<String, dynamic> post,
  }) async {
    final int postId = post['post_id'] as int;
    final int providerId = post['provider_id'] as int;

    final results = await Future.wait([
      getUser(token, providerId),
      getPostLikes(token, postId),
      getPostComments(token, postId),
    ]);

    final Map<String, dynamic> owner =
        (results[0] as Map<String, dynamic>?) ?? {};
    final Map<String, dynamic> likes =
        (results[1] as Map<String, dynamic>?) ?? {};
    final Map<String, dynamic>? commentsResp =
        results[2] as Map<String, dynamic>?;

    final List<dynamic> commentsRaw =
        (commentsResp?['comments'] as List?) ?? [];

    final List<int> commenterIds = [];
    for (final c in commentsRaw) {
      if (c is Map && c['user_id'] != null) {
        final int uid = c['user_id'] as int;
        if (!commenterIds.contains(uid)) commenterIds.add(uid);
      }
    }

    final List<Future<Map<String, dynamic>?>> userJobs =
        commenterIds.map((uid) => getUser(token, uid)).toList();
    final List<Map<String, dynamic>?> userResults = await Future.wait(userJobs);

    final Map<int, Map<String, dynamic>> commentUsersById = {};
    for (int i = 0; i < commenterIds.length; i++) {
      final uid = commenterIds[i];
      final user = userResults[i];
      if (user != null) commentUsersById[uid] = user;
    }

    final List<Map<String, dynamic>> commentsEnriched =
        commentsRaw.map<Map<String, dynamic>>((c) {
      final m = Map<String, dynamic>.from(c as Map);
      final uid = m['user_id'];
      if (uid is int && commentUsersById.containsKey(uid)) {
        m['user'] = commentUsersById[uid];
      }
      return m;
    }).toList();

    return {
      'post': post,
      'owner': owner,
      'likes': likes,
      'comments': commentsEnriched,
    };
  }

  /// ดึงฟีด + enrich (owner / like_count / comment_count / user_ids ที่ไลก์)
  static Future<List<Map<String, dynamic>>> getCommunityFeedWithExtras(
    String token,
  ) async {
    final posts = await getCommunityPosts(token);
    final List<Future<Map<String, dynamic>>> jobs = [];
    for (final post in posts) {
      jobs.add(_enrichPostWithExtras(token, post));
    }
    return await Future.wait(jobs);
  }

  static Future<Map<String, dynamic>> _enrichPostWithExtras(
    String token,
    Map<String, dynamic> post,
  ) async {
    final int postId = post['post_id'] as int;
    final int providerId = post['provider_id'] as int;

    final results = await Future.wait([
      getUser(token, providerId),
      getPostLikes(token, postId),
      getPostComments(token, postId),
    ]);

    final Map<String, dynamic> owner =
        (results[0] as Map<String, dynamic>?) ?? {};
    final Map<String, dynamic> likes =
        (results[1] as Map<String, dynamic>?) ?? {};
    final Map<String, dynamic>? commentsResp =
        results[2] as Map<String, dynamic>?;

    final int commentCount =
        ((commentsResp?['comments'] as List?) ?? []).length;

    final List<dynamic> likedUserIds =
        (likes['user_ids'] is List) ? likes['user_ids'] as List : [];

    return {
      'post': post,
      'owner': owner,
      'like_count': (likes['like_count'] ?? 0) as int,
      'comment_count': commentCount,
      'liked_user_ids': likedUserIds,
    };
  }
}

/// ===================================================================
/// 3) POST DETAIL PAGE (มี like + comment + ส่งค่ากลับ + back แบบ commu)
/// ===================================================================
class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String token;
  final Map<String, dynamic>? currentUser;

  const PostDetailPage({
    super.key,
    required this.post,
    required this.token,
    required this.currentUser,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<Map<String, dynamic>> _future;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSending = false;

  int _likeCount = 0;
  bool _likedByMe = false;
  bool _modified = false;

  @override
  void initState() {
    super.initState();
    _future = _loadBundle();
  }

  Future<Map<String, dynamic>> _loadBundle() async {
    final bundle = await ApiService.getFullPostBundle(
      token: widget.token,
      post: widget.post,
    );

    final meId = widget.currentUser?['user_id'];
    final Map<String, dynamic> likes =
        (bundle['likes'] as Map<String, dynamic>?) ?? {};
    final int likeCount = (likes['like_count'] ?? 0) as int;
    final List likedUserIds =
        (likes['user_ids'] is List) ? likes['user_ids'] as List : [];

    bool likedByMe = false;
    if (meId != null) likedByMe = likedUserIds.contains(meId);

    _likeCount = likeCount;
    _likedByMe = likedByMe;

    return bundle;
  }

  Widget _postImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(path, width: double.infinity, height: 200, fit: BoxFit.cover);
    }
    return Image.asset(path, width: double.infinity, height: 200, fit: BoxFit.cover);
  }

  String _formatIso(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const thMonths = [
        'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
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

  Widget _meAvatar() {
    final me = widget.currentUser;
    if (me == null) {
      return const CircleAvatar(
        backgroundImage: AssetImage('assets/images/profile1.png'),
        radius: 20,
      );
    }
    final avatarUrl = me['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      return CircleAvatar(backgroundImage: NetworkImage(avatarUrl), radius: 20);
    }
    return const CircleAvatar(
      backgroundImage: AssetImage('assets/images/profile1.png'),
      radius: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _modified);
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('โหลดโพสต์ไม่สำเร็จ'));
              }

              final bundle = snapshot.data!;
              final post = bundle['post'] as Map<String, dynamic>;
              final Map<String, dynamic> owner =
                  (bundle['owner'] as Map<String, dynamic>?) ?? {};
              final List comments =
                  (bundle['comments'] as List?) ?? <dynamic>[];

              final List images = (post['images'] as List?) ?? [];
              final String? firstImage =
                  images.isNotEmpty ? images.first.toString() : null;

              final String displayName =
                  (owner['display_name'] ??
                          owner['full_name'] ??
                          'ผู้ใช้หมายเลข ${post['provider_id']}')
                      .toString();

              final String? avatarUrl = owner['avatar_url'] as String?;
              final Widget avatarWidget = (avatarUrl != null &&
                      avatarUrl.isNotEmpty &&
                      avatarUrl.startsWith('http'))
                  ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl), radius: 25)
                  : const CircleAvatar(
                      backgroundImage: AssetImage('assets/images/profile1.png'),
                      radius: 25,
                    );

              final createdAt = post['created_at'];
              String createdAtStr = '';
              if (createdAt is int) {
                final dt = DateTime.fromMillisecondsSinceEpoch(
                  createdAt * 1000,
                  isUtc: true,
                ).toLocal();
                createdAtStr =
                    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER: back เหมือน commu page
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context, _modified),
                          child: SvgPicture.asset(
                            'assets/icons/back_arrow.svg',
                            width: 24,
                            height: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'โพสต์',
                          style: TextStyle(
                            color: Color(0xff2A2929),
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // owner + เวลา + ปุ่มไลก์
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        avatarWidget,
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xff038263),
                              ),
                            ),
                            Text(
                              createdAtStr,
                              style: const TextStyle(
                                color: Color(0xFFF58319),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () async {
                            final res = await ApiService.toggleLike(
                              token: widget.token,
                              postId: post['post_id'] as int,
                            );
                            if (res != null) {
                              final likedNow = res['liked'] == true;
                              final int likeCountNow =
                                  (res['like_count'] ?? 0) as int;
                              setState(() {
                                _likedByMe = likedNow;
                                _likeCount = likeCountNow;
                                _modified = true;
                              });
                            }
                          },
                          icon: Icon(
                            _likedByMe ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                            size: 27,
                          ),
                        ),
                        Text(_likeCount.toString()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // caption
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      post['description'] ?? '',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),

                  // รูป (ถ้ามี)
                  if (firstImage != null && firstImage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _postImage(firstImage),
                      ),
                    ),

                  // กล่องคอมเมนต์
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _meAvatar(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            decoration: InputDecoration(
                              hintText: 'แสดงความคิดเห็นของคุณ...',
                              filled: true,
                              fillColor: const Color(0xFFF2F2F2),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          onPressed: _isSending
                              ? null
                              : () async {
                                  final text = _commentCtrl.text.trim();
                                  if (text.isEmpty) return;

                                  setState(() => _isSending = true);

                                  final ok = await ApiService.createComment(
                                    token: widget.token,
                                    postId: post['post_id'] as int,
                                    body: text,
                                  );

                                  if (ok) {
                                    _commentCtrl.clear();
                                    setState(() {
                                      _future = _loadBundle();
                                      _modified = true;
                                    });
                                  }
                                  setState(() => _isSending = false);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // รายการคอมเมนต์
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index] as Map<String, dynamic>;
                        final body = c['body']?.toString() ?? '';
                        final userId = c['user_id'];
                        final created = c['created_at']?.toString();
                        final Map<String, dynamic>? commentUser =
                            c['user'] as Map<String, dynamic>?;

                        final String cDisplayName =
                            (commentUser?['display_name'] ??
                                    commentUser?['full_name'] ??
                                    'user #$userId')
                                .toString();

                        final String? commentAvatar =
                            commentUser?['avatar_url'] as String?;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (commentAvatar != null &&
                                  commentAvatar.isNotEmpty &&
                                  commentAvatar.startsWith('http'))
                                CircleAvatar(
                                  backgroundImage: NetworkImage(commentAvatar),
                                  radius: 18,
                                )
                              else
                                const CircleAvatar(
                                  backgroundImage:
                                      AssetImage('assets/images/profile1.png'),
                                  radius: 18,
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cDisplayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (created != null)
                                      Text(
                                        _formatIso(created),
                                        style: const TextStyle(
                                          color: Color(0xFFF58319),
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF2F2F2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(body),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ===================================================================
/// 4) COMMUNITY PAGE (ฟีด + สร้างโพสต์ด้วยอัปโหลดรูป)
/// ===================================================================
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String? _token;
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _feed = [];
  bool _isLoading = true;
  String? _error;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final token = await VerifiedService.getToken();
      if (token == null) {
        setState(() {
          _error = 'ยังไม่ได้ล็อกอิน';
          _isLoading = false;
        });
        return;
      }

      final me = await VerifiedService.getCurrentUser();
      final feed = await ApiService.getCommunityFeedWithExtras(token);

      setState(() {
        _token = token;
        _me = me;
        _feed = feed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatFromUnix(dynamic v) {
    if (v == null) return '';
    try {
      final dt =
          DateTime.fromMillisecondsSinceEpoch((v as int) * 1000, isUtc: true)
              .toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _meAvatar(Map<String, dynamic>? me) {
    if (me == null) {
      return const CircleAvatar(
        backgroundImage: AssetImage('assets/images/profile1.png'),
        radius: 25,
      );
    }
    final avatarUrl = me['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      return CircleAvatar(backgroundImage: NetworkImage(avatarUrl), radius: 25);
    }
    return const CircleAvatar(
      backgroundImage: AssetImage('assets/images/profile1.png'),
      radius: 25,
    );
  }

  String _likeText(int likeCount) => likeCount.toString();

  /// Dialog สร้างโพสต์ (อัปโหลดรูปแทนพิมพ์ลิงก์)
  Future<void> _showCreatePostDialog() async {
    if (_token == null) return;

    final descCtrl = TextEditingController();
    File? pickedImageFile;
    bool posting = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  _meAvatar(_me),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _me?['display_name']?.toString() ?? 'โพสต์ใหม่',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'เขียนอะไรสักหน่อย...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: posting
                          ? null
                          : () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  pickedImageFile = File(picked.path);
                                });
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xffF2F2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pickedImageFile != null
                                    ? 'เลือกรูปแล้ว: ${pickedImageFile!.path.split('/').last}'
                                    : 'เลือกรูปจากเครื่อง (ไม่บังคับ)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (pickedImageFile != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          pickedImageFile!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: posting ? null : () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: posting
                      ? null
                      : () async {
                          final desc = descCtrl.text.trim();
                          if (desc.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('กรุณาพิมพ์ข้อความก่อน')),
                            );
                            return;
                          }

                          setStateDialog(() => posting = true);

                          String? imageUrl;
                          if (pickedImageFile != null) {
                            imageUrl = await ApiService.uploadImage(
                              token: _token!,
                              file: pickedImageFile!,
                            );
                          }

                          final ok = await ApiService.createCommunityPost(
                            token: _token!,
                            description: desc,
                            imageUrl: imageUrl,
                          );

                          setStateDialog(() => posting = false);

                          if (ok) {
                            Navigator.pop(ctx);
                            await _loadAll();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('โพสต์ไม่สำเร็จ')),
                            );
                          }
                        },
                  child: posting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('โพสต์'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    final token = _token!;
    final me = _me;

    return Scaffold(
      // ถ้ามี bottom nav ของโปรเจกต์ ให้ปลดบรรทัดนี้
      // bottomNavigationBar: NavBar(),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // กล่องเขียนโพสต์ใหม่ (กดแล้วเปิด dialog)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _showCreatePostDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    _meAvatar(me),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        me?['display_name'] != null
                            ? 'โพสต์อะไรหน่อยไหม ${me!['display_name']}'
                            : 'เกิดอะไรขึ้น?',
                        style: const TextStyle(color: Color(0xff828282), fontSize: 16),
                      ),
                    ),
                    const Icon(Icons.edit, color: Color(0xff828282)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // FEED
          Expanded(
            child: ListView.separated(
              itemCount: _feed.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
              itemBuilder: (context, index) {
                final item = _feed[index];
                final Map<String, dynamic> post = item['post'] as Map<String, dynamic>;
                final Map<String, dynamic> owner =
                    (item['owner'] as Map<String, dynamic>?) ?? {};

                final int likeCount = item['like_count'] as int? ?? 0;
                final int commentCount = item['comment_count'] as int? ?? 0;

                final List likedUserIds =
                    item['liked_user_ids'] is List ? item['liked_user_ids'] : [];

                final meId = me?['user_id'];
                final bool likedByMe = meId != null ? likedUserIds.contains(meId) : false;

                final String displayName =
                    (owner['display_name'] ??
                            owner['full_name'] ??
                            'ผู้ใช้หมายเลข ${post['provider_id']}')
                        .toString();

                final String? avatarUrl = owner['avatar_url'] as String?;
                final Widget avatarWidget = (avatarUrl != null &&
                        avatarUrl.isNotEmpty &&
                        avatarUrl.startsWith('http'))
                    ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl), radius: 25)
                    : const CircleAvatar(
                        backgroundImage: AssetImage('assets/images/profile1.png'),
                        radius: 25,
                      );

                final createdAtStr = _formatFromUnix(post['created_at']);
                final List images = (post['images'] as List?) ?? [];
                final String? firstImage =
                    images.isNotEmpty ? images.first.toString() : null;

                return InkWell(
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailPage(
                          post: post,
                          token: token,
                          currentUser: me,
                        ),
                      ),
                    );
                    if (changed == true) {
                      await _loadAll();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: avatarWidget,
                          title: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xff038263),
                            ),
                          ),
                          subtitle: Text(
                            createdAtStr,
                            style: const TextStyle(color: Color(0xFFF58319)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            post['description'] ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (firstImage != null && firstImage.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                firstImage,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final res = await ApiService.toggleLike(
                                    token: token,
                                    postId: post['post_id'] as int,
                                  );
                                  if (res != null) {
                                    final bool likedNow = res['liked'] == true;
                                    final int likeCountNow =
                                        (res['like_count'] ?? 0) as int;

                                    setState(() {
                                      _feed[index]['like_count'] = likeCountNow;
                                      final meId = me?['user_id'];
                                      List newLikedIds =
                                          List.from(_feed[index]['liked_user_ids'] ?? <int>[]);
                                      if (meId != null) {
                                        if (likedNow) {
                                          if (!newLikedIds.contains(meId)) {
                                            newLikedIds.add(meId);
                                          }
                                        } else {
                                          newLikedIds.remove(meId);
                                        }
                                      }
                                      _feed[index]['liked_user_ids'] = newLikedIds;
                                    });
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      likedByMe ? Icons.favorite : Icons.favorite_border,
                                      color: Colors.red,
                                      size: 27,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(_likeText(likeCount)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/comment.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$commentCount'),
                                ],
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
        ],
      ),
    );
  }
}
