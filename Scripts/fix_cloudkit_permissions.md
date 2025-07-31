# Fix CloudKit Permission Issues

## The Problem
You're seeing "Permission Failure - Can't query system types" errors. This means CloudKit isn't properly configured.

## Solution Steps

### 1. Check iCloud Sign-in
- Open Settings app in simulator
- Go to Sign in to your iPhone/iPad
- Make sure you're signed in with an Apple ID
- If not signed in, sign in with your Apple ID

### 2. Verify CloudKit Container Setup
1. Go to https://developer.apple.com/account
2. Navigate to Certificates, Identifiers & Profiles
3. Click on Identifiers → App IDs
4. Find your app (com.jimmypocock.FameFit)
5. Check that CloudKit is enabled with the correct container

### 3. Configure CloudKit Dashboard
1. Go to https://icloud.developer.apple.com/dashboard
2. Sign in with your developer account
3. Select your container: `iCloud.com.jimmypocock.FameFit`
4. Go to Schema → Record Types
5. Make sure these record types exist:
   - UserProfiles
   - Workouts
   - UserRelationships
   - ActivityFeedItems
6. If they don't exist, create them with the fields from CloudKitSchema.md
7. **IMPORTANT**: Deploy changes to Production environment

### 4. Add Missing Indexes
For each record type, go to Schema → Indexes and add:
- `___recordID` as QUERYABLE (three underscores)
- This prevents "Field 'recordName' is not marked queryable" errors

### 5. Reset and Retry
1. In the app, use Developer Menu → Reset for Onboarding Test
2. Restart the app
3. Try the onboarding flow again

## If Still Having Issues

The app might be trying to use CloudKit before it's ready. The initialization errors suggest the schema manager is failing to set up. This could be because:

1. The container doesn't exist
2. You're not signed into iCloud
3. The schema hasn't been deployed to Production
4. Network connectivity issues

Check the CloudKit dashboard for any error messages or warnings about your container.