#!/bin/bash

# Build script for Chaimates brand

echo "🚀 Building Chaimates Outlet App..."

# Check if build type is provided
BUILD_TYPE=${1:-debug}

case $BUILD_TYPE in
  debug)
    echo "📱 Building DEBUG APK for Chaimates..."
    flutter build apk --flavor chaimates --dart-define=FLAVOR=chaimates --debug
    echo "✅ Debug APK built successfully!"
    echo "📦 Location: build/app/outputs/flutter-apk/app-chaimates-debug.apk"
    ;;
  release)
    echo "📱 Building RELEASE APK for Chaimates..."
    flutter build apk --flavor chaimates --dart-define=FLAVOR=chaimates --release
    echo "✅ Release APK built successfully!"
    echo "📦 Location: build/app/outputs/flutter-apk/app-chaimates-release.apk"
    ;;
  appbundle)
    echo "📱 Building RELEASE APP BUNDLE for Chaimates..."
    flutter build appbundle --flavor chaimates --dart-define=FLAVOR=chaimates --release
    echo "✅ App Bundle built successfully!"
    echo "📦 Location: build/app/outputs/bundle/chaimatesRelease/app-chaimates-release.aab"
    ;;
  ios)
    echo "📱 Building iOS for Chaimates..."
    flutter build ios --flavor chaimates --dart-define=FLAVOR=chaimates --release --no-codesign
    echo "✅ iOS build completed!"
    ;;
  *)
    echo "❌ Invalid build type. Use: debug, release, appbundle, or ios"
    exit 1
    ;;
esac

echo ""
echo "✨ Build complete for Chaimates!"
