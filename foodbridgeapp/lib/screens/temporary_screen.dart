import 'package:flutter/material.dart';
import 'package:foodbridgeapp/screens/login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'post_page.dart';
import 'edit_profile_page.dart';
import 'profile_page.dart';
import 'other_profile_page.dart';
import 'setting_page.dart';
import 'history_order_page.dart';
import 'view_more_page.dart';

class TemporaryScreen extends StatelessWidget {
  const TemporaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "หน้าแรกชั่วคราวให้ทุกคน\nกดเพจของตัวเองแล้วเขียนโค้ดได้เลย",
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
              child: const Text('Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterPage()),
                );
              },
              child: const Text('Register'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HomePage()),
                );
              },
              child: const Text('Home'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PostPage(postId: 2)),
                );
              },
              child: const Text('Post'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                );
              },
              child: const Text('Edit Profile'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: const Text('Profile'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OtherProfilePage(userId: 3)),
                );
              },
              child: const Text('other Profile'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HistoryOrderPage()),
                );
              },
              child: const Text('History Order'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ViewMorePage(type: 'free', ownerId:'0')),
                );
              },
              child: const Text('History Order'),
            ),
          ],
        ),
      ),
    );
  }
}
