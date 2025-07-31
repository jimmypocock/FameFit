#!/bin/bash

echo "=== Performing WorkoutHistory to Workouts Refactoring ==="
echo "========================================================="
echo

# Function to safely replace text in files
replace_in_file() {
    local file=$1
    local old_text=$2
    local new_text=$3
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/$old_text/$new_text/g" "$file"
    else
        # Linux
        sed -i "s/$old_text/$new_text/g" "$file"
    fi
}

# Step 1: Update CloudKit record type references (exact string "WorkoutHistory")
echo "Step 1: Updating CloudKit record type from 'WorkoutHistory' to 'Workouts'..."
find . -name "*.swift" -type f | while read file; do
    if grep -q 'recordType: "WorkoutHistory"' "$file"; then
        echo "  Updating record type in: $file"
        replace_in_file "$file" 'recordType: "WorkoutHistory"' 'recordType: "Workouts"'
    fi
done

# Step 2: Update WorkoutHistoryItem to WorkoutItem
echo
echo "Step 2: Updating WorkoutHistoryItem to WorkoutItem..."
find . -name "*.swift" -type f | while read file; do
    if grep -q "WorkoutHistoryItem" "$file"; then
        echo "  Updating: $file"
        replace_in_file "$file" "WorkoutHistoryItem" "WorkoutItem"
    fi
done

# Step 3: Update function names from workoutHistory to workout
echo
echo "Step 3: Updating function names..."
find . -name "*.swift" -type f | while read file; do
    if grep -q "saveWorkoutHistory" "$file"; then
        echo "  Updating saveWorkoutHistory in: $file"
        replace_in_file "$file" "saveWorkoutHistory" "saveWorkout"
    fi
    if grep -q "fetchWorkoutHistory" "$file"; then
        echo "  Updating fetchWorkoutHistory in: $file"
        replace_in_file "$file" "fetchWorkoutHistory" "fetchWorkouts"
    fi
done

# Step 4: Update view file name
echo
echo "Step 4: Renaming WorkoutHistoryView..."
if [ -f "./FameFit/Views/WorkoutHistoryView.swift" ]; then
    mv "./FameFit/Views/WorkoutHistoryView.swift" "./FameFit/Views/WorkoutsView.swift"
    echo "  Renamed WorkoutHistoryView.swift to WorkoutsView.swift"
    
    # Update the struct name inside
    replace_in_file "./FameFit/Views/WorkoutsView.swift" "struct WorkoutHistoryView" "struct WorkoutsView"
fi

# Step 5: Update test file names
echo
echo "Step 5: Renaming test files..."
if [ -f "./FameFitTests/Unit/Models/WorkoutHistoryItemTests.swift" ]; then
    mv "./FameFitTests/Unit/Models/WorkoutHistoryItemTests.swift" "./FameFitTests/Unit/Models/WorkoutItemTests.swift"
    echo "  Renamed WorkoutHistoryItemTests.swift to WorkoutItemTests.swift"
    
    # Update the class name inside
    replace_in_file "./FameFitTests/Unit/Models/WorkoutItemTests.swift" "WorkoutHistoryItemTests" "WorkoutItemTests"
fi

# Step 6: Update variable names from workoutHistory to workout where appropriate
echo
echo "Step 6: Updating variable names..."
# This is more complex and needs manual review, so we'll just list files that might need attention

echo
echo "Files that may need manual review for variable name updates:"
grep -r "workoutHistory" . --include="*.swift" | grep -v ".build" | cut -d: -f1 | sort -u

# Step 7: Update JavaScript files
echo
echo "Step 7: Updating JavaScript files..."
find . -name "*.js" -type f | while read file; do
    if grep -q "WorkoutHistory" "$file"; then
        echo "  Updating: $file"
        replace_in_file "$file" "WorkoutHistory" "Workouts"
    fi
done

# Step 8: Update markdown files
echo
echo "Step 8: Updating documentation..."
find . -name "*.md" -type f | while read file; do
    if grep -q "WorkoutHistory" "$file"; then
        echo "  Updating: $file"
        replace_in_file "$file" "WorkoutHistory" "Workouts"
        replace_in_file "$file" "WorkoutHistoryItem" "WorkoutItem"
    fi
done

echo
echo "Refactoring complete! Please review the changes and test thoroughly."
echo
echo "Don't forget to:"
echo "1. Update the CloudKit Dashboard to rename the record type from 'WorkoutHistory' to 'Workouts'"
echo "2. Run all tests to ensure nothing is broken"
echo "3. Update any CloudKit subscriptions that reference the old record type"