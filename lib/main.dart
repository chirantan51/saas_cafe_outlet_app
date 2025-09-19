import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/ui/screens/manage_menu_screen.dart';
import 'package:outlet_app/ui/screens/new_edit_category_screen.dart';
import 'package:outlet_app/ui/screens/menu_item_screen.dart';
import 'package:outlet_app/ui/theme.dart';
import 'ui/screens/generate_otp_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/dashboard_v2.dart';
import 'ui/screens/dashboard_v3.dart';
import 'providers/dashboard_provider.dart';
import 'providers/recent_orders_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/category_provider.dart';
import 'providers/business_mode_provider.dart';
import 'providers/subscription_products_provider.dart';
import 'providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:outlet_app/services/notification_service.dart'; // Update with actual path


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('dkC: 🔄 Handling background message: ${message.messageId}');
  
  // (Optional) Initialize Flutter or Firebase if needed
  await Firebase.initializeApp();

  // You can access background-safe logic here
  // e.g., trigger Android activity using method channel if needed
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Must be set BEFORE Firebase is initialized
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final container = ProviderContainer();
  final notificationService = NotificationService(container);
  await notificationService.init(); // ✅ AFTER Firebase.init()

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    // Optionally, you can stop the app from crashing
    Zone.current.handleUncaughtError(
        details.exception, details.stack ?? StackTrace.current);
  };
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ProviderScope(child: MyApp()),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final ProviderSubscription<AuthState> _authSub;
  @override
  void initState() {
    super.initState();
    // Listen for auth changes to clear provider caches on logout/login
    _authSub = ref.listenManual<AuthState>(authProvider, (prev, next) {
      // Invalidate data providers whenever auth flips to ensure fresh data
      ref.invalidate(dashboardProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(menuProvider);
      ref.invalidate(businessModeProvider);
      ref.invalidate(subscriptionDashboardProvider);
      // Category-related fetch providers will rebuild as needed
      // If there are additional user-scoped providers, invalidate them here.
    });
  }

  @override
  void dispose() {
    _authSub.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider); // ✅ Listen to auth state

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Chaimates Outlet',
      theme: AppTheme.lightTheme, // ✅ Apply Theme Globally
      routes: {
        "/login": (context) => GenerateOtpScreen(),
        "/dashboard": (context) => const DashboardScreen(),
        "/dashboard-v2": (context) => const DashboardV2Screen(),
        "/dashboard-v3": (context) => const DashboardV3Screen(),
        "/manage-menu": (context) => const ManageMenuScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == "/add-item") {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => MenuItemScreen(
              isEditMode: args?["is_edit_mode"] ?? false,
              productId: args?["product_id"],
            ),
          );
        } else if (settings.name == "/add-category") {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => NewEditCategoryScreen(
              isEditMode: args?["is_edit_mode"] ?? false,
              categoryId: args?["category_id"],
            ),
          );
        }
        return null; // Return null if the route is unknown
      },
      debugShowCheckedModeBanner: false,
      home: authState.isAuthenticated
          ? const DashboardV3Screen()
          : GenerateOtpScreen(),
    );
  }
}


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
  
//   // ✅ Check if token exists and is valid
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   String? authToken = prefs.getString("auth_token");

//   runApp(MyApp(authToken: authToken));
// }

// class MyApp extends StatelessWidget {
//   final String? authToken;
//   MyApp({this.authToken});

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (context) => AuthProvider(),
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         theme: AppTheme.lightTheme, // ✅ Apply Theme
//         // theme: ThemeData(
//         //   primaryColor: Color(0xFF54A079),
//         //   scaffoldBackgroundColor: Colors.white,
//         // ),
//         home: authToken != null ? DashboardScreen() : GenerateOtpScreen(),
//       ),
//     );
//   }
// }


// void main() {
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (context) => AuthProvider()),
//       ],
//       child: MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Chaimates Outlet',
//       theme: AppTheme.lightTheme, // ✅ Apply Theme
//       home: GenerateOtpScreen(),
//     );
//   }
// }
