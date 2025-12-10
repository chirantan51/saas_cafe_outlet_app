#!/bin/bash

# Enterprise-scale Flutter Multi-Brand Build Script
# Handles selective asset bundling to reduce APK size for 20+ brands

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check arguments
if [ -z "$1" ]; then
    print_error "Usage: ./build_flavor.sh <brand_flavor> [build_type]"
    echo "Examples:"
    echo "  ./build_flavor.sh chaimates debug"
    echo "  ./build_flavor.sh jds_kitchen release"
    echo "  ./build_flavor.sh chaimates appbundle"
    exit 1
fi

FLAVOR=$1
BUILD_TYPE=${2:-debug}
PUBSPEC_BACKUP="pubspec.yaml.backup"
ASSETS_BACKUP_DIR=".assets_backup"

# Validate flavor
VALID_FLAVORS=("chaimates" "jds_kitchen")
if [[ ! " ${VALID_FLAVORS[@]} " =~ " ${FLAVOR} " ]]; then
    print_error "Invalid flavor: $FLAVOR"
    print_info "Valid flavors: ${VALID_FLAVORS[*]}"
    exit 1
fi

print_info "Building for brand: $FLAVOR with type: $BUILD_TYPE"

# Function to cleanup on exit
cleanup() {
    if [ -f "$PUBSPEC_BACKUP" ]; then
        print_info "Restoring original pubspec.yaml..."
        mv "$PUBSPEC_BACKUP" pubspec.yaml
    fi

    if [ -d "$ASSETS_BACKUP_DIR" ]; then
        print_info "Restoring asset directories..."
        for brand_dir in "$ASSETS_BACKUP_DIR"/*; do
            if [ -d "$brand_dir" ]; then
                brand_name=$(basename "$brand_dir")
                rm -rf "assets/$brand_name"
                mv "$brand_dir" "assets/"
            fi
        done
        rm -rf "$ASSETS_BACKUP_DIR"
    fi
}

# Set trap to cleanup on exit (success or failure)
trap cleanup EXIT

# Step 1: Backup pubspec.yaml
print_info "Backing up pubspec.yaml..."
cp pubspec.yaml "$PUBSPEC_BACKUP"

# Step 2: Backup and temporarily remove other brand assets
print_info "Temporarily removing other brand assets..."
mkdir -p "$ASSETS_BACKUP_DIR"

for brand_dir in assets/*/; do
    brand_name=$(basename "$brand_dir")
    if [ "$brand_name" != "$FLAVOR" ] && [ "$brand_name" != "icons" ] && [ "$brand_name" != "sounds" ]; then
        print_info "  Moving assets/$brand_name to backup..."
        mv "assets/$brand_name" "$ASSETS_BACKUP_DIR/"
    fi
done

# Step 3: Update pubspec.yaml to only include current brand's assets
print_info "Updating pubspec.yaml for $FLAVOR only..."
python3 - <<EOF
import re

with open('pubspec.yaml', 'r') as f:
    content = f.read()

# Find the assets section and replace it
assets_section = """  assets:
    # Current brand assets only (optimized for single brand)
    - assets/$FLAVOR/
    # Legacy assets (kept for backward compatibility)
    - assets/logo.png
    - assets/icons/edit2.png
    - assets/sounds/order-alert-1.mp3
    - assets/sounds/order-alert-2.mp3"""

# Replace the assets section
pattern = r'  assets:.*?(?=\n\n|\n#|$)'
content = re.sub(pattern, assets_section, content, flags=re.DOTALL)

with open('pubspec.yaml', 'w') as f:
    f.write(content)
EOF

print_success "pubspec.yaml updated for $FLAVOR"

# Step 4: Run flutter pub get
print_info "Running flutter pub get..."
flutter pub get

# Step 5: Build based on type
case $BUILD_TYPE in
    debug)
        print_info "Building DEBUG APK for $FLAVOR..."
        flutter build apk --flavor "$FLAVOR" --dart-define=FLAVOR="$FLAVOR" --debug
        OUTPUT_PATH="build/app/outputs/flutter-apk/app-$FLAVOR-debug.apk"
        ;;
    release)
        print_info "Building RELEASE APK for $FLAVOR..."
        flutter build apk --flavor "$FLAVOR" --dart-define=FLAVOR="$FLAVOR" --release
        OUTPUT_PATH="build/app/outputs/flutter-apk/app-$FLAVOR-release.apk"
        ;;
    appbundle)
        print_info "Building RELEASE APP BUNDLE for $FLAVOR..."
        flutter build appbundle --flavor "$FLAVOR" --dart-define=FLAVOR="$FLAVOR" --release
        OUTPUT_PATH="build/app/outputs/bundle/${FLAVOR}Release/app-$FLAVOR-release.aab"
        ;;
    ios)
        print_info "Building iOS for $FLAVOR..."
        flutter build ios --flavor "$FLAVOR" --dart-define=FLAVOR="$FLAVOR" --release --no-codesign
        print_success "iOS build completed!"
        exit 0
        ;;
    *)
        print_error "Invalid build type: $BUILD_TYPE"
        print_info "Valid types: debug, release, appbundle, ios"
        exit 1
        ;;
esac

# Step 6: Display build info
if [ -f "$OUTPUT_PATH" ]; then
    FILE_SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
    print_success "Build completed successfully!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Brand:    $FLAVOR"
    print_info "Type:     $BUILD_TYPE"
    print_info "Size:     $FILE_SIZE"
    print_info "Location: $OUTPUT_PATH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    print_warning "Build completed but output file not found at expected location"
fi

# Cleanup will be called automatically by trap
