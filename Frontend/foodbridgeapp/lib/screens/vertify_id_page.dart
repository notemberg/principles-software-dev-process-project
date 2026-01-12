import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'vertify_success_page.dart';
import 'dart:convert';
import 'dart:io';

class VerifyIDPage extends StatefulWidget {
  const VerifyIDPage({super.key});

  @override
  State<VerifyIDPage> createState() => _VerifyIDPageState();
}

class _VerifyIDPageState extends State<VerifyIDPage> {
  File? _image;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  void _submit() async {
    try {
      final _storage = const FlutterSecureStorage();
      final token = await _storage.read(key: 'token');
      if (token == null) return;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://foodbridge1.onrender.com/me/uploads/images'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Attach the file
      request.files.add(await http.MultipartFile.fromPath(
        'file', // this key should match what your backend expects
        _image!.path,
        filename: _image!.path.split('/').last,
      ));

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final uploadData = jsonDecode(response.body);
        final imageUrl = uploadData['url'];
        print("imageURL : $imageUrl");

        final verificationResponse = await http.post(
          Uri.parse('https://foodbridge1.onrender.com/me/verification'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json', // must specify JSON
          },
          body: jsonEncode({'idcard_image_url': imageUrl}),
        );

        if (verificationResponse.statusCode == 201) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VerifySuccessPage()),
          );
        } else {
          final error = jsonDecode(verificationResponse.body);
          print('Verification failed: $error');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Verification failed')));
        }
      } else {
        print('Upload failed: ${response.body}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image upload failed')));
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error occurred: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'ยืนยันตัวตน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // keeps text left-aligned
                children: const [
                  Text(
                    'เพิ่มรูปบัตรประชาชนของคุณ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '*สามารถปิดหรือขีดฆ่าเลขประจำตัวประชาชนได้',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // make image responsive (no fixed width)
            Image.asset(
              'assets/images/id_sample.png',
              width: MediaQuery.of(context).size.width * 0.5,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 8),
            const Text(
              'ตัวอย่างการปิดบังข้อมูล',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 245, 131, 25),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color.fromARGB(
                    255,
                    245,
                    131,
                    25,
                  ).withOpacity(0.05),
                ),
                child: _image == null
                    ? const Center(
                        child: Icon(
                          Icons.add,
                          color: Color.fromARGB(255, 245, 131, 25),
                          size: 50,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'หมายเหตุ:\n'
              '- สามารถปิดข้อมูลบัตรได้ ยกเว้นเลขท้าย 5 หลักสุดท้าย\n'
              '- ต้องแสดงชื่อ-นามสกุล ทั้งภาษาไทยและอังกฤษ\n'
              '- ข้อมูลบัตรจะใช้เพื่อตรวจสอบตัวตนเท่านั้น\n'
              '- ใช้เวลา 1-2 วันทำการ',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),

      // ✅ Button stays the same (no size, padding, or position changes)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _image == null ? null : _submit, // disable if no image
            style: ElevatedButton.styleFrom(
              backgroundColor: _image == null
                  ? Colors.grey // grey when disabled
                  : const Color.fromARGB(255, 245, 131, 25), // active color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: _image == null ? 0 : 3, // optional: no shadow when disabled
              shadowColor: const Color.fromRGBO(0, 0, 0, 0.25),
            ),
            child: const Text(
              'ตกลง',
              style: TextStyle(
                fontSize: 18,
                fontFamily: "IBMPlexSansThai",
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),

    );
  }
}
