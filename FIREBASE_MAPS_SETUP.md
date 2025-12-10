# Firebase & Google Maps Setup Guide for Multi-Brand App

## 📋 Overview

This guide will help you set up Firebase (for notifications) and Google Maps API keys for both brand flavors:
- **Chaimates** (`com.saas_outlet_app.chaimates`)
- **JD's Kitchen** (`com.saas_outlet_app.jds_kitchen`)

---

## 🔥 Part 1: Firebase Setup (FCM Notifications)

### Debug SHA-1 Fingerprint
Your debug SHA-1: `6C:FE:24:F1:8D:36:9A:75:5B:BC:1D:1B:E3:3E:C8:55:60:58:62:B2`

### Step 1: Chaimates Firebase App

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Open project: **saas-food-delivery-app**
3. Click **Add app** → Select **Android**
4. Enter:
   - **Package name**: `com.saas_outlet_app.chaimates`
   - **App nickname**: `Chaimates Outlet`
   - **SHA-1**: `6C:FE:24:F1:8D:36:9A:75:5B:BC:1D:1B:E3:3E:C8:55:60:58:62:B2`
5. Click **Register app**
6. **Download `google-services.json`**
7. Save to: `android/app/src/chaimates/google-services.json`

### Step 2: JD's Kitchen Firebase App

1. Same Firebase project: **saas-food-delivery-app**
2. Click **Add app** → Select **Android**
3. Enter:
   - **Package name**: `com.saas_outlet_app.jds_kitchen`
   - **App nickname**: `JD's Kitchen`
   - **SHA-1**: `6C:FE:24:F1:8D:36:9A:75:5B:BC:1D:1B:E3:3E:C8:55:60:58:62:B2`
4. Click **Register app**
5. **Download `google-services.json`**
6. Save to: `android/app/src/jds_kitchen/google-services.json`

### Step 3: Enable Firebase Plugin

In `android/app/build.gradle`, uncomment line 6:

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id "com.google.gms.google-services"  // ← Uncomment this line
}
```

### Expected File Structure:
```
android/app/
├── src/
│   ├── main/
│   │   └── AndroidManifest.xml
│   ├── chaimates/
│   │   └── google-services.json          ← Chaimates Firebase config
│   └── jds_kitchen/
│       └── google-services.json          ← JD's Kitchen Firebase config
```

---

## 🗺️ Part 2: Google Maps API Keys Setup

### Step 1: Create Chaimates Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **API Key**
5. Click **Restrict Key** and configure:

   **Key Configuration:**
   - **Name**: `Chaimates Outlet - Android Maps`
   - **Application restrictions**:
     - Select **Android apps**
     - Click **Add an item**:
       - Package name: `com.saas_outlet_app.chaimates`
       - SHA-1: `6C:FE:24:F1:8D:36:9A:75:5B:BC:1D:1B:E3:3E:C8:55:60:58:62:B2`
   - **API restrictions**:
     - Select **Restrict key**
     - Enable:
       - ✅ Maps SDK for Android
       - ✅ Places API
       - ✅ Geocoding API

6. Click **Save**
7. **Copy the API key**

### Step 2: Create JD's Kitchen Maps API Key

1. Click **Create Credentials** → **API Key**
2. Click **Restrict Key** and configure:

   **Key Configuration:**
   - **Name**: `JD's Kitchen - Android Maps`
   - **Application restrictions**:
     - Select **Android apps**
     - Click **Add an item**:
       - Package name: `com.saas_outlet_app.jds_kitchen`
       - SHA-1: `6C:FE:24:F1:8D:36:9A:75:5B:BC:1D:1B:E3:3E:C8:55:60:58:62:B2`
   - **API restrictions**:
     - Select **Restrict key**
     - Enable:
       - ✅ Maps SDK for Android
       - ✅ Places API
       - ✅ Geocoding API

3. Click **Save**
4. **Copy the API key**

### Step 3: Configure local.properties

1. Copy the template:
   ```bash
   cp android/local.properties.template android/local.properties
   ```

2. Edit `android/local.properties` and add your API keys:
   ```properties
   CHAIMATES_MAPS_API_KEY=your_chaimates_api_key_here
   JDS_KITCHEN_MAPS_API_KEY=your_jds_kitchen_api_key_here
   ```

