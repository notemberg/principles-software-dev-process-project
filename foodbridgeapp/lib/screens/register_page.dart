import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final usernameController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;

  Future<void> _register() async {
  final username = usernameController.text.trim();
  final password = passwordController.text.trim();
  final confirm = confirmPasswordController.text.trim();
  final email = emailController.text.trim();
  final phone = phoneController.text.trim();
  final fullName = "${firstNameController.text.trim()} ${lastNameController.text.trim()}";

  if (username.isEmpty ||
      firstNameController.text.isEmpty ||
      lastNameController.text.isEmpty ||
      email.isEmpty ||
      phone.isEmpty ||
      password.isEmpty ||
      confirm.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง')),
    );
    return;
  }

  if (!RegExp(r'[@]').hasMatch(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณากรอกข้อมูล email')),
    );
    return;
  }

  if (password.length < 8) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร')),
    );
    return;
  }

  if (!RegExp(r'[0-9]').hasMatch(password)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('รหัสผ่านต้องมีตัวเลขอย่างน้อย 1 ตัว')),
    );
    return;
  }

  if (password != confirm) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')),
    );
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('https://foodbridge1.onrender.com/auth/register'),
      // Uri.parse('https://10.0.0.2:1323/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "username": username,
        "phone": phone,
        "email": email, 
        "password": password,
        "full_name": fullName,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สมัครบัญชีสำเร็จ!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });

    } else if (response.statusCode == 400) {
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'เกิดข้อผิดพลาดในการสมัครบัญชี'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เกิดข้อผิดพลาด: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
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

              const Text('logo',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('ยินดีต้อนรับสู่ Food Bridge',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const Text('สโลแกน',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google signup not implemented')),
                  );
                },
                icon: SvgPicture.asset('assets/icons/google_icon.svg', height: 24),
                label: const Text('สมัครบัญชีด้วย Google',
                    style: TextStyle(color: Colors.black87)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 3,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const Divider(thickness: 1),
              const SizedBox(height: 8),
              const Text('หรือ', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 30),

              _buildTextField('ชื่อผู้ใช้', controller: usernameController),
              const SizedBox(height: 16),
              _buildTextField('อีเมล', controller: emailController),
              const SizedBox(height: 16),
              _buildTextField('ชื่อจริง', controller: firstNameController),
              const SizedBox(height: 16),
              _buildTextField('นามสกุล', controller: lastNameController),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'กรุณากรอกชื่อจริงและนามสกุลจริงตามบัตรประชาชนเท่านั้น',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField('เบอร์โทรศัพท์',
                  controller: phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  hintText: 'รหัสผ่าน',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '• ความยาวมากกว่า 8 ตัวอักษร\n• ต้องมีตัวเลข',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField('ยืนยันรหัสผ่าน',
                  controller: confirmPasswordController, obscureText: true),
              const SizedBox(height: 30),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'สมัครบัญชี',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('คุณมีบัญชีแล้วใช่หรือไม่? '),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      'เข้าสู่ระบบ',
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

  Widget _buildTextField(
    String hint, {
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
