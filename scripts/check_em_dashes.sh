#!/bin/bash
# UI-12: Check for em-dashes in dates feature code
# Em-dashes (—) should not appear in UI copy per dates-ui-tickets.md §2

# Resolve script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Date chat (RFC-006: CH-F2, CH-F5) follows the same rule. A folder that doesn't exist yet is
# skipped, so grep doesn't fail on it.
SCAN_DIRS=()
for feature in dates chat safety; do
    [ -d "$PROJECT_ROOT/lib/features/$feature" ] && SCAN_DIRS+=("$PROJECT_ROOT/lib/features/$feature/")
done

echo "🔍 Checking for em-dashes in dates, chat and safety features..."

# Run grep and capture exit code
set +e
grep -r "—" "${SCAN_DIRS[@]}" 2>&1
GREP_EXIT=$?
set -e

# Handle grep exit codes:
# 0 = matches found (fail)
# 1 = no matches (success)
# 2+ = error (fail)
if [ $GREP_EXIT -eq 0 ]; then
    echo "❌ FAIL: Em-dashes found in dates, chat or safety feature code"
    echo "Please replace em-dashes with commas, periods, or hyphens with spaces"
    exit 1
elif [ $GREP_EXIT -eq 1 ]; then
    echo "✅ PASS: No em-dashes found"
    exit 0
else
    echo "❌ ERROR: Failed to scan for em-dashes (grep exit code: $GREP_EXIT)"
    exit 1
fi
