#!/bin/bash
# UI-12: Check for em-dashes in dates feature code
# Em-dashes (—) should not appear in UI copy per dates-ui-tickets.md §2

set -e

echo "🔍 Checking for em-dashes in dates feature..."

if grep -r "—" lib/features/dates/ 2>/dev/null; then
    echo "❌ FAIL: Em-dashes found in dates feature code"
    echo "Please replace em-dashes with commas, periods, or hyphens with spaces"
    exit 1
else
    echo "✅ PASS: No em-dashes found"
    exit 0
fi
