# Multi-Brand Configuration Guide

This document explains how to build and run the Outlet App for different brands.

## 🎯 Available Brands

### 1. **Chaimates Outlet**
- **Package Name**: `com.chaimates.outlet_app`
- **Brand ID**: `38a8915e-c484-11f0-9212-ea148faff773`
- **Primary Color**: `#54A079` (Green)
- **Secondary Color**: `#1F1B20` (Dark)

### 2. **JD's Kitchen**
- **Package Name**: `com.saas_outlet_app.jds_kitchen`
- **Brand ID**: `38a8915ec48411f09212ea148faff773`
- **Primary Color**: `#144c9f` (Blue)
- **Secondary Color**: `#040205` (Dark)

---

## 🚀 Quick Start

### Running the App (Development)

#### Using Build Scripts (Recommended)
```bash
# Run Chaimates
./run_app.sh chaimates

# Run JD's Kitchen
./run_app.sh jds_kitchen
```

#### Using Flutter CLI Directly
```bash
# Run Chaimates
flutter run --flavor chaimates --dart-define=FLAVOR=chaimates

# Run JD's Kitchen
flutter run --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen
```

---

## 📦 Building APKs

### Using Build Scripts (Recommended)

#### **Chaimates Outlet**
```bash
# Debug APK
./build_chaimates.sh debug

# Release APK
./build_chaimates.sh release

# App Bundle (for Play Store)
./build_chaimates.sh appbundle

# iOS Build
./build_chaimates.sh ios
```

#### **JD's Kitchen**
```bash
# Debug APK
./build_jds_kitchen.sh debug

# Release APK
./build_jds_kitchen.sh release

# App Bundle (for Play Store)
./build_jds_kitchen.sh appbundle

# iOS Build
./build_jds_kitchen.sh ios
```

### Using Flutter CLI Directly

#### **Debug Builds**
```bash
# Chaimates Debug
flutter build apk --flavor chaimates --dart-define=FLAVOR=chaimates --debug

# JD's Kitchen Debug
flutter build apk --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen --debug
```

#### **Release Builds**
```bash
# Chaimates Release
flutter build apk --flavor chaimates --dart-define=FLAVOR=chaimates --release

# JD's Kitchen Release
flutter build apk --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen --release
```

#### **App Bundles (for Play Store)**
```bash
# Chaimates App Bundle
flutter build appbundle --flavor chaimates --dart-define=FLAVOR=chaimates --release

# JD's Kitchen App Bundle
flutter build appbundle --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen --release
```

---

## 🏗️ Project Structure

### Configuration Files
```
lib/config/
├── brand_config.dart          # Brand-specific settings (colors, IDs, etc.)
└── flavor_config.dart         # Flavor initialization and management
```

### Brand-Specific Assets
```
assets/
├── chaimates/
│   ├── logo.png
│   ├── icons/
│   └── sounds/
├── jds_kitchen/
│   ├── logo.png               # Replace with JD's Kitchen logo
│   ├── icons/
│   └── sounds/
└── (legacy assets for backward compatibility)
```

### Platform-Specific Configuration

#### **Android** ([android/app/build.gradle](android/app/build.gradle))
```gradle
flavorDimensions "brand"

productFlavors {
    chaimates {
        dimension "brand"
        applicationId "com.chaimates.outlet_app"
        resValue "string", "app_name", "Chaimates Outlet"
    }

    jds_kitchen {
        dimension "brand"
        applicationId "com.saas_outlet_app.jds_kitchen"
        resValue "string", "app_name", "JD's Kitchen"
    }
}
```

#### **iOS** ([ios/Flutter/](ios/Flutter/))
- `Chaimates.xcconfig` - Chaimates iOS configuration
- `JdsKitchen.xcconfig` - JD's Kitchen iOS configuration

---

## 🎨 How It Works

