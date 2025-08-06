# TODO: Group Workouts Feature Completion

## 🚨 Critical Missing Features

### 1. Live Workout Session UI
- [ ] Create active workout tracking interface
- [ ] Implement real-time participant status updates during workouts
- [ ] Add live metrics sharing between participants
- [ ] Show participant progress in real-time (heart rate, calories, distance)
- [ ] Handle participant dropout/reconnection during session
- **Location**: Need to implement in `GroupWorkoutDetailView.swift:906` (see TODO comment)

### 2. Watch App Integration
- [ ] Add group workout support to Watch app
- [ ] Sync group workout data between iOS and Watch
- [ ] Display participant info on Watch during workout
- [ ] Show group workout invites on Watch
- [ ] Enable starting/joining group workouts from Watch
- **Location**: `FameFit Watch App/` needs group workout features

### 3. Real-time Sync During Workouts
- [ ] Implement live participant heartbeat/status updates
- [ ] Add real-time metrics sync using CloudKit subscriptions
- [ ] Handle network interruptions gracefully
- [ ] Optimize update frequency for battery life
- **Location**: Extend `GroupWorkoutService+WorkoutManagement.swift`

## 📋 Feature Completions Needed

### 4. Edit Group Workouts
- [ ] Complete `EditGroupWorkoutView` implementation (currently placeholder)
- [ ] Add form validation
- [ ] Handle participant notification on changes
- [ ] Support recurring workout modifications
- **Location**: `FameFit/Views/GroupWorkouts/EditGroupWorkoutView.swift`

### 5. Invitation Flow UX
- [ ] Complete invite sending in `InviteFriendsView`
- [ ] Add invite acceptance/decline flow
- [ ] Implement invite notifications
- [ ] Add invite expiration handling
- [ ] Create invite deep linking
- **Location**: `FameFit/Views/GroupWorkouts/InviteFriendsView.swift`

### 6. Notification Integration
- [ ] Hook up group workout notifications to `NotificationManager`
- [ ] Add notification types:
  - [ ] Workout reminder (30 min before)
  - [ ] Invite received
  - [ ] Participant joined/left
  - [ ] Workout started without you
  - [ ] Workout completed
- **Location**: Extend `NotificationManager.swift`

### 7. Calendar Integration
- [ ] Complete calendar sync implementation
- [ ] Add to iOS Calendar app
- [ ] Support calendar subscription
- [ ] Handle timezone conversions properly
- **Location**: `GroupWorkoutService+Calendar.swift`

## 🔧 Technical Improvements

### 8. Performance Optimizations
- [ ] Implement pagination for group workout lists
- [ ] Add image caching for participant avatars
- [ ] Optimize CloudKit queries with indexes
- [ ] Add offline support with local caching

### 9. Testing Gaps
- [ ] Add UI tests for group workout creation flow
- [ ] Test real-time sync scenarios
- [ ] Add Watch app integration tests
- [ ] Test notification delivery
- [ ] Add performance tests for large group sessions

### 10. Polish & Edge Cases
- [ ] Handle maximum participant limits
- [ ] Add workout templates for quick creation
- [ ] Implement workout history/analytics
- [ ] Add achievement unlocks for group workouts
- [ ] Handle conflicts when multiple edits happen simultaneously
- [ ] Add "ghost mode" for privacy during workouts

## 💡 Nice-to-Have Features

### Future Enhancements
- [ ] Voice chat during workouts
- [ ] Workout replay/analysis
- [ ] Team vs team competitions
- [ ] Scheduled recurring workouts
- [ ] Integration with Strava/other platforms
- [ ] Custom workout plans for groups
- [ ] Leaderboards within group workouts
- [ ] Post-workout group photos
- [ ] Workout music sync

## 📝 Known Issues to Address

### From Codebase Analysis
- [ ] Fix ID confusion in follower system (CloudKit User IDs vs Profile UUIDs)
- [ ] Complete error handling in all service methods
- [ ] Add retry logic for failed CloudKit operations
- [ ] Improve loading states and error messages

## 🎯 Recommended Priority Order

1. **Phase 1: Core Functionality**
   - Live workout session UI
   - Basic Watch app integration
   - Complete edit functionality

2. **Phase 2: Real-time Features**
   - Real-time sync during workouts
   - Notification integration
   - Invitation flow completion

3. **Phase 3: Polish**
   - Calendar integration
   - Performance optimizations
   - Comprehensive testing

4. **Phase 4: Enhancements**
   - Nice-to-have features
   - Advanced analytics
   - Social features integration

## 📊 Estimated Completion

- **Current Status**: ~80% infrastructure complete
- **Estimated effort for MVP**: 2-3 weeks
- **Full feature completion**: 4-6 weeks

## 🔗 Related Files

- Main service: `FameFit/Services/GroupWorkoutService.swift`
- Models: `FameFit/Models/GroupWorkout.swift`
- Views: `FameFit/Views/GroupWorkouts/`
- Tests: `FameFitTests/GroupWorkouts/`