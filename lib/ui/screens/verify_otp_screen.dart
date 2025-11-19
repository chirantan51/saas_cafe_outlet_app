import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../constants.dart';
import '../../providers/auth_provider.dart';
import '../../utils/device_metadata.dart';
import 'dashboard_screen.dart';

class VerifyOtpScreen extends ConsumerWidget {
  final String mobile;
  VerifyOtpScreen({super.key, required this.mobile});

  final TextEditingController _otpController = TextEditingController();
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);

  Future<void> _verifyOtp(BuildContext context, WidgetRef ref) async {
    String otp = _otpController.text.trim();

    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid 4-digit OTP")));
      return;
    }

    _isLoading.value = true;

    try {
      final metadata = await DeviceMetadata.collect();
      final response = await http.post(
        Uri.parse("$BASE_URL/api/otp/outlets/register/"),
        body: {
          "mobile": mobile,
          "otp": otp,
          ...metadata.toRequestBody(),
        },
      );

      final data = jsonDecode(response.body);
      _isLoading.value = false;

      if (data["success"] == true) {
        final authToken = data["auth_token"];
        ref.read(authProvider.notifier).login(authToken); // ✅ Store token

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        final message = data["message"]?.toString() ?? "Failed to verify OTP";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      _isLoading.value = false;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error, try again.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: "Enter OTP"),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, isLoading, child) {
                return ElevatedButton(
                  onPressed: isLoading ? null : () => _verifyOtp(context, ref),
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Verify OTP"),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}



// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:outlet_app/constants.dart';
// import 'package:provider/provider.dart';
// import '../../state/auth_provider.dart';
// import 'dashboard_screen.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class VerifyOtpScreen extends StatelessWidget {
//   final String mobile;
//   VerifyOtpScreen({required this.mobile});

//   final List<TextEditingController> _otpControllers =
//       List.generate(4, (index) => TextEditingController());
//   final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

//   final ValueNotifier<bool> _isResendEnabled = ValueNotifier(false);
//   final ValueNotifier<int> _secondsRemaining = ValueNotifier(40);
//   final ValueNotifier<bool> _isLoading = ValueNotifier(false);

//   void _startOtpTimer() {
//     _isResendEnabled.value = false;
//     _secondsRemaining.value = 40;

//     Timer.periodic(Duration(seconds: 1), (timer) {
//       if (_secondsRemaining.value > 0) {
//         _secondsRemaining.value--;
//       } else {
//         timer.cancel();
//         _isResendEnabled.value = true;
//       }
//     });
//   }

//   Future<void> _verifyOtp(BuildContext context) async {
//     String otp = _otpControllers.map((e) => e.text).join(); // Get OTP as string
//     if (otp.length != 4) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Enter a valid 4-digit OTP")),
//       );
//       return;
//     }

//     _isLoading.value = true;

//     final response = await http.post(
//       Uri.parse("$BASE_URL/api/otp/outlets/register/"),
//       body: {
//         "mobile": mobile,
//         "otp": otp,
//       },
//     );

//     final data = jsonDecode(response.body);

//     _isLoading.value = false;

//     if (data["success"] == true) {
//       final authToken = data["auth_token"];

//       // ✅ Store token in SharedPreferences
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setString("auth_token", authToken);

//       final authProvider = Provider.of<AuthProvider>(context, listen: false);
//       authProvider.login(authToken);

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => DashboardScreen()),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(data["message"])),
//       );
//     }
//   }

//   void _resendOtp(BuildContext context) {
//     _startOtpTimer();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("OTP Resent to $mobile")),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     _startOtpTimer();

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Verify OTP"),
//         backgroundColor: Theme.of(context).primaryColor,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               // ✅ Replace with actual image path in assets
//               //Image.asset("assets/images/otp_banner.png", height: 150),

//               SizedBox(height: 20),
//               Text(
//                 "Verify Your Identity",
//                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               Text(
//                 "We've sent a verification code to\n$mobile",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//               ),

//               SizedBox(height: 20),

//               // ✅ OTP Boxes
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: List.generate(4, (index) {
//                   return Container(
//                     width: 50,
//                     height: 50,
//                     margin: EdgeInsets.symmetric(horizontal: 5),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(10),
//                       border: Border.all(color: Colors.grey),
//                     ),
//                     alignment: Alignment.center,
//                     child: TextField(
//                       controller: _otpControllers[index],
//                       focusNode: _focusNodes[index],
//                       keyboardType: TextInputType.number,
//                       textAlign: TextAlign.center,
//                       maxLength: 1,
//                       obscureText: true, // ✅ Hides OTP with *
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                       decoration: InputDecoration(
//                         counterText: "",
//                         border: InputBorder.none,
//                       ),
//                       onChanged: (value) {
//                         if (value.isNotEmpty) {
//                           if (index < 3) {
//                             _focusNodes[index].unfocus();
//                             FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
//                           }
//                         } else {
//                           if (index > 0) {
//                             _focusNodes[index].unfocus();
//                             FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
//                           }
//                         }
//                       },
//                     ),
//                   );
//                 }),
//               ),

//               SizedBox(height: 10),

//               // ✅ Timer
//               ValueListenableBuilder<int>(
//                 valueListenable: _secondsRemaining,
//                 builder: (context, value, child) {
//                   return Text(
//                     "Code expires in 00:${value.toString().padLeft(2, '0')}",
//                     style: TextStyle(color: Colors.redAccent, fontSize: 14),
//                   );
//                 },
//               ),

//               SizedBox(height: 20),

//               // ✅ Verify Button
//               ValueListenableBuilder<bool>(
//                 valueListenable: _isLoading,
//                 builder: (context, isLoading, child) {
//                   return ElevatedButton(
//                     onPressed: isLoading ? null : () => _verifyOtp(context),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Color(0xFF54A079),
//                       minimumSize: Size(double.infinity, 50),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: isLoading
//                         ? CircularProgressIndicator(color: Colors.white)
//                         : Text("Verify OTP", style: TextStyle(fontSize: 16)),
//                   );
//                 },
//               ),

//               SizedBox(height: 20),

//               // ✅ Resend OTP
//               ValueListenableBuilder<bool>(
//                 valueListenable: _isResendEnabled,
//                 builder: (context, isEnabled, child) {
//                   return TextButton(
//                     onPressed: isEnabled ? () => _resendOtp(context) : null,
//                     child: Text(
//                       isEnabled ? "Resend OTP" : "Resend in ${_secondsRemaining.value}s",
//                       style: TextStyle(color: isEnabled ? Color(0xFF54A079) : Colors.grey),
//                     ),
//                   );
//                 },
//               ),

//               SizedBox(height: 20),

//               // ✅ Security Info
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.lock, color: Color(0xFF54A079)),
//                   SizedBox(width: 5),
//                   Text(
//                     "Your information is securely encrypted",
//                     style: TextStyle(color: Colors.grey, fontSize: 12),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
