#!/usr/bin/env bash
set -euo pipefail
REPO="${1:-elbatt/elbatt-chatbot}"
SINCE_HUMAN="${SINCE:-7 days ago}"

# Linux vs macOS date:
if date -d "$SINCE_HUMAN" >/dev/null 2>&1; then
  SINCE_ISO="$(date -u -d "$SINCE_HUMAN" +%Y-%m-%dT%H:%M:%SZ)"
elif date -v-7d >/dev/null 2>&1; then
  SINCE_ISO="$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)"
else
  SINCE_ISO="$(date -u -Iseconds)"
fi

echo "Repo: $REPO"
echo "Since: $SINCE_ISO"
echo

COMMITS=$(gh api repos/$REPO/commits -f since="$SINCE_ISO" --paginate --jq 'length' | awk '{s+=$1} END{print s+0}')
MERGED=$(gh pr list -R "$REPO" --state merged --search "merged:>$SINCE_ISO" --limit 200 | wc -l | tr -d ' ')
OPEN_PRS=$(gh pr list -R "$REPO" --state open --limit 200 | wc -l | tr -d ' ')
OPEN_ISSUES=$(gh issue list -R "$REPO" --state open --limit 200 | wc -l | tr -d ' ')
CLOSED_ISSUES=$(gh issue list -R "$REPO" --state closed --search "closed:>$SINCE_ISO" --limit 200 | wc -l | tr -d ' ')

RUNS_JSON=$(gh run list -R "$REPO" --limit 100 --json conclusion,createdAt)
RUNS_LAST7=$(echo "$RUNS_JSON" | jq --arg s "$SINCE_ISO" '[.[] | select(.createdAt > $s)]')
RUNS_TOTAL=$(echo "$RUNS_LAST7" | jq 'length')
RUNS_PASS=$(echo "$RUNS_LAST7" | jq '[.[] | select(.conclusion=="success")] | length')
RUNS_FAIL=$(echo "$RUNS_LAST7" | jq '[.[] | select(.conclusion=="failure")] | length')

LAST_DEPLOY=$(gh api repos/$REPO/deployments --jq '.[0].created_at' 2>/dev/null || true)
LAST_RELEASE=$(gh release list -R "$REPO" --limit 1 2>/dev/null | awk '{print $1" "$2" "$3" "$4}')

printf "%-28s %s\n" "Commits (last 7d):" "$COMMITS"
printf "%-28s %s\n" "PRs merged (last 7d):" "$MERGED"
printf "%-28s %s\n" "Open PRs:" "$OPEN_PRS"
printf "%-28s %s\n" "Issues (open):" "$OPEN_ISSUES"
printf "%-28s %s\n" "Issues closed (last 7d):" "$CLOSED_ISSUES"
printf "%-28s %s\n" "CI runs last 7d (total):" "$RUNS_TOTAL"
printf "%-28s %s\n" "CI passed / failed:" "$RUNS_PASS / $RUNS_FAIL"
printf "%-28s %s\n" "Last deployment:" "${LAST_DEPLOY:-n/a}"
printf "%-28s %s\n" "Last release:" "${LAST_RELEASE:-n/a}"
