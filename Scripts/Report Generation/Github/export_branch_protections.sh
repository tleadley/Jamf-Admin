#!/bin/bash

#==============================================================================
# Description:  Retrieves branch protection rules for all active repositories
#               for a GitHub owner and exports them to a CSV file. It now
#               includes an entry for repositories with no protected branches.
#
# Usage:        ./export_branch_protections.sh <GITHUB_OWNER> <OUTPUT_FILE.csv>
# Example:      ./export_branch_protections.sh google google_protections.csv
#
# Dependencies:
#   - GitHub CLI (gh): https://cli.github.com/
#   - jq: https://stedolan.github.io/jq/
#==============================================================================

set -eo pipefail

# --- Function to check for required tools ---
check_dependencies() {
  if ! command -v gh &> /dev/null; then
    echo "Error: The GitHub CLI ('gh') is not installed." >&2
    echo "Please install it from: https://cli.github.com/" >&2
    exit 1
  fi
  if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed." >&2
    echo "Please install it (e.g., 'brew install jq')." >&2
    exit 1
  fi
}

# --- Main Script Logic ---
main() {
  check_dependencies

  local OWNER="$1"
  local OUTPUT_FILE="$2"

  if [[ -z "$OWNER" ]] || [[ -z "$OUTPUT_FILE" ]]; then
    echo "Error: Missing arguments." >&2
    echo "Usage: $0 <GITHUB_OWNER> <OUTPUT_FILE.csv>" >&2
    exit 1
  fi

  # Check GitHub authentication status
  if ! gh auth status &> /dev/null; then
    echo "You are not logged in to GitHub." >&2
    echo "Please run 'gh auth login' and try again." >&2
    exit 1
  fi

  echo "🔍 Fetching repositories for '$OWNER' and writing to '$OUTPUT_FILE'..." >&2

  # Initialize CSV file with a header
  echo "Repository,Branch,RequiredReviews,DismissStaleReviews,RequireConversationResolution,RequiredStatusChecks,AllowForcePushes,AllowDeletions" > "$OUTPUT_FILE"

  # Get all non-archived repositories
  gh repo list "$OWNER" --no-archived --json nameWithOwner --limit 1000 --jq '.[].nameWithOwner' | while read -r repo; do
    echo "▪️ Checking repository: $repo" >&2

    protected_branches=$(gh api "repos/$repo/branches" --jq '.[] | select(.protection.enabled == true) | .name' 2>/dev/null)

    # --- MODIFIED LOGIC FOR REPOS WITH NO RULES ---
    # If no protected branches are found, write a default "no rules" entry.
    if [[ -z "$protected_branches" ]]; then
      echo "$repo,None,0,false,false,,false,false" >> "$OUTPUT_FILE"
      continue
    fi

    # Loop through each protected branch and get its rules
    echo "$protected_branches" | while read -r branch; do
      rules=$(gh api "repos/$repo/branches/$branch/protection" 2>/dev/null)

      if [[ -z "$rules" ]]; then
        continue
      fi

      # Use jq to extract rules and format as a CSV row, then append to the file.
      echo "$rules" | jq --arg repo "$repo" --arg branch "$branch" -r '
        [
          $repo,
          $branch,
          .required_pull_request_reviews.required_approving_review_count // 0,
          .required_pull_request_reviews.dismiss_stale_reviews // false,
          .required_conversation_resolution.enabled // false,
          ((.required_status_checks.contexts // []) | join(";")),
          .allow_force_pushes.enabled // false,
          .allow_deletions.enabled // false
        ] | @csv
      ' >> "$OUTPUT_FILE"
    done
  done

  echo "✨ Done. Results saved to $OUTPUT_FILE" >&2
}

main "$@"
