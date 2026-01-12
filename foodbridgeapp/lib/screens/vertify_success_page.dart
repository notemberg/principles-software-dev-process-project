import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerifySuccessPage extends StatelessWidget {
  const VerifySuccessPage({super.key});

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/vertify_check.svg',
                width: 70,
                height: 70,
              ),
              const SizedBox(height: 20),
              const Text(
                'การยืนยันตัวตนสำเร็จ',
                style: TextStyle(
                  color: Color.fromARGB(255, 3, 130, 99),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณได้รับการยืนยันตัวตนแล้ว\nรอแอดมินตรวจสอบ 1 - 2 วันทำการ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 3, 130, 99),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: const Color.fromRGBO(0, 0, 0, 0.25),
            ),
            child: const Text("บันทึก", style: TextStyle(fontSize: 18, fontFamily: "IBMPlexSansThai", color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
