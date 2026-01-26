#!/bin/bash

# ------------------------------------------------------------
# commit-push.sh
# Stages ONLY modified (tracked) + new (untracked) files,
# commits, and pushes. Deletions are intentionally ignored.
# ------------------------------------------------------------

# --- Validate git repo ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a Git repository."
  exit 1
fi

# --- Get commit message (args or prompt) ---
if [ -n "$*" ]; then
  COMMIT_MSG="$*"
else
  read -p "Enter commit message: " COMMIT_MSG
fi

if [ -z "$COMMIT_MSG" ]; then
  echo "Commit message is required."
  exit 1
fi

echo ""
echo "Collecting modified tracked files..."
staged=0

# --- Stage modified (tracked) files ---
while IFS= read -r file; do
  echo "  M  $file"
  if git add "$file"; then
    ((staged++))
  fi
done < <(git ls-files -m)

echo "Collecting new (untracked) files..."
# --- Stage new (untracked) files ---
while IFS= read -r file; do
  echo "  A  $file"
  if git add "$file"; then
    ((staged++))
  fi
done < <(git ls-files --others --exclude-standard)

echo "Committing $staged file(s)..."
if ! git commit -m "$COMMIT_MSG"; then
  echo "Commit failed."
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Pushing branch $BRANCH ..."
if ! git push origin "$BRANCH"; then
  echo "Push failed."
  exit 1
fi

echo ""
echo "Done. Pushed branch $BRANCH."
exit 0
