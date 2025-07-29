# FameFit Developer Tools

This directory contains development-only tools for testing FameFit with realistic CloudKit data. These tools are only included in DEBUG builds and will not ship in production.

## Test Account Setup Guide

### 1. Create Test Apple IDs

Create the following Apple IDs for testing different personas:

1. **Athlete Account** - `famefit.athlete@icloud.com`
   - Sarah Chen - Marathon runner, 125k XP, verified
   
2. **Beginner Account** - `famefit.beginner@icloud.com`
   - Mike Johnson - Just started fitness journey, 2.8k XP
   
3. **Influencer Account** - `famefit.influencer@icloud.com`
   - Alex Rivera - Certified PT, 245k XP, verified
   
4. **Coach Account** - `famefit.coach@icloud.com`
   - Emma Thompson - Former Olympic athlete, 380k XP, verified
   
5. **Casual Account** - `famefit.casual@icloud.com`
   - James Park - Weekend warrior, 18.5k XP

### 2. Sign Into Simulators

1. Open Settings app in each simulator
2. Sign in with different test Apple IDs
3. Use different simulator devices for each account:
   - iPhone 16 Pro - Athlete
   - iPhone 15 Pro - Beginner
   - iPhone 15 - Influencer
   - iPhone 14 Pro - Coach
   - iPhone 14 - Casual

### 3. Register Each Account

For each simulator/account:

1. Launch FameFit app
2. Complete onboarding (Sign in with Apple, grant HealthKit)
3. Shake device to open Developer Menu
4. Tap "Register This Account"
5. Select the appropriate persona
6. The CloudKit ID will be saved automatically

### 4. Set Up Test Data

In the Developer Menu for each account:

1. **Setup Profile** - Creates the user profile with persona data
2. **Setup Social Graph** - Creates follow relationships between test accounts
3. **Seed Workout History** - Adds realistic workout history (last 90 days)
4. **Seed Activity Feed** - Creates activity feed items

Or use **"Setup Everything"** to do all steps at once.

### 5. Social Relationships

The test accounts have predefined relationships:

- **Athlete** (Sarah):
  - Mutual follow with Influencer
  - Follows Coach
  - Followed by Casual

- **Beginner** (Mike):
  - Follows Coach, Influencer, and Athlete

- **Influencer** (Alex):
  - Mutual follow with Athlete and Coach
  - Followed by Beginner and Casual

- **Coach** (Emma):
  - Mutual follow with Influencer
  - Followed by Athlete and Beginner

- **Casual** (James):
  - Follows Athlete and Influencer

## Using Developer Menu

### Access
Shake any device running a DEBUG build to show the Developer Menu.

### Features

1. **Account Management**
   - Register current account as a test persona
   - View current CloudKit user ID
   - See assigned persona

2. **Data Seeding**
   - Setup Profile - Creates UserProfile record
   - Setup Social Graph - Creates follow relationships
   - Seed Workout History - Adds workout records
   - Seed Activity Feed - Creates feed items

3. **Quick Actions**
   - Setup Everything - One-tap full setup
   - Clean All Data - Remove all test data

4. **Help**
   - Setup Instructions - Shows this guide

## Best Practices

1. **Consistent Testing**: Always use the same Apple ID for the same persona
2. **Team Sharing**: Store test Apple ID credentials in team password manager
3. **Clean State**: Use "Clean All Data" before major testing sessions
4. **Realistic Data**: Test data mimics real user behavior patterns

## Troubleshooting

### "Persona not found" Error
- Make sure you've registered the current account first
- Check you're signed into the correct Apple ID

### Social relationships not showing
- Ensure all test accounts have been set up
- Social graph requires other accounts to exist

### CloudKit errors
- Verify you're in Development environment (not Production)
- Check CloudKit Dashboard for schema issues

## Architecture

- `TestAccounts.swift` - Defines test personas and their data
- `CloudKitSeeder.swift` - Seeds CloudKit with test data
- `DeveloperMenu.swift` - UI for developer tools

All code is wrapped in `#if DEBUG` to ensure it's excluded from release builds.