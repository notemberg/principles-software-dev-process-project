import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_picker_page.dart'; // or wherever your MapPickerPage lives
import 'dart:convert';
import 'nav_bar.dart';
import 'map_picker_page.dart';
import 'package:geocoding/geocoding.dart';
import 'create_post.dart';

LatLng? _latLng;

String formatThaiAddress(Placemark p) {
  // Safely join components commonly used in TH addresses
  final parts = [
    p.street,               // บ้าน/เลขที่ ถนน (sometimes full line)
    p.subLocality,          // แขวง/ตำบล
    p.locality,             // เขต/อำเภอ
  ].where((e) => (e != null && e.trim().isNotEmpty)).toList();
  // Fallback if street is empty: use name + thoroughfare if available (optional)
  if (parts.isEmpty) return '${p.name ?? ''} ${p.thoroughfare ?? ''}'.trim();
  return parts.join(' ');
  }

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();


  // Controllers
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _phoneController = TextEditingController();

  Map<String, dynamic>? userData;
  File? _image;

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
        _usernameController.text = data['display_name'] ?? '';
        _nameController.text = data['first_name'] ?? '';
        _lastnameController.text = data['last_name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _locationController.text = data['address_line'] ?? '';
        _provinceController.text = data['province'] ?? '';
        _postcodeController.text = data['postal_code'] ?? '';
        _phoneController.text = data['phone'] ?? '';
      });
    } else {
      print('Failed to load user: ${response.statusCode}');
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return;

    String? imageUrl = userData?['avatar_url'];

    // Upload image if new one picked
    if (_image != null) {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://foodbridge1.onrender.com/me/uploads/images'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        _image!.path,
        filename: _image!.path.split('/').last,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final uploadData = jsonDecode(response.body);
        imageUrl = uploadData['url'];
        print("Uploaded image URL: $imageUrl");
      } else {
        print("Image upload failed: ${response.statusCode}");
      }
    }

    final body = {
      "display_name": _usernameController.text,
      "first_name": _nameController.text,
      "last_name": _lastnameController.text,
      "bio": _bioController.text,
      "address_line": _locationController.text,
      "province": _provinceController.text,
      "postal_code": _postcodeController.text,
      "phone": _phoneController.text,
      "avatar_url": imageUrl,
    };

    final response = await http.put(
      Uri.parse('https://foodbridge1.onrender.com/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกโปรไฟล์เรียบร้อย ✅')),
      );
      _loadUser(); // refresh to show updated avatar
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตไม่สำเร็จ ❌ (${response.statusCode})')),
      );
    }
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? type,
    int? maxLines = 1,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.25),
                  blurRadius: 2,
                  offset: Offset(0, 2))
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            validator: validator,
            decoration: InputDecoration(
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color.fromARGB(255, 3, 130, 99), width: 1)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.red, width: 1)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 244, 243, 243),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 244, 243, 243),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "แก้ไขโปรไฟล์",
          style: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 90,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _image != null
                          ? FileImage(_image!)
                          : (userData?['avatar_url'] != null
                              ? NetworkImage(userData!['avatar_url'])
                              : null) as ImageProvider<Object>?,
                      child: _image == null && userData?['avatar_url'] == null
                          ? SvgPicture.asset(
                              'assets/icons/no_profile.svg',
                              width: 180,
                              height: 180,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Fields
              buildTextField("Username", _usernameController),
              buildTextField("ชื่อ", _nameController),
              buildTextField("นามสกุล", _lastnameController),
              buildTextField("Bio", _bioController, maxLines: 2),
              // Replace the "ที่อยู่ / Location" field section with this:
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'ที่อยู่', 
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    )
                  ),
                ],      
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.15),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: Colors.red[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapPickerPage(
                                initial: _latLng ?? const LatLng(13.7563, 100.5018),
                              ),
                            ),
                          );

                          if (result != null) {
                            setState(() {
                              _latLng = result.latLng;
                              _locationController.text = formatThaiAddress(result.placemark);
                              _provinceController.text = result.placemark.administrativeArea ?? '';
                              _postcodeController.text = result.placemark.postalCode ?? '';
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              hintText: 'แตะเพื่อเลือกตำแหน่งจากแผนที่\nบ้าน/เลขที่ ถนน แขวง เขต',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true, 
                              contentPadding: EdgeInsets.zero, 
                            ),
                            maxLines: null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                      flex: 2, child: buildTextField("จังหวัด", _provinceController)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: buildTextField(
                      "Postcode",
                      _postcodeController,
                      type: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "กรอก Postcode";
                        if (!RegExp(r'^\d{5}$').hasMatch(value)) {
                          return "ต้องเป็นตัวเลข 5 หลัก";
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              buildTextField("เบอร์โทร", _phoneController, type: TextInputType.phone),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _saveProfile();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 130, 99),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                    shadowColor: const Color.fromRGBO(0, 0, 0, 0.25),
                  ),
                  child: const Text(
                    "บันทึก",
                    style: TextStyle(fontFamily: "IBMPlexSansThai"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

