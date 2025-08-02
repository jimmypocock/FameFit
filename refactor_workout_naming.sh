#!/bin/bash

# Refactoring script to change WorkoutHistory to Workouts
# This script will help identify all files that need to be changed

echo "=== Refactoring WorkoutHistory to Workouts ==="
echo "=============================================="
echo

# Step 1: Find all occurrences of WorkoutHistory
echo "Step 1: Finding all occurrences of WorkoutHistory..."
echo "-----------------------------------------------------"

# Find in Swift files
echo "Swift files containing 'WorkoutHistory':"
find . -name "*.swift" -type f -exec grep -l "WorkoutHistory" {} \; | grep -v ".build" | sort

echo
echo "JavaScript files containing 'WorkoutHistory':"
find . -name "*.js" -type f -exec grep -l "WorkoutHistory" {} \; | grep -v "node_modules" | sort

echo
echo "Markdown files containing 'WorkoutHistory':"
find . -name "*.md" -type f -exec grep -l "WorkoutHistory" {} \; | sort

echo
echo "Step 2: Key replacements needed:"
echo "--------------------------------"
echo "1. WorkoutHistoryItem -> WorkoutItem"
echo "2. WorkoutHistory (record type) -> Workouts"
echo "3. workoutHistory (variable names) -> workout or workouts"
echo "4. File rename: WorkoutHistoryItem.swift -> WorkoutItem.swift"
echo "5. File rename: WorkoutHistoryView.swift -> WorkoutsView.swift"

echo
echo "Step 3: CloudKit specific changes:"
echo "----------------------------------"
echo "Record type: 'WorkoutHistory' -> 'Workouts'"
echo "This needs to be changed in CloudKit Dashboard too!"

echo
echo "Step 4: Suggested order of changes:"
echo "-----------------------------------"
echo "1. Update model file (WorkoutHistoryItem.swift -> WorkoutItem.swift)"
echo "2. Update CloudKit record type references"
echo "3. Update all service files"
echo "4. Update all view files"
echo "5. Update test files"
echo "6. Update documentation"

echo
echo "Total files to update:"
find . -type f \( -name "*.swift" -o -name "*.js" -o -name "*.md" \) -exec grep -l "WorkoutHistory" {} \; | grep -v -E "(.build|node_modules|refactor_workout_naming.sh)" | wc -l