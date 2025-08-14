# CloudKit Development Workflow

## The Challenge

When developing with CloudKit and Apple Watch apps, you'll encounter this issue:
- **Watch apps ALWAYS use Production CloudKit** (even when run from Xcode)
- **iPhone apps use Development CloudKit** when run from Xcode
- **They can't share data** between Development and Production environments

## Solutions

### 1. **Deploy Schema to Production** (Recommended)

Before testing Watch↔iPhone communication:

```bash
# In CloudKit Dashboard (https://icloud.developer.apple.com/dashboard)
1. Go to your app's container
2. Select "Schema" → "Deploy Schema Changes..."
3. Deploy from Development to Production
```

This ensures both environments have the same schema.

### 2. **Use TestFlight for Full Testing**

For complete integration testing:
1. Archive your app with both iOS and Watch targets
2. Upload to TestFlight
3. Both apps will use Production CloudKit
4. Full feature testing is possible

### 3. **Development Workflow Options**

#### Option A: Force Production in Development (Current Setup)

In `CloudKitConfiguration.swift`:
```swift
#if DEBUG
static let forceProductionInDebug = true  // Set to true to use production
#else
static let forceProductionInDebug = false
#endif
```

**IMPORTANT**: This doesn't actually force CloudKit to use production in simulator/development builds. CloudKit determines the environment based on:
- Code signing (Development vs Distribution)
- Provisioning profile
- Build configuration

#### Option B: Use Development Provisioning Profile with Production Entitlement

1. In Xcode, go to Signing & Capabilities
2. Add CloudKit capability
3. In entitlements file, add:
```xml
<key>com.apple.developer.icloud-container-environment</key>
<string>Production</string>
```

**Note**: This may require a special provisioning profile.

#### Option C: Test Features Independently

1. **Test iPhone features** in Development environment
2. **Test Watch features** separately (they'll use Production)
3. **Test integration** via TestFlight

### 4. **Recommended Development Process**

1. **Initial Development**: 
   - Develop iPhone features using Development CloudKit
   - Develop Watch features knowing they use Production

2. **Schema Changes**:
   - Make schema changes in Development first
   - Test on iPhone
   - Deploy to Production
   - Test on Watch

3. **Integration Testing**:
   - Use TestFlight builds for full integration testing
   - Both apps will use Production environment

4. **Data Management**:
   - Keep test data in both environments
   - Use different test accounts for Development vs Production

### 5. **Quick Testing via Xcode**

If you need to test iPhone↔Watch communication from Xcode:

1. **Build & Run iPhone app** with Release configuration:
   ```
   Product → Scheme → Edit Scheme → Run → Build Configuration → Release
   ```
   This will use Production CloudKit

2. **Alternative**: Create a custom build configuration:
   - Duplicate Release configuration
   - Name it "Debug-Production"
   - Use for testing

### 6. **Environment Detection**

To detect which environment you're using at runtime:

```swift
// Add to CloudKitService.swift
func detectEnvironment() async {
    do {
        let _ = try await container.privateCloudDatabase.allRecordZones()
        print("✅ Using CloudKit Production Environment")
    } catch {
        if error.localizedDescription.contains("development") {
            print("🔧 Using CloudKit Development Environment")
        } else {
            print("❓ CloudKit environment unknown: \(error)")
        }
    }
}
```

## Important Notes

1. **Schema must be deployed to Production** before Watch app can work
2. **TestFlight always uses Production** for both apps
3. **Simulator behavior varies** - sometimes uses Development even with Production settings
4. **Real devices are more reliable** for testing Production environment

## Common Issues

### "Record type not found" on Watch
- **Cause**: Schema not deployed to Production
- **Fix**: Deploy schema from Development to Production in CloudKit Dashboard

### Data not syncing between iPhone and Watch
- **Cause**: Different CloudKit environments
- **Fix**: Use TestFlight or force both to Production

### Can't force Production in Development
- **Cause**: CloudKit environment is determined by code signing
- **Fix**: Use Release build configuration or TestFlight