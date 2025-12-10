#!/usr/bin/env python3
"""
Enterprise Multi-Brand Configuration Generator
Generates Flutter/Android/iOS configurations for 20+ brands from brands_config.json
"""

import json
import os
import sys
from pathlib import Path

def load_brands_config():
    """Load brands configuration from JSON file"""
    config_path = Path(__file__).parent / "brands_config.json"
    with open(config_path, 'r') as f:
        return json.load(f)

def generate_brand_config_dart(brands):
    """Generate lib/config/brand_config.dart with all brands"""

    brand_configs = []
    for brand in brands:
        if not brand.get('active', True):
            continue

        config = f"""  /// {brand['name']} brand configuration
  static const {brand['id']} = BrandConfig(
    brandName: '{brand['name']}',
    brandId: '{brand['brandId']}',
    packageName: '{brand['packageName']}',
    primaryColor: Color(0xFF{brand['primaryColor'][1:]}),
    secondaryColor: Color(0xFF{brand['secondaryColor'][1:]}),
    logoAssetPath: 'assets/{brand['id']}/logo.png',
    baseUrl: 'http://139.59.86.36:8000',
  );"""
        brand_configs.append(config)

    dart_content = f"""import 'package:flutter/material.dart';

/// Brand configuration class that holds all brand-specific settings
class BrandConfig {{
  final String brandName;
  final String brandId;
  final String packageName;
  final Color primaryColor;
  final Color secondaryColor;
  final String logoAssetPath;
  final String baseUrl;

  const BrandConfig({{
    required this.brandName,
    required this.brandId,
    required this.packageName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.logoAssetPath,
    required this.baseUrl,
  }});

{chr(10).join(brand_configs)}
}}
"""

    output_path = Path(__file__).parent / "lib/config/brand_config.dart"
    with open(output_path, 'w') as f:
        f.write(dart_content)

    print(f"✅ Generated {output_path}")

def generate_flavor_config_dart(brands):
    """Generate lib/config/flavor_config.dart with all brand cases"""

    switch_cases = []
    for brand in brands:
        if not brand.get('active', True):
            continue

        case = f"""      case '{brand['id']}':
        brandConfig = BrandConfig.{brand['id']};
        break;"""
        switch_cases.append(case)

    dart_content = f"""import 'brand_config.dart';

/// Flavor configuration that determines which brand is currently active
class FlavorConfig {{
  final BrandConfig brandConfig;
  final String flavor;

  FlavorConfig._({{
    required this.brandConfig,
    required this.flavor,
  }});

  static FlavorConfig? _instance;

  /// Get the current flavor configuration instance
  static FlavorConfig get instance {{
    if (_instance == null) {{
      throw Exception(
        'FlavorConfig not initialized. Call FlavorConfig.initialize() first.',
      );
    }}
    return _instance!;
  }}

  /// Check if FlavorConfig has been initialized
  static bool get isInitialized => _instance != null;

  /// Initialize the flavor configuration
  static void initialize({{required String flavor}}) {{
    final BrandConfig brandConfig;

    switch (flavor.toLowerCase()) {{
{chr(10).join(switch_cases)}
      default:
        throw Exception('Unknown flavor: $flavor');
    }}

    _instance = FlavorConfig._(
      brandConfig: brandConfig,
      flavor: flavor,
    );
  }}

  /// Reset the flavor configuration (useful for testing)
  static void reset() {{
    _instance = null;
  }}
}}
"""

    output_path = Path(__file__).parent / "lib/config/flavor_config.dart"
    with open(output_path, 'w') as f:
        f.write(dart_content)

    print(f"✅ Generated {output_path}")

def generate_android_flavors(brands):
    """Generate Android product flavors configuration snippet"""

    flavors = []
    for brand in brands:
        if not brand.get('active', True):
            continue

        flavor = f"""        {brand['id']} {{
            dimension "brand"
            applicationId "{brand['packageName']}"
            resValue "string", "app_name", "{brand['name']}"
            manifestPlaceholders = [
                    applicationName: "io.flutter.app.FlutterApplication",
                    MAPS_API_KEY : mapsApiKey
            ]
        }}"""
        flavors.append(flavor)

    gradle_snippet = f"""    flavorDimensions "brand"

    productFlavors {{
{chr(10).join(flavors)}
    }}"""

    print("\n📱 Android Product Flavors (add to android/app/build.gradle):")
    print("="*60)
    print(gradle_snippet)
    print("="*60)

    return gradle_snippet

def generate_ios_configs(brands):
    """Generate iOS xcconfig files for each brand"""

    ios_flutter_dir = Path(__file__).parent / "ios/Flutter"
    ios_flutter_dir.mkdir(parents=True, exist_ok=True)

    for brand in brands:
        if not brand.get('active', True):
            continue

        # Convert brand id to PascalCase for filename
        filename = ''.join(word.capitalize() for word in brand['id'].split('_'))

        config_content = f"""#include "Generated.xcconfig"

PRODUCT_BUNDLE_IDENTIFIER = {brand['bundleId']}
APP_DISPLAY_NAME = {brand['name']}
"""

        config_path = ios_flutter_dir / f"{filename}.xcconfig"
        with open(config_path, 'w') as f:
            f.write(config_content)

        print(f"✅ Generated {config_path}")

def generate_build_scripts(brands):
    """Generate individual build scripts for each brand"""

    for brand in brands:
        if not brand.get('active', True):
            continue

        script_content = f"""#!/bin/bash

# Build script for {brand['name']}

echo "🚀 Building {brand['name']}..."

# Use the optimized build script
./build_flavor.sh {brand['id']} "$@"
"""

        script_path = Path(__file__).parent / f"build_{brand['id']}.sh"
        with open(script_path, 'w') as f:
            f.write(script_content)

        os.chmod(script_path, 0o755)  # Make executable
        print(f"✅ Generated {script_path}")

def generate_asset_directories(brands):
    """Create asset directories for each brand"""

    assets_dir = Path(__file__).parent / "assets"

    for brand in brands:
        if not brand.get('active', True):
            continue

        brand_dir = assets_dir / brand['id']
        (brand_dir / "icons").mkdir(parents=True, exist_ok=True)
        (brand_dir / "sounds").mkdir(parents=True, exist_ok=True)

        # Create placeholder files
        placeholder = brand_dir / ".gitkeep"
        placeholder.touch()

        print(f"✅ Created asset directory: {brand_dir}")

def main():
    print("🚀 Enterprise Multi-Brand Configuration Generator")
    print("="*60)

    config = load_brands_config()
    brands = config['brands']
    active_brands = [b for b in brands if b.get('active', True)]

    print(f"\n📊 Found {len(active_brands)} active brands out of {len(brands)} total")

    # Generate all configurations
    print("\n📝 Generating configurations...")
    generate_brand_config_dart(brands)
    generate_flavor_config_dart(brands)
    generate_android_flavors(brands)
    generate_ios_configs(brands)
    generate_build_scripts(brands)
    generate_asset_directories(brands)

    print("\n" + "="*60)
    print("✅ All configurations generated successfully!")
    print("\n📚 Next steps:")
    print("1. Copy the Android flavors snippet to android/app/build.gradle")
    print("2. Add brand logos to respective assets/<brand>/logo.png")
    print("3. Run ./build_<brand>.sh release to build")
    print("="*60)

if __name__ == "__main__":
    main()