3. **DO NOT commit `local.properties` to git** (it's already in .gitignore)

---

## ✅ Verification Checklist

### Firebase (Notifications):
- [ ] Created Chaimates Firebase app with package `com.saas_outlet_app.chaimates`
- [ ] Downloaded and placed `google-services.json` in `android/app/src/chaimates/`
- [ ] Created JD's Kitchen Firebase app with package `com.saas_outlet_app.jds_kitchen`
- [ ] Downloaded and placed `google-services.json` in `android/app/src/jds_kitchen/`
- [ ] Uncommented Firebase plugin in `android/app/build.gradle`

### Google Maps:
- [ ] Created Chaimates Maps API key (restricted to package)
- [ ] Created JD's Kitchen Maps API key (restricted to package)
- [ ] Added both API keys to `android/local.properties`
- [ ] Verified `local.properties` is in `.gitignore`

### Testing:
- [ ] Build Chaimates flavor: `./build_flavor.sh chaimates debug`
- [ ] Build JD's Kitchen flavor: `./build_flavor.sh jds_kitchen debug`
- [ ] Test notifications on Chaimates
- [ ] Test notifications on JD's Kitchen
- [ ] Test Google Maps on both flavors

---

## 🧪 Test Commands

```bash
# Run Chaimates
./run_app.sh chaimates

# Run JD's Kitchen
./run_app.sh jds_kitchen

# Build Chaimates APK
./build_flavor.sh chaimates release

# Build JD's Kitchen APK
./build_flavor.sh jds_kitchen release
```

---

## 🔐 Security Notes

1. **Never commit**:
   - `android/local.properties` (contains API keys)
   - `android/app/src/*/google-services.json` (optional - can be committed but be careful)

2. **API Key Restrictions**:
   - Always restrict API keys to specific package names
   - Add SHA-1 fingerprints for additional security
   - Use separate keys for debug and release builds (optional)

3. **Firebase Security**:
   - Each brand has its own Firebase app
   - FCM tokens are tied to package names
   - Can't send notifications across brands

---

## 📞 Support

If you encounter issues:
1. Check that package names match exactly
2. Verify SHA-1 fingerprints are correct
3. Ensure API keys are properly restricted
4. Check that `google-services.json` files are in correct locations
5. Run `flutter clean && flutter pub get`
6. Rebuild the app

---

## 📝 Notes

- For production builds, get the release SHA-1 from your release keystore
- Consider using environment variables for CI/CD pipelines
- Both brands share the same Firebase project but have separate apps
- Maps API keys should be different for each brand for better tracking and security

---
---

# iOS Multi-Brand Setup Guide
## Firebase Configuration & Flavor Support for iOS

This section covers setting up iOS flavors (Chaimates and JD's Kitchen) with separate Firebase configurations.

---

## Part 1: Configure iOS Schemes in Xcode (Manual Steps)

### Step 1: Open Xcode Workspace
```bash
open ios/Runner.xcworkspace
```

Wait for Xcode to open and load the workspace.

### Step 2: Create Build Configurations

1. In Xcode, click on the **Runner** project (blue icon at the top left)
2. Select the **Runner** PROJECT (not target) in the middle panel  
3. Click the **Info** tab
4. Under **Configurations**, you'll see: Debug, Release, Profile

**Duplicate for Chaimates:**
- Click **+** below Configurations → Duplicate "Debug" Configuration → Name: **Chaimates-Debug**
- Click **+** → Duplicate "Release" → Name: **Chaimates-Release**  
- Click **+** → Duplicate "Profile" → Name: **Chaimates-Profile**

**Duplicate for JD's Kitchen:**
- Click **+** → Duplicate "Debug" → Name: **JdsKitchen-Debug**
- Click **+** → Duplicate "Release" → Name: **JdsKitchen-Release**
- Click **+** → Duplicate "Profile" → Name: **JdsKitchen-Profile**

### Step 3: Assign Configuration Files

Still in **Info** tab, for each configuration row, set the configuration file:

| Configuration | Configuration File | Pods File |
|--------------|-------------------|-----------|
| Chaimates-Debug | Chaimates-Debug | Pods-Runner.debug |
| Chaimates-Release | Chaimates-Release | Pods-Runner.release |
| Chaimates-Profile | Chaimates-Release | Pods-Runner.release |
| JdsKitchen-Debug | JdsKitchen-Debug | Pods-Runner.debug |
| JdsKitchen-Release | JdsKitchen-Release | Pods-Runner.release |
| JdsKitchen-Profile | JdsKitchen-Release | Pods-Runner.release |

**Note**: The configuration files (Chaimates-Debug.xcconfig, etc.) have already been created in `ios/Flutter/` folder.

### Step 4: Create Schemes

1. Xcode menu: **Product** → **Scheme** → **Manage Schemes...**

**Create Chaimates Scheme:**
1. Click **+** button
2. Target: **Runner**, Name: **Chaimates**
3. Click **OK**, then select **Chaimates** and click **Edit**
4. Set configurations for each action:
   - **Run**: Chaimates-Debug
   - **Test**: Chaimates-Debug
   - **Profile**: Chaimates-Profile
   - **Analyze**: Chaimates-Debug
   - **Archive**: Chaimates-Release
5. Click **Close**

**Create JdsKitchen Scheme:**
1. Click **+** button
2. Target: **Runner**, Name: **JdsKitchen**
3. Click **OK**, then select **JdsKitchen** and click **Edit**
4. Set configurations:
   - **Run**: JdsKitchen-Debug
   - **Test**: JdsKitchen-Debug
   - **Profile**: JdsKitchen-Profile
   - **Analyze**: JdsKitchen-Debug
   - **Archive**: JdsKitchen-Release
5. Click **Close**

✅ **Xcode configuration complete!**

---

## Part 2: Firebase Setup for iOS

### Step 5: Add iOS Apps in Firebase Console

#### Add Chaimates iOS App:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **saas-food-delivery-app**
3. Click ⚙️ → **Project Settings**
4. Scroll to "Your apps"
5. Click **+ Add app** → Select **iOS** (Apple icon)
6. Fill in details:
   - **iOS bundle ID**: `com.saas_outlet_app.chaimates`
   - **App nickname**: `Chaimates Outlet iOS`
   - **App Store ID**: (leave blank)
7. Click **Register app**
8. **Download `GoogleService-Info.plist`**
9. Save it as: `GoogleService-Info-Chaimates.plist` to your **Downloads** folder
10. Complete remaining steps (or skip for now)

#### Add JD's Kitchen iOS App:

1. In same Firebase project, click **+ Add app** → **iOS**
2. Fill in:
   - **iOS bundle ID**: `com.saas_outlet_app.jds_kitchen`
   - **App nickname**: `JD's Kitchen iOS`
3. Click **Register app**
4. **Download `GoogleService-Info.plist`**
5. Save as: `GoogleService-Info-JdsKitchen.plist` to **Downloads**

### Step 6: Copy Firebase Config Files

Once you have both files downloaded, run these commands:

```bash
# Copy Chaimates config
cp ~/Downloads/GoogleService-Info-Chaimates.plist /Users/chirantan/Applications/outlet_app/ios/Runner/GoogleService-Info-Chaimates.plist

# Copy JD's Kitchen config
cp ~/Downloads/GoogleService-Info-JdsKitchen.plist /Users/chirantan/Applications/outlet_app/ios/Runner/GoogleService-Info-JdsKitchen.plist
```

Or tell me when you've downloaded them and I'll copy them for you.

### Step 7: Add Firebase Files to Xcode

1. In Xcode, right-click **Runner** folder (yellow)
2. **Add Files to "Runner"...**
3. Navigate to `ios/Runner/`
4. Select BOTH:
   - `GoogleService-Info-Chaimates.plist`
   - `GoogleService-Info-JdsKitchen.plist`
5. ✅ Check "Copy items if needed"
6. ✅ Add to target: **Runner**
7. Click **Add**

### Step 8: Add Build Script to Copy Correct Firebase Config

1. In Xcode, select **Runner** TARGET (not project)
2. Go to **Build Phases** tab
3. Click **+** → **New Run Script Phase**
4. **Drag** the new script phase to be **BEFORE** "Copy Bundle Resources"
5. Expand the Run Script
6. Name it: **"Copy Firebase Config"**
7. Paste this script:

```bash
# Select correct GoogleService-Info.plist based on build configuration
if [[ "${CONFIGURATION}" == *"Chaimates"* ]]; then
    echo "✅ Using Chaimates Firebase configuration"
    cp -f "${SRCROOT}/Runner/GoogleService-Info-Chaimates.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
elif [[ "${CONFIGURATION}" == *"JdsKitchen"* ]]; then
    echo "✅ Using JD's Kitchen Firebase configuration"
    cp -f "${SRCROOT}/Runner/GoogleService-Info-JdsKitchen.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
else
    echo "⚠️ Using default (Chaimates) Firebase configuration"
    cp -f "${SRCROOT}/Runner/GoogleService-Info-Chaimates.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
fi
```

✅ **Firebase configuration complete!**

---

## Part 3: Testing

### Clean and Rebuild

```bash
cd /Users/chirantan/Applications/outlet_app
flutter clean
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### Test Chaimates on iOS Simulator

```bash
# List available simulators
flutter devices

# Run Chaimates
flutter run --flavor chaimates -d <simulator-id>

# Or if you have iPhone 15 Pro:
flutter run --flavor chaimates -d 0F7E212F-6D30-4B83-9102-00179D7130AF
```

### Test JD's Kitchen on iOS Simulator

```bash
flutter run --flavor jds_kitchen -d <simulator-id>
```

### Verify Bundle IDs

```bash
# Check Chaimates bundle ID
flutter build ios --flavor chaimates --debug --no-codesign
# Should show: com.saas_outlet_app.chaimates

# Check JD's Kitchen bundle ID  
flutter build ios --flavor jds_kitchen --debug --no-codesign
# Should show: com.saas_outlet_app.jds_kitchen
```

---

## Summary of iOS Files Created

✅ **Configuration Files** (in `ios/Flutter/`):
- `Chaimates-Debug.xcconfig` - Bundle ID: com.saas_outlet_app.chaimates
- `Chaimates-Release.xcconfig`
- `JdsKitchen-Debug.xcconfig` - Bundle ID: com.saas_outlet_app.jds_kitchen
- `JdsKitchen-Release.xcconfig`

✅ **Firebase Config Files** (in `ios/Runner/`):
- `GoogleService-Info-Chaimates.plist` - Chaimates Firebase app
- `GoogleService-Info-JdsKitchen.plist` - JD's Kitchen Firebase app

✅ **Xcode Schemes**:
- Chaimates (uses Chaimates-* configurations)
- JdsKitchen (uses JdsKitchen-* configurations)

---

## Checklist

- [ ] Opened Xcode workspace
- [ ] Created 6 build configurations (3 for each flavor)
- [ ] Assigned xcconfig files to configurations
- [ ] Created Chaimates scheme
- [ ] Created JdsKitchen scheme
- [ ] Added Chaimates iOS app to Firebase Console
- [ ] Downloaded GoogleService-Info-Chaimates.plist
- [ ] Added JD's Kitchen iOS app to Firebase Console
- [ ] Downloaded GoogleService-Info-JdsKitchen.plist
- [ ] Copied both .plist files to ios/Runner/
- [ ] Added both files to Xcode project
- [ ] Added "Copy Firebase Config" build script
- [ ] Ran pod install
- [ ] Tested Chaimates flavor
- [ ] Tested JD's Kitchen flavor

---

## Troubleshooting

**"The Xcode project does not define custom schemes"**
- Make sure you created the schemes in Xcode (Step 4)
- Verify schemes are checked as "Shared" in Manage Schemes

**"Firebase not initialized"**
- Check build output for "Using [Brand] Firebase configuration"
- Verify .plist files are in ios/Runner/
- Ensure build script is running BEFORE Copy Bundle Resources

**Pod install fails**
- Update CocoaPods: `sudo gem install cocoapods`
- Clean and retry: `rm -rf Pods Podfile.lock && pod install`

**Wrong bundle ID showing**
- Check the scheme selected in Xcode
- Verify xcconfig file assignments in Build Settings
- Make sure you're using `--flavor` flag when building

---

## Next Steps

After completing iOS setup:

1. ✅ Both iOS flavors (Chaimates & JD's Kitchen) have separate bundle IDs
2. ✅ Each flavor uses its own Firebase configuration  
3. ✅ Can build and run: `flutter run --flavor chaimates` or `--flavor jds_kitchen`
4. ✅ Ready for App Store submission (each flavor as separate app)
5. 🎯 Configure push notifications for each Firebase app
6. 🎯 Set up Google Maps API keys for iOS (if needed)

