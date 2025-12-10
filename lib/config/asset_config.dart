import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'flavor_config.dart';

/// Manages brand-specific assets with support for:
/// 1. Bundled assets (fallback)
/// 2. Downloaded assets (for reducing APK size)
/// 3. CDN-hosted assets (for dynamic brands)
class AssetConfig {
  static final AssetConfig _instance = AssetConfig._internal();
  factory AssetConfig() => _instance;
  AssetConfig._internal();

  final Dio _dio = Dio();

  /// Base URL for hosted brand assets (optional)
  /// Example: 'https://your-cdn.com/brand-assets'
  static const String? assetCdnBaseUrl = null; // Set this to enable CDN

  /// Check if asset is bundled (for current brand only)
  bool get isAssetBundled {
    // Only the current flavor's assets are bundled
    // This will be controlled by build scripts
    return true; // Default: use bundled assets
  }

  /// Get logo path for current brand
  String getLogoPath() {
    final brandConfig = FlavorConfig.instance.brandConfig;
    return brandConfig.logoAssetPath;
  }

  /// Get icon path for current brand
  String getIconPath(String iconName) {
    final flavor = FlavorConfig.instance.flavor;
    return 'assets/$flavor/icons/$iconName';
  }

  /// Get sound path for current brand
  String getSoundPath(String soundName) {
    final flavor = FlavorConfig.instance.flavor;
    return 'assets/$flavor/sounds/$soundName';
  }

  /// Download brand assets from CDN (for future use)
  /// This allows you to publish a minimal APK and download brand assets on first launch
  Future<void> downloadBrandAssets({
    required String brandId,
    String? cdnUrl,
  }) async {
    if (cdnUrl == null && assetCdnBaseUrl == null) {
      if (kDebugMode) {
        print('⚠️ CDN URL not configured, skipping asset download');
      }
      return;
    }

    final baseUrl = cdnUrl ?? assetCdnBaseUrl!;
    final appDir = await getApplicationDocumentsDirectory();
    final brandAssetsDir = Directory('${appDir.path}/brand_assets/$brandId');

    if (!await brandAssetsDir.exists()) {
      await brandAssetsDir.create(recursive: true);
    }

    try {
      // Download logo
      await _downloadFile(
        '$baseUrl/$brandId/logo.png',
        '${brandAssetsDir.path}/logo.png',
      );

      // Download other assets as needed
      if (kDebugMode) {
        print('✅ Brand assets downloaded successfully for $brandId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to download brand assets: $e');
      }
      // Fallback to bundled assets
    }
  }

  Future<void> _downloadFile(String url, String savePath) async {
    try {
      await _dio.download(url, savePath);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to download $url: $e');
      }
      rethrow;
    }
  }

  /// Get downloaded asset path (for CDN-based assets)
  Future<String?> getDownloadedAssetPath(String assetName) async {
    final brandId = FlavorConfig.instance.brandConfig.brandId;
    final appDir = await getApplicationDocumentsDirectory();
    final assetPath = '${appDir.path}/brand_assets/$brandId/$assetName';

    final file = File(assetPath);
    if (await file.exists()) {
      return assetPath;
    }
    return null;
  }
}
