#!/bin/bash

# Build script for JD's Kitchen brand

echo "🚀 Building JD's Kitchen App..."

# Check if build type is provided
BUILD_TYPE=${1:-debug}

case $BUILD_TYPE in
  debug)
    echo "📱 Building DEBUG APK for JD's Kitchen..."
    flutter build apk --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen --debug
    echo "✅ Debug APK built successfully!"
    echo "📦 Location: build/app/outputs/flutter-apk/app-jds_kitchen-debug.apk"
    ;;
  release)
    echo "📱 Building RELEASE APK for JD's Kitchen..."
    flutter build apk --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen --release
    echo "✅ Release APK built successfully!"
    echo "📦 Location: build/app/outputs/flutter-apk/app-jds_kitchen-release.apk"
    ;;
  appbundle)
    echo "📱 Building RELEASE APP BUNDLE for JD's Kitchen..."
    flutter build appbundle --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen --release
    echo "✅ App Bundle built successfully!"
    echo "📦 Location: build/app/outputs/bundle/jds_kitchenRelease/app-jds_kitchen-release.aab"
    ;;
  ios)
    echo "📱 Building iOS for JD's Kitchen..."
    flutter build ios --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen --release --no-codesign
    echo "✅ iOS build completed!"
    ;;
  *)
    echo "❌ Invalid build type. Use: debug, release, appbundle, or ios"
    exit 1
    ;;
esac

echo ""
echo "✨ Build complete for JD's Kitchen!"