### 1. **Flavor Initialization** ([lib/main.dart](lib/main.dart))
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flavor based on --dart-define=FLAVOR
  const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'chaimates');
  FlavorConfig.initialize(flavor: flavor);

  // ... rest of initialization
}
```

### 2. **Dynamic Theme** ([lib/ui/theme.dart](lib/ui/theme.dart))
The theme automatically adapts based on the current brand:
```dart
static ThemeData get lightTheme {
  final brandConfig = FlavorConfig.instance.brandConfig;
  return _buildLightTheme(
    primaryColor: brandConfig.primaryColor,
    secondaryColor: brandConfig.secondaryColor,
  );
}
```

### 3. **Dynamic API Configuration** ([lib/core/api_service.dart](lib/core/api_service.dart))
API service automatically uses the correct brand ID:
```dart
// Add brand ID header dynamically from flavor config
options.headers['X-Brand-Id'] = FlavorConfig.instance.brandConfig.brandId;
```

### 4. **Dynamic Assets**
Access brand-specific assets using:
```dart
final logoPath = FlavorConfig.instance.brandConfig.logoAssetPath;
// Returns: 'assets/chaimates/logo.png' or 'assets/jds_kitchen/logo.png'
```

---

## 🔧 Adding a New Brand

To add a new brand, follow these steps:

### 1. **Update Brand Configuration** ([lib/config/brand_config.dart](lib/config/brand_config.dart))
```dart
static const newBrand = BrandConfig(
  brandName: 'New Brand Name',
  brandId: 'your-brand-uuid-here',
  packageName: 'com.example.new_brand',
  primaryColor: Color(0xFFHEXCOD),
  secondaryColor: Color(0xFFHEXCOD),
  logoAssetPath: 'assets/new_brand/logo.png',
  baseUrl: 'http://your-api-url.com',
);
```

### 2. **Update Flavor Config** ([lib/config/flavor_config.dart](lib/config/flavor_config.dart))
```dart
switch (flavor.toLowerCase()) {
  // ... existing cases
  case 'new_brand':
    brandConfig = BrandConfig.newBrand;
    break;
}
```

### 3. **Add Android Flavor** ([android/app/build.gradle](android/app/build.gradle))
```gradle
new_brand {
    dimension "brand"
    applicationId "com.example.new_brand"
    resValue "string", "app_name", "New Brand Name"
}
```

### 4. **Add iOS Configuration**
Create `ios/Flutter/NewBrand.xcconfig`:
```
#include "Generated.xcconfig"

PRODUCT_BUNDLE_IDENTIFIER = com.example.new-brand
APP_DISPLAY_NAME = New Brand Name
```

### 5. **Create Assets Folder**
```bash
mkdir -p assets/new_brand/icons assets/new_brand/sounds
# Add logo.png and other assets
```

### 6. **Create Build Script**
```bash
cp build_chaimates.sh build_new_brand.sh
# Edit the script to use --flavor new_brand
```

---

## 📱 Output Locations

### Android APKs
```
build/app/outputs/flutter-apk/
├── app-chaimates-debug.apk
├── app-chaimates-release.apk
├── app-jds_kitchen-debug.apk
└── app-jds_kitchen-release.apk
```

### Android App Bundles
```
build/app/outputs/bundle/
├── chaimatesRelease/app-chaimates-release.aab
└── jds_kitchenRelease/app-jds_kitchen-release.aab
```

---

## 🐛 Troubleshooting

### Issue: "FlavorConfig not initialized" error
**Solution**: Make sure you're passing `--dart-define=FLAVOR=<brand_name>` when running or building.

### Issue: Assets not found
**Solution**: Run `flutter pub get` to refresh asset paths, or run `flutter clean && flutter pub get`.

### Issue: Wrong theme colors showing
**Solution**: Make sure FlavorConfig is initialized BEFORE MaterialApp is built.

### Issue: API calls using wrong brand ID
**Solution**: Verify that `FlavorConfig.initialize()` is called before `ApiService()` is instantiated.

### Issue: Build scripts not executable
**Solution**: Run `chmod +x *.sh` in the project root.

---

## 📝 Notes

- Both brands share the same codebase and only differ in configuration
- You can install both brands on the same device (different package names)
- ⚠️ **All brand assets are bundled in every APK** (Flutter limitation - see [ASSET_OPTIMIZATION.md](ASSET_OPTIMIZATION.md))
  - Only active brand's assets are loaded at runtime
  - Typical overhead: ~1-2 MB per APK (minimal impact)
- API base URL is the same for both brands; only the `X-Brand-Id` header differs
- Theme colors automatically adapt based on the selected flavor

---

## 🆘 Need Help?

If you encounter issues:
1. Run `flutter clean`
2. Run `flutter pub get`
3. Try building again with the appropriate script
4. Check that all configuration files are properly set up

For more information, see:
- [lib/config/brand_config.dart](lib/config/brand_config.dart) - Brand settings
- [lib/config/flavor_config.dart](lib/config/flavor_config.dart) - Flavor management
- [android/app/build.gradle](android/app/build.gradle) - Android configuration
