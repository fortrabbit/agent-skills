#!/usr/bin/env bash
# Copies the skill into fortrabbit/laravel-boost, the Composer package Laravel Boost installs it from, and tags it with the release version.
set -euo pipefail

tag="${1:?usage: sync-laravel-boost.sh vX.Y.Z [remote]}"
remote="${2:-git@github.com:fortrabbit/laravel-boost.git}"
src="plugins/fortrabbit/skills/fortrabbit"

[[ -f "$src/SKILL.md" ]] || { echo "Run from the repo root: $src/SKILL.md not found." >&2; exit 1; }

# Copy only the commit the release tag points at, so a reverted VERSION never tags newer content with an old version.
git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null || git fetch --quiet origin "refs/tags/$tag:refs/tags/$tag" 2>/dev/null || true
if [[ "$(git rev-parse --quiet --verify "$tag^{commit}" || true)" != "$(git rev-parse HEAD)" ]]; then
  echo "Tag $tag does not point at HEAD, skipping." >&2
  exit 0
fi

dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT

git clone --quiet "$remote" "$dir"
if git -C "$dir" rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
  echo "laravel-boost already has $tag, skipping."
  exit 0
fi

dest="$dir/resources/boost/skills/fortrabbit"
rm -rf "$dest"
mkdir -p "$dest"
cp -R "$src/." "$dest/"

git -C "$dir" add --all resources/boost/skills
if ! git -C "$dir" diff --cached --quiet; then
  git -C "$dir" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "Sync the fortrabbit skill from agent-skills $tag"
fi
git -C "$dir" tag "$tag"
git -C "$dir" push --quiet origin HEAD "refs/tags/$tag"
echo "laravel-boost synced and tagged $tag."
