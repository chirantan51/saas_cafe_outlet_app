# Asset Optimization Guide

## ⚠️ Current Limitation

**All brand assets are bundled into every APK**, regardless of which flavor is built. This is a Flutter framework limitation - the `pubspec.yaml` doesn't support conditional asset inclusion per flavor.

### Impact:
- ✅ Chaimates APK contains both Chaimates AND JD's Kitchen assets
- ✅ JD's Kitchen APK contains both Chaimates AND JD's Kitchen assets
- ⚠️ Slightly larger app size (~few hundred KB depending on assets)

---

## 🔍 Why This Happens

Flutter's asset bundling happens **before** flavor-specific build steps run. The `pubspec.yaml` is processed once for all flavors, so all declared assets are included in every build.

---

## 💡 Solutions to Reduce App Size

### **Option 1: Manual Asset Filtering (Complex)**

Create a build script that modifies `pubspec.yaml` before each build:

```bash
# Before building Chaimates
sed -i '' '/jds_kitchen/d' pubspec.yaml
flutter build apk --flavor chaimates

# Restore pubspec.yaml
git checkout pubspec.yaml
```

**Pros:** Smaller APK size
**Cons:** Complex, error-prone, breaks version control

---

### **Option 2: Native Asset Variants (Android Only)**

Use Android's native `src/<flavor>/assets` structure:

```
android/app/src/
├── chaimates/assets/
│   └── flutter_assets/
│       └── assets/chaimates/
└── jds_kitchen/assets/
    └── flutter_assets/
        └── assets/jds_kitchen/
```

**Pros:** Android builds only include relevant assets
**Cons:** Complex setup, doesn't work for iOS

---

### **Option 3: Accept Current Approach (Recommended)**

Keep all assets in both builds and optimize where it matters:

#### **Minimal Impact Because:**
1. **Small Asset Sizes**: Typical logo + icons + sounds = ~500KB-2MB total
2. **Compressed in APK**: Assets are compressed in the APK bundle
3. **Fast Loading**: Only active brand's assets are loaded at runtime
4. **Simpler Maintenance**: No complex build scripts needed

#### **Optimize What Matters More:**
- ✅ Reduce image sizes (use WebP format)
- ✅ Enable ProGuard for release builds
- ✅ Use `flutter build appbundle` for Play Store (reduces download size)
- ✅ Remove unused dependencies

---

## 📊 Typical Asset Breakdown

| Asset Type | Size per Brand | Both Brands Total |
|------------|----------------|-------------------|
| Logo (PNG) | 50-200 KB | 100-400 KB |
| Icons | 10-50 KB | 20-100 KB |
| Sounds | 50-500 KB | 100-1 MB |
| **Total** | ~110-750 KB | **~220 KB-1.5 MB** |

**Compared to a typical Flutter app:** 15-30 MB
**Impact:** Less than 10% increase

---

## ✅ Recommended Approach

**Keep the current setup** because:

1. ✅ **Simplicity**: Easy to maintain and understand
2. ✅ **Minimal Impact**: Asset overhead is small (<2MB for both brands)
3. ✅ **No Build Complexity**: No custom scripts or fragile build processes
4. ✅ **Cross-Platform**: Works identically on Android and iOS
5. ✅ **Runtime Efficiency**: Only active brand's assets are loaded into memory

---

## 🚀 Future Optimization (If Needed)

If app size becomes a concern later (e.g., >10 brands), consider:

1. **Asset CDN**: Download brand assets on first launch
2. **Separate Apps**: Publish completely separate apps per brand
3. **Custom Build Pipeline**: Implement automated asset filtering

---

## 📝 Current Status

- ✅ All assets declared in `pubspec.yaml`
- ✅ Runtime uses only active brand's assets via `FlavorConfig.instance.brandConfig.logoAssetPath`
- ✅ No memory waste (unused assets aren't loaded)
- ⚠️ Small disk space overhead in APK (~1-2 MB total)

**Conclusion:** Current approach is optimal for 2-5 brands. No action needed.
