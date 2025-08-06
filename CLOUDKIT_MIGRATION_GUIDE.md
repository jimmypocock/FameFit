# CloudKit Migration Guide

This guide helps you migrate from the legacy CloudKitManager to the modern CloudKitManagerV2.

## Overview of Changes

### 1. **Async/Await Instead of Callbacks**
- All CloudKit operations now use Swift's modern concurrency
- No more completion handlers or callback hell
- Better error propagation and handling

### 2. **Actor-based State Management**
- Thread-safe state management using Swift actors
- No more race conditions
- Proper retry logic with exponential backoff

### 3. **Operation Queue with Rate Limiting**
- Automatic rate limiting to prevent CloudKit throttling
- Priority-based operation scheduling
- Better performance under load

### 4. **Improved Error Handling**
- Distinguishes between retryable and non-retryable errors
- Automatic retry with exponential backoff
- Better error messages and logging

## Migration Steps

### Step 1: Update Dependency Container

```swift
// Old
let cloudKitManager = CloudKitManager()

// New
let cloudKitManager = CloudKitManagerV2()
```

### Step 2: Update Method Calls

#### Account Status Check

```swift
// Old
cloudKitManager.checkAccountStatus()

// New
Task {
    await cloudKitManager.refreshAccountStatus()
}
```

#### User Record Setup

```swift
// Old
cloudKitManager.setupUserRecord(userID: userID, displayName: displayName)

// New
Task {
    await cloudKitManager.setupUserRecord(userID: userID, displayName: displayName)
}
```

#### Adding XP

```swift
// Old
cloudKitManager.addXP(100)

// New
Task {
    await cloudKitManager.addXP(100)
}
```

### Step 3: Update Service Classes

Services should now inherit from `AsyncCloudKitService`:

```swift
// Old
class WorkoutSyncService {
    private let cloudKitManager: CloudKitManaging
    
    func syncWorkouts(completion: @escaping (Result<Void, Error>) -> Void) {
        // Complex nested callbacks
    }
}

// New
class WorkoutSyncServiceV2: AsyncCloudKitService {
    func syncWorkouts() async throws -> SyncResult {
        // Linear, easy-to-read code
    }
}
```

### Step 4: Update View Models

```swift
// Old
class WorkoutViewModel: ObservableObject {
    func saveWorkout() {
        cloudKitManager.save(record) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.showSuccess = true
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
}

// New
@MainActor
class WorkoutViewModel: ObservableObject {
    func saveWorkout() async {
        do {
            let saved = try await workoutService.save(workout)
            showSuccess = true
        } catch {
            self.error = error
        }
    }
}
```

### Step 5: Handle the "Can't query system types" Error

The new implementation handles this gracefully:

```swift
// The new CloudKitManagerV2 automatically:
// 1. Checks if CloudKit is available before operations
// 2. Retries when CloudKit becomes available
// 3. Logs informative messages instead of scary errors
```

## Benefits of Migration

1. **Better Performance**
   - Operations are automatically batched and rate-limited
   - Concurrent operations where appropriate
   - Smart caching

2. **Improved Reliability**
   - Automatic retry with exponential backoff
   - Better handling of CloudKit outages
   - No more race conditions

3. **Easier to Test**
   - Async/await makes testing straightforward
   - Actor isolation prevents test interference
   - Clear separation of concerns

4. **Better Developer Experience**
   - Linear code flow
   - Type-safe error handling
   - Better debugging with structured concurrency

## Common Pitfalls to Avoid

1. **Don't Mix Old and New**
   - Migrate entire features at once
   - Don't try to use both managers simultaneously

2. **Remember to Use Task**
   - When calling async methods from synchronous contexts
   - Use `Task { }` to bridge the gap

3. **Update Error Handling**
   - New errors are more specific
   - Update your error UI to handle new error types

4. **Test Thoroughly**
   - The new implementation may expose timing issues
   - Test with poor network conditions
   - Test with CloudKit rate limiting

## Rollback Plan

If you need to rollback:

1. The old CloudKitManager is still available
2. No schema changes are required
3. Simply switch back in your dependency container

## Next Steps

1. Start with non-critical features
2. Monitor CloudKit dashboard for any issues
3. Gradually migrate all services
4. Remove old CloudKitManager once complete