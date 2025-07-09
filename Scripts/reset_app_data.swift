#!/usr/bin/env swift

import Foundation

// This script resets all FameFit app data for testing

print("🧹 Resetting FameFit app data...")

// 1. Clear UserDefaults
let userDefaults = UserDefaults.standard
let fameFitKeys = [
    "FameFitUserID",
    "FameFitUserName",
    "hasCompletedOnboarding",
    "selectedCharacter"
]

for key in fameFitKeys {
    userDefaults.removeObject(forKey: key)
    print("  ✓ Removed UserDefaults key: \(key)")
}

// Also clear any keys that start with "FameFit"
let allKeys = userDefaults.dictionaryRepresentation().keys
for key in allKeys where key.hasPrefix("FameFit") {
    userDefaults.removeObject(forKey: key)
    print("  ✓ Removed UserDefaults key: \(key)")
}

userDefaults.synchronize()

print("\n✅ App data reset complete!")
print("\nNext steps:")
print("1. Delete the app from your device/simulator")
print("2. In Settings > Sign in with Apple > Apps Using Apple ID > Remove FameFit")
print("3. For CloudKit: Settings > [Your Name] > iCloud > Manage Storage > FameFit > Delete Data")
print("4. Reinstall the app")
print("\nThe app will start fresh with onboarding!"