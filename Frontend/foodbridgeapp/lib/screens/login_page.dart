import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:foodbridgeapp/screens/home_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'notification_page.dart';
import 'report_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginController = TextEditingController();    // phone หรือ email ก็ได้
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscure = true;

  Future<void> _login() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://foodbridge1.onrender.com/auth/login'),
        // Uri.parse('http://10.0.2.2:1323/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "login": login,
          "password": password,
        }),
      );

      setState(() => _isLoading = false);

      if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final token = data['token'];
      // final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyMjc0MDksInJvbGUiOiJVU0VSIiwidWlkIjoyfQ.wgxcI6YlrWBQS0TILjijFUygE4X_ZTz1OcU8T632Ru0';

      await _storage.write(key: 'token', value: token);
      print('Response body: ${res.body}');

      final profileRes = await http.get(
        Uri.parse('https://foodbridge1.onrender.com/me'),
        headers: {"Authorization": "Bearer $token"},
      );

      bool isVerified = false;
      int? userId;
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        isVerified = profileData['is_verified'] == true;
        userId = profileData['user_id'];
        print('User verified: $isVerified (ID: $userId)');

        await _storage.write(key: 'user_id', value: userId.toString());
        await _storage.write(key: 'is_verified', value: isVerified.toString());
      }
      
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        String message = 'เข้าสู่ระบบไม่สำเร็จ';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] is String) {
            message = body['message'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้: $e')),
      );
    }
  }

  void _loginWithGoogle() {
    // TODO: ใส่ Google Sign-In จริงภายหลัง
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ยังไม่รองรับ Google Login')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Logo
              const Text('logo',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Welcome text
              const Text('ยินดีต้อนรับสู่ Food Bridge',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const Text('สโลแกน',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 40),

              // Google Sign-In
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _loginWithGoogle,
                  icon: SvgPicture.asset(
                    'assets/icons/google_icon.svg',
                    height: 24,
                  ),
                  label: const Text(
                    'เข้าสู่ระบบด้วย Google',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Divider(thickness: 1),
              const SizedBox(height: 8),
              const Text('หรือ',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 30),

              // Login
              TextField(
                controller: _loginController,
                decoration: InputDecoration(
                  hintText: 'ชื่อผู้ใช้',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'รหัสผ่าน',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Sign up link
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ไม่มีบัญชีผู้ใช้ใช่หรือไม่? '),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const Text(
                        'สมัครเลย',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'เข้าสู่ระบบ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Forgot password
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Text('คุณลืมรหัสผ่านใช่หรือไม่? '),
                  TextButton(
                    onPressed: () {
                      // TODO: ลืมรหัสผ่าน
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ReportPage(postId: 6,)),
                              // builder: (context) => const NotificationPage()) ,
                        );
                    },
                    child: const Text(
                      'ลืมรหัสผ่าน',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
