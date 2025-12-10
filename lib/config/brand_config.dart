import 'package:flutter/material.dart';

/// Brand configuration class that holds all brand-specific settings
class BrandConfig {
  final String brandName;
  final String brandId;
  final String packageName;
  final Color primaryColor;
  final Color secondaryColor;
  final String logoAssetPath;
  final String baseUrl;

  const BrandConfig({
    required this.brandName,
    required this.brandId,
    required this.packageName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.logoAssetPath,
    required this.baseUrl,
  });

  /// Chaimates brand configuration
  static const chaimates = BrandConfig(
    brandName: 'Chaimates Outlet',
    brandId: '38a88abac48411f09212ea148faff773',
    packageName: 'com.saas_outlet_app.chaimates',
    primaryColor: Color(0xFF54A079),
    secondaryColor: Color(0xFF1F1B20),
    logoAssetPath: 'assets/chaimates/logo.png',
    baseUrl: 'http://139.59.86.36:8000',
  );

  /// JD's Kitchen brand configuration
  static const jdsKitchen = BrandConfig(
    brandName: "JD's Kitchen",
    brandId: '38a8915ec48411f09212ea148faff773',
    packageName: 'com.saas_outlet_app.jds_kitchen',
    primaryColor: Color(0xFF144c9f),
    secondaryColor: Color(0xFF040205),
    logoAssetPath: 'assets/jds_kitchen/logo.png',
    baseUrl: 'http://139.59.86.36:8000',
  );
}
