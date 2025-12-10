import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/ui/screens/manage_menu_screen.dart';
import 'package:outlet_app/ui/screens/new_edit_category_screen.dart';
import 'package:outlet_app/ui/screens/menu_item_screen.dart';
import 'package:outlet_app/ui/screens/subscription_create_subscription.dart';
import 'package:outlet_app/ui/theme.dart';
import 'package:outlet_app/config/flavor_config.dart';
import 'ui/screens/create_subscription_plan_screen.dart';
import 'ui/screens/about_us_screen.dart';
import 'ui/screens/manage_subscriptions_screen.dart';
import 'ui/screens/customer_management_screen.dart';
import 'ui/screens/generate_otp_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/dashboard_v2.dart';
import 'ui/screens/dashboard_v3.dart';
import 'ui/screens/dashboard_modern_screen.dart';
import 'providers/dashboard_provider.dart';
import 'providers/recent_orders_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/category_provider.dart';
import 'providers/business_mode_provider.dart';
import 'providers/subscription_products_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:outlet_app/services/notification_service.dart'; // Update with actual path

/// Background message handler for Firebase Cloud Messaging
/// This runs in an isolate separate from the main app
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔄 Handling background message: ${message.messageId}');

  // Initialize Firebase if needed (in background isolate)
  await Firebase.initializeApp();

  // Background-safe logic here
  // Note: UI operations are not available in background handler
  print('Background notification received: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flavor configuration
  // The flavor is passed via --dart-define during build
  const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'chaimates');
  FlavorConfig.initialize(flavor: flavor);

  // Register background message handler FIRST (must be set BEFORE Firebase.initializeApp)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Firebase (flavor-specific google-services.json will be used)
  await Firebase.initializeApp();

  final container = ProviderContainer();

  // Initialize notification service for foreground notifications
  final notificationService = NotificationService(container);
  await notificationService.init();

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
      ref.invalidate(customerListProvider);
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
    final brandName = FlavorConfig.instance.brandConfig.brandName;

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: brandName,
      theme: AppTheme.lightTheme, // ✅ Apply Theme Globally (now brand-aware)
      routes: {
        "/login": (context) => GenerateOtpScreen(),
        "/dashboard": (context) => const DashboardScreen(),
        "/dashboard-v2": (context) => const DashboardV2Screen(),
        "/dashboard-v3": (context) => const DashboardV3Screen(),
        "/dashboard-modern": (context) => const DashboardModernScreen(),
        "/manage-menu": (context) => const ManageMenuScreen(),
        "/create-subscription-plan": (context) =>
            const CreateSubscriptionPlanScreen(),
        "/create-subscription": (context) =>
            const SubscriptionCreateSubscriptionScreen(),
        "/about-us": (context) => const AboutUsScreen(),
        "/manage-subscriptions": (context) => const ManageSubscriptionsScreen(),
        "/customer-management": (context) =>
            const CustomerManagementScreen(),
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
          //? const DashboardModernScreen()
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
