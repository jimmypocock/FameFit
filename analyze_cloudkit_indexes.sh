#!/bin/bash

echo "=== CloudKit Index Requirements Analysis ==="
echo "Based on queries found in the codebase"
echo "==========================================="
echo

# Function to extract queries from a file
analyze_file() {
    local file=$1
    local filename=$(basename "$file")
    
    # Check if file has queries
    if grep -q "CKQuery\|NSPredicate.*format:" "$file"; then
        echo "📄 $filename"
        echo "-------------------"
        
        # Extract record types
        grep -B2 -A2 "CKQuery(recordType:" "$file" | grep "recordType:" | sed 's/.*recordType: *"\([^"]*\)".*/Record Type: \1/' | sort -u
        
        # Extract predicate fields
        echo "Fields used in queries:"
        grep "NSPredicate.*format:" "$file" | sed 's/.*format: *"//; s/".*//' | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*' | grep -v '^%' | sort -u | sed 's/^/  - /'
        
        # Extract sort descriptors
        echo "Sort fields:"
        grep "NSSortDescriptor.*key:" "$file" | grep -oE 'key: *"[^"]*"' | sed 's/key: *"/  - /' | sed 's/"//' | sort -u
        
        echo
    fi
}

# Analyze each Swift file
for file in $(find /Users/jimmypocock/Projects/Watch/FameFit -name "*.swift" -type f); do
    if grep -q "CKQuery\|NSPredicate.*format:" "$file" 2>/dev/null; then
        analyze_file "$file"
    fi
done

echo "=== Summary of Required Indexes ==="
echo

# Collect all record types and their fields
echo "By Record Type:"
echo "---------------"

# Create a comprehensive analysis
for recordType in ActivityFeedItems DeviceTokens GroupWorkouts UserProfiles UserRelationships Users UserSettings WorkoutChallenges WorkoutComments WorkoutHistory WorkoutKudos; do
    echo
    echo "🗂 $recordType"
    echo "  Required indexes:"
    
    # Find all files that reference this record type
    grep -r "recordType: *\"$recordType\"" /Users/jimmypocock/Projects/Watch/FameFit --include="*.swift" 2>/dev/null | while read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        # Get surrounding context for better extraction
        grep -A10 -B10 "recordType: *\"$recordType\"" "$file" 2>/dev/null
    done | grep -E "(NSPredicate|NSSortDescriptor)" | while read -r predLine; do
        if echo "$predLine" | grep -q "NSPredicate.*format:"; then
            # Extract field names from predicates
            echo "$predLine" | sed 's/.*format: *"//; s/".*//' | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*' | grep -v -E '^(NSPredicate|format|AND|OR|NOT|IN|BETWEEN|LIKE|CONTAINS|BEGINSWITH|ENDSWITH|%@|%K)$'
        elif echo "$predLine" | grep -q "NSSortDescriptor.*key:"; then
            # Extract sort fields
            echo "$predLine" | grep -oE 'key: *"[^"]*"' | sed 's/key: *"//' | sed 's/"//' | awk '{print $0 " (SORTABLE)"}'
        fi
    done | sort -u | sed 's/^/    - /'
    
    echo "    - ___recordID (QUERYABLE) [System requirement]"
done

echo
echo "=== Specific Queries Found ==="
echo

# Show actual queries for ActivityFeedItems specifically
echo "📄 ActivityFeedItems queries:"
grep -r "ActivityFeedItems" /Users/jimmypocock/Projects/Watch/FameFit --include="*.swift" -A5 -B5 2>/dev/null | grep -E "(NSPredicate|format:|NSSortDescriptor)" | head -20