import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'verify_otp_screen.dart';
import '../../core/api_service.dart'; // Use ApiService for brand-aware requests
import '../../config/flavor_config.dart';


class GenerateOtpScreen extends StatelessWidget {
  final TextEditingController _mobileController = TextEditingController();
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);

  GenerateOtpScreen({super.key}); // ✅ Manages loading state

  // Function to call the OTP API
  void _generateOtp(BuildContext context) async {
    final String mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
          duration: Duration(seconds: 2),
        ),
      );
      //Fluttertoast.showToast(msg: "Please enter a valid 10-digit mobile number.");
      return;
    }

    _isLoading.value = true; // ✅ Show loading state

    try {
      // Use ApiService which automatically adds X-Brand-Id header
      final apiService = ApiService();
      final response = await apiService.post(
        "/api/otp/outlets/register/",
        data: {"mobile": mobile},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      // Debug logging
      print('🔍 OTP API Response Status: ${response.statusCode}');
      print('🔍 OTP API Response Body: ${response.data}');

      final data = response.data;

      if (data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP Sent Successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        //Fluttertoast.showToast(msg: "OTP Sent Successfully!");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpScreen(mobile: mobile),
          ),
        );
      } else {
        final message = data["message"]?.toString() ?? "Failed to send OTP";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: 2),
          ),
        );
        //Fluttertoast.showToast(msg: data["message"] ?? "Failed to send OTP");
      }
    } catch (e) {
      print('🔍 OTP API Error: $e');
      String errorMessage = 'Failed to send OTP';

      if (e is DioException) {
        errorMessage = e.response?.data?['message']?.toString() ??
                      e.message ??
                      'Network error';
      } else {
        errorMessage = e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errorMessage'),
          duration: Duration(seconds: 2),
        ),
      );
      //Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }

    _isLoading.value = false; // ✅ Hide loading state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Container(),
            // Image.asset(
            //   'assets/cafe_background.jpg', // Background image
            //   fit: BoxFit.cover,
            // ),
          ),

          // Floating Box Centered
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Logo
                  Image.asset(
                    FlavorConfig.instance.brandConfig.logoAssetPath,
                    height: 80,
                    width: 80,
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    FlavorConfig.instance.brandConfig.brandName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Subtitle
                  Text(
                    "Enter your mobile number to get started",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mobile Number Input - Fixed Height
                  SizedBox(
                    height: 50, // Fixed height for both TextField & Button
                    width: double.infinity, // Match width
                    child: TextField(
                      autofocus: true,  // ✅ Auto-focus enabled
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone),
                        hintText: "Enter mobile number",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Generate OTP Button - Same Height as TextField
                  SizedBox(
                    height: 50, // Fixed height matching TextField
                    width: double.infinity, // Match width
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isLoading,
                      builder: (context, isLoading, child) {
                        return ElevatedButton(
                          onPressed: isLoading ? null : () => _generateOtp(context), // Disable when loading
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(double.infinity, 50), // Make button same height as TextField
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Generate OTP"),
                        );
                      }
                    )
                
                    // ElevatedButton(
                    //   onPressed: _isLoading ? null : _generateOtp, // Disable button when loading
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Color(0xFF54A079),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(10),
                    //     ),
                    //     padding: EdgeInsets.zero, // Remove extra padding
                    //   ),
                    //   child: Text(
                    //     "Generate OTP",
                    //     style: TextStyle(fontSize: 16),
                    //   ),
                    // ),
                  ),

                  const SizedBox(height: 15),

                  // Terms & Privacy Policy
                  Text.rich(
                    TextSpan(
                      text: "By continuing, you agree to our ",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      children: const [
                        TextSpan(
                          text: "Terms of Service",
                          style: TextStyle(color: Colors.blue),
                        ),
                        TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),

                  // // Help Section
                  // TextButton(
                  //   onPressed: () {
                  //     // Open Support
                  //   },
                  //   child: Text(
                  //     "Contact Support",
                  //     style: TextStyle(color: Color(0xFF54A079)),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
