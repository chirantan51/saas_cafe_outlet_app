# Quick Reference Card 🚀

## 🏢 **Enterprise Scale (20+ Brands)**

### **Optimized Build (Recommended for 20+ brands)**
```bash
# Uses selective asset bundling - only includes current brand's assets
./build_flavor.sh <brand> <type>

# Examples:
./build_flavor.sh chaimates release
./build_flavor.sh jds_kitchen debug
./build_flavor.sh brand3 appbundle
```

### **Add New Brand (Automated)**
```bash
# 1. Edit brands_config.json to add new brand
# 2. Run generator:
./generate_brand_configs.py
# 3. Build:
./build_flavor.sh new_brand release
```

See [ENTERPRISE_MULTI_BRAND.md](ENTERPRISE_MULTI_BRAND.md) for full enterprise guide.

---

## Build Commands Cheat Sheet

### 🏃 Run App (Development)
```bash
# Chaimates
./run_app.sh chaimates

# JD's Kitchen
./run_app.sh jds_kitchen
```

### 📱 Build APK (Debug)
```bash
# Chaimates
./build_chaimates.sh debug

# JD's Kitchen
./build_jds_kitchen.sh debug
```

### 🚢 Build APK (Release)
```bash
# Chaimates
./build_chaimates.sh release

# JD's Kitchen
./build_jds_kitchen.sh release
```

### 📦 Build App Bundle (Play Store)
```bash
# Chaimates
./build_chaimates.sh appbundle

# JD's Kitchen
./build_jds_kitchen.sh appbundle
```

### 🍎 Build iOS
```bash
# Chaimates
./build_chaimates.sh ios

# JD's Kitchen
./build_jds_kitchen.sh ios
```

---

## 🎨 Brand Details

| Brand | Package Name | Brand ID | Primary Color | App Name |
|-------|--------------|----------|---------------|----------|
| **Chaimates** | com.chaimates.outlet_app | 38a8915e-c484-11f0-9212-ea148faff773 | #54A079 | Chaimates Outlet |
| **JD's Kitchen** | com.saas_outlet_app.jds_kitchen | 38a8915ec48411f09212ea148faff773 | #144c9f | JD's Kitchen |

---

## 📂 Key Files

| File | Purpose |
|------|---------|
| [lib/config/brand_config.dart](lib/config/brand_config.dart) | Brand configuration (colors, IDs, names) |
| [lib/config/flavor_config.dart](lib/config/flavor_config.dart) | Flavor management |
| [lib/core/api_service.dart](lib/core/api_service.dart) | API service with dynamic brand ID |
| [lib/ui/theme.dart](lib/ui/theme.dart) | Dynamic theme system |
| [android/app/build.gradle](android/app/build.gradle) | Android flavors |
| [assets/chaimates/](assets/chaimates/) | Chaimates assets |
| [assets/jds_kitchen/](assets/jds_kitchen/) | JD's Kitchen assets |

---

## 🛠️ Troubleshooting

```bash
# Clean build
flutter clean && flutter pub get

# Check installed packages
flutter pub get

# Run with verbose logging
flutter run --flavor chaimates --dart-define=FLAVOR=chaimates -v
```

---

## 📝 Adding New Brand

1. Update [lib/config/brand_config.dart](lib/config/brand_config.dart)
2. Update [lib/config/flavor_config.dart](lib/config/flavor_config.dart)
3. Add flavor to [android/app/build.gradle](android/app/build.gradle)
4. Create `ios/Flutter/YourBrand.xcconfig`
5. Create `assets/your_brand/` folder
6. Copy and modify build script

See [MULTI_BRAND_SETUP.md](MULTI_BRAND_SETUP.md) for detailed instructions.
