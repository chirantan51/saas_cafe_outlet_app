#!/bin/bash

# Script to replace hardcoded Chaimates colors with theme-based colors
# Usage: ./replace_colors.sh

# Color definitions
OLD_COLOR_FULL="Color(0xFF54A079)"
OLD_COLOR_CONST="const Color(0xFF54A079)"

# Files to process
FILES=(
    "lib/ui/screens/dashboard_modern_screen.dart"
    "lib/ui/screens/dashboard_v2.dart"
    "lib/ui/screens/menu_item_screen.dart"
    "lib/ui/screens/create_order_screen.dart"
    "lib/ui/screens/subscription_create_subscription.dart"
    "lib/ui/screens/customer_management_screen.dart"
    "lib/ui/screens/dashboard_screen.dart"
    "lib/ui/screens/products_report_screen.dart"
    "lib/ui/screens/sales_report_screen.dart"
    "lib/ui/screens/reports_screen.dart"
    "lib/ui/screens/subscription_plan_detail_screen.dart"
    "lib/ui/screens/create_subscription_detail_screen.dart"
    "lib/ui/screens/subscription_subscription_detail_screen.dart"
    "lib/ui/screens/create_subscription_plan_screen.dart"
    "lib/ui/screens/delivery_settings_screen.dart"
)

echo "This script lists files that need manual replacement using Edit tool"
echo "=================================================================="
echo ""

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        count=$(grep -c "0xFF54A079\|0x[0-9A-Fa-f][0-9A-Fa-f]54A079" "$file" 2>/dev/null || echo "0")
        if [ "$count" -gt "0" ]; then
            echo "File: $file"
            echo "  Occurrences: $count"
            grep -n "0xFF54A079\|0x[0-9A-Fa-f][0-9A-Fa-f]54A079" "$file" | head -5
            echo ""
        fi
    fi
done

echo "=================================================================="
echo "Summary: Use Edit tool to replace each occurrence manually"
