# Chaimates Flavor-Specific Files

## 📍 Location
`android/app/src/chaimates/`

## 📋 Files to Place Here

### ✅ google-services.json (REQUIRED)
Download from Firebase Console for Chaimates app:
- **Package name**: `com.saas_outlet_app.chaimates`
- **Firebase project**: saas-food-delivery-app
- **Location**: Place directly in this directory

**File path:**
```
android/app/src/chaimates/google-services.json
```

### Optional: Brand-Specific Resources

You can also place Chaimates-specific resources here:
- `res/mipmap-*/ic_launcher.png` - Chaimates app icon
- `res/values/colors.xml` - Chaimates brand colors
- `res/values/strings.xml` - Chaimates-specific strings

## 🔨 How It Works

When you build the Chaimates flavor:
```bash
./build_flavor.sh chaimates release
```

Gradle automatically:
1. ✅ Uses `google-services.json` from this directory
2. ✅ Merges any resources from `res/` with main resources
3. ✅ Overrides main resources if duplicates exist
4. ❌ Ignores `jds_kitchen/` directory completely

## ⚠️ Important

- **DO NOT** place `google-services.json` in `android/app/` (root)
- **DO NOT** commit `google-services.json` to git (optional - depends on your security policy)
- Each flavor must have its own `google-services.json`
