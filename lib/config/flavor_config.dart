import 'brand_config.dart';

/// Flavor configuration that determines which brand is currently active
class FlavorConfig {
  final BrandConfig brandConfig;
  final String flavor;

  FlavorConfig._({
    required this.brandConfig,
    required this.flavor,
  });

  static FlavorConfig? _instance;

  /// Get the current flavor configuration instance
  static FlavorConfig get instance {
    if (_instance == null) {
      throw Exception(
        'FlavorConfig not initialized. Call FlavorConfig.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if FlavorConfig has been initialized
  static bool get isInitialized => _instance != null;

  /// Initialize the flavor configuration
  static void initialize({required String flavor}) {
    final BrandConfig brandConfig;

    switch (flavor.toLowerCase()) {
      case 'chaimates':
        brandConfig = BrandConfig.chaimates;
        break;
      case 'jds_kitchen':
      case 'jdskitchen':
        brandConfig = BrandConfig.jdsKitchen;
        break;
      default:
        throw Exception('Unknown flavor: $flavor');
    }

    _instance = FlavorConfig._(
      brandConfig: brandConfig,
      flavor: flavor,
    );
  }

  /// Reset the flavor configuration (useful for testing)
  static void reset() {
    _instance = null;
  }
}
