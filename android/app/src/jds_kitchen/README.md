# JD's Kitchen Flavor-Specific Files

## 📍 Location
`android/app/src/jds_kitchen/`

## 📋 Files to Place Here

### ✅ google-services.json (REQUIRED)
Download from Firebase Console for JD's Kitchen app:
- **Package name**: `com.saas_outlet_app.jds_kitchen`
- **Firebase project**: saas-food-delivery-app
- **Location**: Place directly in this directory

**File path:**
```
android/app/src/jds_kitchen/google-services.json
```

### Optional: Brand-Specific Resources

You can also place JD's Kitchen-specific resources here:
- `res/mipmap-*/ic_launcher.png` - JD's Kitchen app icon
- `res/values/colors.xml` - JD's Kitchen brand colors
- `res/values/strings.xml` - JD's Kitchen-specific strings

## 🔨 How It Works

When you build the JD's Kitchen flavor:
```bash
./build_flavor.sh jds_kitchen release
```

Gradle automatically:
1. ✅ Uses `google-services.json` from this directory
2. ✅ Merges any resources from `res/` with main resources
3. ✅ Overrides main resources if duplicates exist
4. ❌ Ignores `chaimates/` directory completely

## ⚠️ Important

- **DO NOT** place `google-services.json` in `android/app/` (root)
- **DO NOT** commit `google-services.json` to git (optional - depends on your security policy)
- Each flavor must have its own `google-services.json`
