import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.motorcycle, color: Colors.teal, size: 100),
            SizedBox(height: 20),
            Text(
              'BILLK MOTOLINK LTD',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.teal),
          ],
        ),
      ),
    );
  }
}
