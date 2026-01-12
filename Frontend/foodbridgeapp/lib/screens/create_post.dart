import 'package:flutter/material.dart';
import 'map_picker_page.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
//import 'package:intl/intl.dart'

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _pricecontroller = TextEditingController();
  final TextEditingController _quantitycontroller = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  // String _fmtTime(TimeOfDay t) =>
  //   '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  // final _thai = DateFormat('d MMM yyyy', 'th'); // e.g., 28 ก.ย. 2025
  bool _wantToDistribute = true;
  int _price = 0;
  int _quantity = 1;
  String _selectedCategory = 'ของคาว'; //wait for api+++++++++++++++++++++++++
  TimeOfDay _openTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 16, minute: 0);
  String _province = '';   // e.g., กรุงเทพมหานคร
  String _district = '';   // e.g., เขตบางรัก
  String _postal = '';     // e.g., 10400
  LatLng? _latLng;         // selected location

  File? _image;
  String? _uploadedImageUrl;
  
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

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked == null) return; // user cancelled

    setState(() {
      _image = File(picked.path);
    });

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://foodbridge1.onrender.com/me/uploads/images'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', picked.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);

        // Assuming backend returns {"url": "https://..."}
        setState(() {
          _uploadedImageUrl = data['url'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปสำเร็จ!')),
        );
      } else {
        throw Exception('Upload failed with ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปโหลดล้มเหลว: $e')),
      );
    }
  }


  @override
  void initState() {
    super.initState();
    _pricecontroller.text = _price.toString(); // set initial text
    _quantitycontroller.text = _quantity.toString(); // set initial text
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'โพสต์',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.orange),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image upload section
            Container(
              height: 120,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                      ),
                      child: _uploadedImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _uploadedImageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _image != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _image!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.add,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Description field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  hintText: 'ชื่อโพสต์',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Want to distribute toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ต้องการแจกอาหาร',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Switch(
                    value: _wantToDistribute,
                    onChanged: (value) {
                      setState(() {
                        _wantToDistribute = value;
                     
                        if (_wantToDistribute) {
                          _price = 0;
                          _pricecontroller.text = '0';
                        }
                      });
                    },
                    activeColor: Color(0xFF038263),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Price and quantity section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ราคาขาย',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Editable price field
                          SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _pricecontroller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  onChanged: (value) {
                                    setState(() {
                                      _price = int.tryParse(value) ?? 0;
                                      _pricecontroller.text = _price.toString();
                                      _wantToDistribute = _price == 0;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'บาท',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                                  ),
                                ),
                              ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _price+=5;
                                    _pricecontroller.text = _price.toString();
                                  });
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: Colors.grey[600],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _price-=5;
                                    if (_price < 0) _price = 0;
                                    _pricecontroller.text = _price.toString();
                                  });
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'จำนวน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: _quantitycontroller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  onChanged: (value) {
                                    setState(() {
                                      _quantity = int.tryParse(value) ?? 0;
                                      _quantitycontroller.text = _quantity.toString();
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'ชิ้น',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                                  ),
                                ),
                              ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _quantity++;
                                    _quantitycontroller.text = _quantity.toString();
                                  });
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: Colors.grey[600],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_quantity > 0) _quantity--;
                                    _quantitycontroller.text = _quantity.toString();
                                  });
                                },
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'หมวดหมู่อาหาร',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  //wait for api+++++++++++++++++++++++++
                  Row(
                    children: [
                      _buildCategoryButton('ของคาว'),
                      const SizedBox(width: 8),
                      _buildCategoryButton('ของหวาน'),
                      const SizedBox(width: 8),
                      _buildCategoryButton('ผักสด'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Opening hours
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date picker row + Time pickers
                  Row(
                    children: [
                      Icon(Icons.date_range, color: Color(0xFF038263), size: 20),
                      const SizedBox(width: 8),
                      const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0), 
                        child: Text(
                          'วันที่',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            // locale: const Locale('th', 'TH'),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _fmtDate(_selectedDate), // or _thai.format(_selectedDate)
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time,color: Color(0xFF038263),size: 20,),
                      const SizedBox(width: 8),
                      const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0), 
                        child: Text(
                          'เวลาเปิด - ปิด',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _openTime,
                          );
                          if (time != null) {
                            setState(() {
                              _openTime = time;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade400),   
                            borderRadius: BorderRadius.circular(8),   
                          ),
                          child: Text(
                            '${_openTime.hour.toString().padLeft(2, '0')}:${_openTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const Text(' - '),
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _closeTime,
                          );
                          if (time != null) {
                            setState(() {
                              _closeTime = time;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Address section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
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
                                _addressController.text = formatThaiAddress(result.placemark);
                                _province = result.placemark.administrativeArea ?? '';
                                _district = result.placemark.subLocality ?? '';
                                _postal   = result.placemark.postalCode ?? '';
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                hintText: 'แตะเพื่อเลือกตำแหน่งจากแผนที่\nบ้าน/เลขที่ ถนน แขวง เขต',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _province.isEmpty ? 'จังหวัด' : _province, // e.g., กรุงเทพมหานคร
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _postal.isEmpty ? 'เขต' : _district, // e.g., เขตบางรัก
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Details field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  hintText: 'รายละเอียด',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                maxLines: 3,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Phone number field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  hintText: '0xx-xxx-xxxx',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
      
      // Bottom post button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // Handle post creation
              _createPost();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF038263),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'โพสต์',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCategoryButton(String category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF038263) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
  
  void _createPost() async {
    final storage = const FlutterSecureStorage();
    final url = Uri.parse('https://foodbridge1.onrender.com/posts'); 
    final token = await storage.read(key: 'token');

    if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('กรุณาเข้าสู่ระบบก่อนโพสต์'),
        backgroundColor: Colors.red,
      ),
      );
      return;
    }

    if (_latLng == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('กรุณาเลือกตำแหน่งบนแผนที่ก่อนโพสต์'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
    }

    // Convert TimeOfDay to ISO 8601 (RFC3339)
    final openTimeDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _openTime.hour,
      _openTime.minute,
    ).toUtc();

    final closeTimeDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _closeTime.hour,
      _closeTime.minute,
    ).toUtc();
    if (closeTimeDate.isBefore(openTimeDate)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เวลาปิดต้องหลังเวลาเปิด'),
        backgroundColor: Colors.red,
      ),
    );
    return;
}

    // debug print 
    print('Description       : ${_descriptionController.text}');
    print('Want to distribute: $_wantToDistribute');
    print('Price             : $_price');
    print('Quantity          : $_quantity');
    print('Category          : $_selectedCategory');
    print('Open time         : ${openTimeDate.toIso8601String()}');
    print('Close time        : ${closeTimeDate.toIso8601String()}');
    print('Address           : ${_addressController.text}');
    print('Details           : ${_detailsController.text}');
    print('Phone             : ${_phoneController.text}');
    print('image URL        : ${_uploadedImageUrl ?? "not uploaded"}');
    print('LatLng            : ${_latLng != null ? "${_latLng!.latitude}, ${_latLng!.longitude}" : "not selected"}');
    
    // Build request body
    final body = {
    "title": _descriptionController.text,
    "description": _detailsController.text,
    "is_giveaway": _wantToDistribute,
    "price": _price,
    "quantity": _quantity,
    "category": _selectedCategory,
    "open_time": openTimeDate.toIso8601String(),
    "close_time": closeTimeDate.toIso8601String(),
    "address": _addressController.text,
    "province": _province,
    "district": _district,
    "phone": _phoneController.text,
    "lat": _latLng!.latitude,     
    "lng": _latLng!.longitude,    
    "images": [_uploadedImageUrl],
    "categories": [_selectedCategory], // only one selected
  };

  try {
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode(body),
    );

    print("Sending: ${json.encode(body)}");
    print("Response: ${response.statusCode} ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('โพสต์สำเร็จแล้ว!'),
          backgroundColor: Color(0xFF038263),
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถโพสต์ได้ (${response.statusCode})'),
          backgroundColor: Colors.red,
        ),
      );
      print("Response body: ${response.body}");
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  //   // Show success message or navigate back
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('โพสต์สำเร็จแล้ว!'),
  //       backgroundColor: Colors.green,
  //     ),
  //   );
  //   Future.delayed(const Duration(seconds: 1), () {
  //   Navigator.pop(context);
  //   });
  // }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _detailsController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}