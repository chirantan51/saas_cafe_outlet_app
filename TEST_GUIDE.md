# Testing Multi-Brand Setup (Step by Step)

This guide will help you test the multi-brand setup with 2 brands first.

---

## ✅ **Current Status**

- ✅ Python 3.12.6 installed (no need to install)
- ✅ 2 brands configured: Chaimates, JD's Kitchen
- ✅ Android flavors already in place
- ✅ Build scripts ready

---

## 🧪 **Test Steps**

### **Step 1: Verify Configuration Files**

Check that everything is in place:

```bash
cd /Users/chirantan/Applications/outlet_app

# Check if config files exist
ls -la brands_config.json
ls -la generate_brand_configs.py
ls -la build_flavor.sh
```

Expected output:
```
-rw-r--r-- brands_config.json
-rwxr-xr-x generate_brand_configs.py
-rwxr-xr-x build_flavor.sh
```

---

### **Step 2: Run Configuration Generator (Optional for Testing)**

Since your 2 brands are already configured, this step is **optional**. But you can run it to see how it works:

```bash
# Run from project root
./generate_brand_configs.py
```

**Expected Output:**
```
🚀 Enterprise Multi-Brand Configuration Generator
============================================================

📊 Found 2 active brands out of 2 total

📝 Generating configurations...
✅ Generated /Users/chirantan/Applications/outlet_app/lib/config/brand_config.dart
✅ Generated /Users/chirantan/Applications/outlet_app/lib/config/flavor_config.dart

📱 Android Product Flavors (add to android/app/build.gradle):
============================================================
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
============================================================
✅ Generated ios/Flutter/Chaimates.xcconfig
✅ Generated ios/Flutter/JdsKitchen.xcconfig
✅ Generated build_chaimates.sh
✅ Generated build_jds_kitchen.sh
✅ Created asset directory: assets/chaimates
✅ Created asset directory: assets/jds_kitchen

============================================================
✅ All configurations generated successfully!
============================================================
```

---

### **Step 3: Test Build - Chaimates (Debug)**

Test building Chaimates brand:

```bash
# Using optimized script
./build_flavor.sh chaimates debug
```

**What happens:**
1. Script backs up `pubspec.yaml`
2. Temporarily moves `jds_kitchen` assets
3. Updates `pubspec.yaml` to only include Chaimates assets
4. Builds APK
5. Restores everything

**Expected Output:**
```
ℹ️  Building for brand: chaimates with type: debug
ℹ️  Backing up pubspec.yaml...
ℹ️  Temporarily removing other brand assets...
ℹ️  Updating pubspec.yaml for chaimates only...
✅ pubspec.yaml updated for chaimates
ℹ️  Running flutter pub get...
ℹ️  Building DEBUG APK for chaimates...
✅ Build completed successfully!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️  Brand:    chaimates
ℹ️  Type:     debug
ℹ️  Size:     ~18M
ℹ️  Location: build/app/outputs/flutter-apk/app-chaimates-debug.apk
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### **Step 4: Test Build - JD's Kitchen (Debug)**

Test building JD's Kitchen brand:

```bash
./build_flavor.sh jds_kitchen debug
```

**Expected Output:**
```
ℹ️  Building for brand: jds_kitchen with type: debug
...
✅ Build completed successfully!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️  Brand:    jds_kitchen
ℹ️  Type:     debug
ℹ️  Size:     ~18M
ℹ️  Location: build/app/outputs/flutter-apk/app-jds_kitchen-debug.apk
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### **Step 5: Verify APKs Were Created**

Check that both APKs exist:

```bash
ls -lh build/app/outputs/flutter-apk/app-*-debug.apk
```

**Expected Output:**
```
-rw-r--r-- app-chaimates-debug.apk
-rw-r--r-- app-jds_kitchen-debug.apk
```

---

### **Step 6: Test Run App**

Run each brand on device/emulator:

```bash
# Run Chaimates
./run_app.sh chaimates

# Or run JD's Kitchen
./run_app.sh jds_kitchen
```

**What to verify:**
- ✅ App name matches brand (Chaimates Outlet vs JD's Kitchen)
- ✅ Theme color is correct (Green for Chaimates, Blue for JD's Kitchen)
- ✅ Logo is correct
- ✅ API calls send correct Brand-ID header

---

### **Step 7: Install Both APKs (Optional)**

Since they have different package names, you can install both:

```bash
# Install Chaimates
adb install build/app/outputs/flutter-apk/app-chaimates-debug.apk

# Install JD's Kitchen
adb install build/app/outputs/flutter-apk/app-jds_kitchen-debug.apk
```

Both apps will appear separately on your device!

---

## 🐛 **Troubleshooting**

### **Error: Permission denied**

```bash
chmod +x generate_brand_configs.py build_flavor.sh
```

### **Error: Python not found**

Should not happen (you have Python 3.12.6), but if it does:
```bash
python3 ./generate_brand_configs.py
```

### **Error: Build script fails**

The script automatically restores files. If it doesn't:
```bash
# Manually restore
mv pubspec.yaml.backup pubspec.yaml
mv .assets_backup/* assets/
rm -rf .assets_backup
flutter pub get
```

### **Error: flutter command not found**

Make sure Flutter is in your PATH:
```bash
flutter doctor
```

---

## 📊 **Success Criteria**

After completing all steps, you should have:

- ✅ Two separate APKs built successfully
- ✅ Different package names (can install both simultaneously)
- ✅ Different app names displayed
- ✅ Different theme colors
- ✅ Correct Brand-ID sent in API calls
- ✅ APK size around 18-20 MB (not 45 MB)

---

## 🎯 **Next Steps After Testing**

Once you've verified everything works with 2 brands:

1. **Add remaining 6+ brands** to `brands_config.json`
2. **Run generator** to create all configs
3. **Update Android flavors** in `build.gradle` (copy from script output)
4. **Add brand assets** (logos, icons) to respective folders
5. **Build all brands** using the optimized script

---

## 📝 **Notes**

- The Android flavors are **already configured** for your 2 test brands
- The script is **safe** - it always restores original files
- You can run builds **multiple times** - it won't corrupt anything
- Each build is **independent** - other brands' builds won't be affected

---

## 🆘 **If You Get Stuck**

1. Check this file: [ENTERPRISE_MULTI_BRAND.md](ENTERPRISE_MULTI_BRAND.md)
2. Check logs in terminal for specific error
3. Run `flutter clean && flutter pub get`
4. Try the simple build first: `./build_chaimates.sh debug`
