import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'vertify_id_page.dart';
import 'login_page.dart'; // 👈 import your login page

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('https://foodbridge1.onrender.com/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        userData = data;
      });
    } else {
      print('Failed to load user: ${response.statusCode}');
    }
  }

  Future<void> _logout() async {
    await _storage.deleteAll(); // 💥 clear everything

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false, // remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userData?['full_name'] ?? 'ผู้ใช้งาน';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'การตั้งค่า',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              CircleAvatar(
                radius: 90,
                backgroundColor: Colors.grey[200],
                backgroundImage: (userData?['avatar_url'] != null
                    ? NetworkImage(userData!['avatar_url'])
                    : null) as ImageProvider<Object>?,
                child: userData?['avatar_url'] == null
                    ? SvgPicture.asset(
                        'assets/icons/no_profile.svg',
                        width: 180,
                        height: 180,
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (userData?['is_vertify'] == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.verified,
                        color: Colors.orange,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ผู้ใช้งาน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              _settingTile(context, 'แก้ไขโปรไฟล์', onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()));
              }),
              _settingTile(context, 'ตั้งค่ารหัสผ่าน', onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage()));
              }),
              _settingTile(context, 'การยืนยันตัวตน', onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const VerifyIDPage()));
              }),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'การแจ้งเตือน',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color.fromRGBO(237, 236, 236, 1),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  title: const Text(
                    'Push Notification',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  ),
                  activeColor: const Color.fromARGB(255, 245, 131, 25),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'อื่น ๆ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              _settingTile(
                context,
                'ออกจากระบบ',
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('ยืนยันการออกจากระบบ'),
                      content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('ยกเลิก'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('ออกจากระบบ'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    _logout();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingTile(BuildContext context, String title,
      {VoidCallback? onTap}) {
    return Card(
      color: const Color.fromRGBO(237, 236, 236, 1),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
