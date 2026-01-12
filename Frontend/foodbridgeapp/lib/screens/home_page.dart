import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'for_you_page.dart';
import 'community_page.dart';
import 'nav_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedTab = "forYou"; // ค่าเริ่มต้น
  String? currentProvince;

  @override
  void initState() {
    super.initState();
    _loadUserProvinceAndPosition();
  }

  Future<void> _loadUserProvinceAndPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        currentProvince = placemarks.isNotEmpty
            ? placemarks.first.administrativeArea ?? "No Where"
            : "No Where";
      });
    } catch (e) {
      debugPrint("Error reverse geocoding: $e");
      // if (!mounted) return;
      setState(() {
        currentProvince = "No Where";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavBar(
        currentIndex: 0,
        hasNotification: true,
      ),
      body: Stack(
        children: [
          // 🔹 พื้นหลัง Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
                colors: [
                  Color.fromARGB(90, 3, 130, 98),
                  Color.fromARGB(60, 244, 243, 243),
                  Color(0xFFF4F3F3),
                ],
              ),
            ),
          ),

          // 🔹 เนื้อหาหลัก
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 ปุ่มเลือกแท็บ
                  Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/back_arrow.svg',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "ตำแหน่งของคุณ",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              SizedBox(
                                width:  400,
                                child: Text(
                                  currentProvince ?? 'Unknown',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    // color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTab = "forYou";
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selectedTab == "forYou"
                                ? const Color(0xff038263)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'สำหรับคุณ',
                            style: TextStyle(
                              color: selectedTab == "forYou"
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTab = "community";
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selectedTab == "community"
                                ? const Color(0xff038263)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/commu_icon.svg',
                                width: 15,
                                height: 15,
                                color: selectedTab == "community"
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ชุมชน',
                                style: TextStyle(
                                  color: selectedTab == "community"
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🔹 เนื้อหาเปลี่ยนตามแท็บ
                  Expanded(
                    child: selectedTab == "forYou"
                        ? ForYouPage()
                        : CommunityPage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
