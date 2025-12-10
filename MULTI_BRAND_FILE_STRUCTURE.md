# Multi-Brand File Structure Guide

## 📁 Complete Project Structure

```
outlet_app/
│
├── android/
│   └── app/
│       ├── build.gradle                          ← Flavor configuration
│       └── src/
│           ├── main/                             ← SHARED files (all brands)
│           │   ├── AndroidManifest.xml
│           │   ├── kotlin/
│           │   │   └── MainActivity.kt
│           │   └── res/
│           │       ├── mipmap-*/
│           │       ├── values/
│           │       └── drawable/
│           │
│           ├── chaimates/                        ← CHAIMATES-ONLY files
│           │   ├── google-services.json          ← 🔥 Chaimates Firebase
│           │   ├── README.md
│           │   └── res/                          ← (Optional) Chaimates resources
│           │       ├── mipmap-*/ic_launcher.png  ← Chaimates app icon
│           │       └── values/
│           │           ├── colors.xml            ← Chaimates colors
│           │           └── strings.xml           ← Chaimates strings
│           │
│           └── jds_kitchen/                      ← JD'S KITCHEN-ONLY files
│               ├── google-services.json          ← 🔥 JD's Kitchen Firebase
│               ├── README.md
│               └── res/                          ← (Optional) JD's resources
│                   ├── mipmap-*/ic_launcher.png  ← JD's app icon
│                   └── values/
│                       ├── colors.xml            ← JD's colors
│                       └── strings.xml           ← JD's strings
│
├── ios/
│   └── Flutter/
│       ├── Chaimates.xcconfig                    ← Chaimates iOS config
│       └── JdsKitchen.xcconfig                   ← JD's Kitchen iOS config
│
├── lib/
│   ├── config/
│   │   ├── brand_config.dart                     ← Brand configurations
│   │   └── flavor_config.dart                    ← Flavor management
│   │
│   ├── core/
│   │   └── api_service.dart                      ← Auto X-Brand-Id injection
│   │
│   └── main.dart                                 ← Flavor initialization
│
├── assets/
│   ├── chaimates/                                ← Chaimates Flutter assets
│   │   ├── logo.png
│   │   └── ...
│   │
│   └── jds_kitchen/                              ← JD's Kitchen Flutter assets
│       ├── logo.png
│       └── ...
│
├── brands_config.json                            ← Brand metadata
│
└── Build Scripts:
    ├── build_flavor.sh                           ← Universal build script
    ├── build_chaimates.sh                        ← Chaimates build
    ├── build_jds_kitchen.sh                      ← JD's Kitchen build
    └── run_app.sh                                ← Run specific flavor
```

---

## 🔥 Firebase Configuration Files

### File Locations (CRITICAL):

```
❌ WRONG - DO NOT DO THIS:
android/app/google-services.json                 ← Will cause conflicts!

✅ CORRECT - DO THIS:
android/app/src/chaimates/google-services.json   ← Chaimates Firebase
android/app/src/jds_kitchen/google-services.json ← JD's Kitchen Firebase
```

---

## 🔨 How Gradle Merges Files

### When building Chaimates:
```bash
./build_flavor.sh chaimates release
```

**Gradle Source Sets (in order of priority):**
1. `android/app/src/chaimates/`         ← HIGHEST priority
2. `android/app/src/main/`              ← Base files

**Result:**
- ✅ Uses `chaimates/google-services.json`
- ✅ Uses `chaimates/res/` resources (if exist)
- ✅ Falls back to `main/res/` for common resources
- ✅ Package ID: `com.saas_outlet_app.chaimates`

---

### When building JD's Kitchen:
```bash
./build_flavor.sh jds_kitchen release
```

**Gradle Source Sets (in order of priority):**
1. `android/app/src/jds_kitchen/`       ← HIGHEST priority
2. `android/app/src/main/`              ← Base files

**Result:**
- ✅ Uses `jds_kitchen/google-services.json`
- ✅ Uses `jds_kitchen/res/` resources (if exist)
- ✅ Falls back to `main/res/` for common resources
- ✅ Package ID: `com.saas_outlet_app.jds_kitchen`

---

## 📱 Complete Build Flow

### 1. Download Firebase Configs

**Chaimates:**
1. Firebase Console → Add Android App
2. Package: `com.saas_outlet_app.chaimates`
3. Download `google-services.json`
4. Save to: `android/app/src/chaimates/google-services.json`

**JD's Kitchen:**
1. Firebase Console → Add Android App
2. Package: `com.saas_outlet_app.jds_kitchen`
3. Download `google-services.json`
4. Save to: `android/app/src/jds_kitchen/google-services.json`

### 2. Verify File Structure

```bash
# Should show both google-services.json files
ls -la android/app/src/chaimates/google-services.json
ls -la android/app/src/jds_kitchen/google-services.json
```

### 3. Build & Test

```bash
# Build Chaimates
./build_flavor.sh chaimates debug

# Build JD's Kitchen
./build_flavor.sh jds_kitchen debug

# Both APKs can be installed on same device!
```

---

## 🎯 Best Practices

### ✅ DO:
- Keep `google-services.json` in flavor-specific directories
- Use separate Firebase apps for each brand
- Test each flavor independently
- Document flavor-specific configurations

### ❌ DON'T:
- Place `google-services.json` in `android/app/` root
- Share `google-services.json` between flavors
- Hardcode brand-specific values in main code
- Commit API keys to git (use `local.properties`)

---

## 🔐 Security Considerations

### Files to Gitignore:
```gitignore
# Already in .gitignore (verify)
android/local.properties
android/app/src/*/google-services.json  # Optional - your choice

# Keep in Git (recommended):
brands_config.json                       # Metadata only, no secrets
lib/config/brand_config.dart            # Package names are public
```

### Files Safe to Commit:
- ✅ `brands_config.json` - No secrets, just metadata
- ✅ `brand_config.dart` - Package names are public
- ✅ Flavor config files (`.xcconfig`, `build.gradle`)
- ⚠️ `google-services.json` - Depends on your security policy
  - Public apps: Can commit (Firebase has security rules)
  - Enterprise: Don't commit (use CI/CD secrets)

---

## 📞 Troubleshooting

### Build fails with "google-services.json not found"
**Solution:** Ensure file is in correct location:
```bash
android/app/src/chaimates/google-services.json
```

### Wrong notifications received
**Solution:** Verify each flavor has its own `google-services.json` with correct package name

### Both apps have same icon
**Solution:** Create flavor-specific icons:
```
android/app/src/chaimates/res/mipmap-*/ic_launcher.png
android/app/src/jds_kitchen/res/mipmap-*/ic_launcher.png
```

---

## 🎉 Benefits of This Structure

1. ✅ **Complete Brand Isolation** - Each brand has separate Firebase config
2. ✅ **No Build Conflicts** - Gradle handles file merging automatically
3. ✅ **Scalable** - Easy to add more brands
4. ✅ **Clean Code** - No brand-specific code in main source
5. ✅ **Independent Testing** - Test each brand separately
6. ✅ **Flexible Resources** - Override icons, colors per brand
