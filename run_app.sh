#!/bin/bash

# Script to run the app with a specific brand flavor

echo "🚀 Running Outlet App..."

# Check if brand is provided
BRAND=${1:-chaimates}

case $BRAND in
  chaimates)
    echo "📱 Running Chaimates Outlet..."
    flutter run --flavor chaimates --dart-define=FLAVOR=chaimates
    ;;
  jds_kitchen|jds|jdskitchen)
    echo "📱 Running JD's Kitchen..."
    flutter run --flavor jds_kitchen --dart-define=FLAVOR=jds_kitchen
    ;;
  *)
    echo "❌ Invalid brand. Use: chaimates or jds_kitchen"
    exit 1
    ;;
esac
