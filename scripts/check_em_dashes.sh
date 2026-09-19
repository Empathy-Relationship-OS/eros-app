#!/bin/bash
# UI-12: Check for em-dashes in dates feature code
# Em-dashes (—) should not appear in UI copy per dates-ui-tickets.md §2

# Resolve script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DATES_DIR="$PROJECT_ROOT/lib/features/dates"

echo "🔍 Checking for em-dashes in dates feature..."

# Run grep and capture exit code
set +e
grep -r "—" "$DATES_DIR/" 2>&1
GREP_EXIT=$?
set -e

# Handle grep exit codes:
# 0 = matches found (fail)
# 1 = no matches (success)
# 2+ = error (fail)
if [ $GREP_EXIT -eq 0 ]; then
    echo "❌ FAIL: Em-dashes found in dates feature code"
    echo "Please replace em-dashes with commas, periods, or hyphens with spaces"
    exit 1
elif [ $GREP_EXIT -eq 1 ]; then
    echo "✅ PASS: No em-dashes found"
    exit 0
else
    echo "❌ ERROR: Failed to scan for em-dashes (grep exit code: $GREP_EXIT)"
    exit 1
fi
