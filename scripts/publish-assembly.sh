#!/usr/bin/env bash
# Push the build worktree's assembled commit to manifest.toml's [publish]
# branch and tag it. The lock pins the commit, which fork-assembler builds
# deterministically: refuse to publish a worktree at any other. The push is a
# force (a rebuild re-commits rather than fast-forwards), leased against the
# head we observed.
#
# Usage: publish-assembly.sh [BUILD_WORKTREE]

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

worktree="${1:-.worktrees/build}"
lock_file="manifest.lock.json"
manifest="manifest.toml"

if [[ ! -d "$worktree" ]]; then
  echo "error: no build worktree at $worktree; run \`fork-assembler build\` first" >&2
  exit 1
fi

publish_key() {
  awk -v key="$1" '
    /^\[publish\]/ { in_publish = 1; next }
    /^\[/          { in_publish = 0 }
    in_publish && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$manifest"
}

remote="$(publish_key remote)"
branch="$(publish_key branch)"
tag_prefix="$(publish_key tag_prefix)"
if [[ -z "$remote" || -z "$branch" ]]; then
  echo "error: $manifest has no [publish] remote/branch to push to" >&2
  exit 1
fi

expected_tree="$(jq -r '.build.tree' "$lock_file")"
if [[ -z "$expected_tree" || "$expected_tree" == "null" ]]; then
  echo "error: $lock_file records no build tree" >&2
  exit 1
fi

if [[ -n "$(git -C "$worktree" status --porcelain)" ]]; then
  echo "error: $worktree is dirty -- it is mid-build or mid-resolution" >&2
  exit 1
fi

commit="$(git -C "$worktree" rev-parse HEAD)"
actual_tree="$(git -C "$worktree" rev-parse 'HEAD^{tree}')"
if [[ "$actual_tree" != "$expected_tree" ]]; then
  echo "error: $worktree carries tree $actual_tree, but $lock_file pins $expected_tree" >&2
  echo "       run \`fork-assembler build --locked\` to reproduce the locked tree first" >&2
  exit 1
fi

expected_commit="$(jq -r '.build.commit' "$lock_file")"
if [[ "$commit" != "$expected_commit" ]]; then
  echo "error: $worktree is at $commit, but $lock_file pins $expected_commit" >&2
  echo "       run \`fork-assembler build --locked\` to reproduce the locked commit first" >&2
  exit 1
fi

git -C "$worktree" fetch --force --no-tags "$remote" "$branch" >&2 || true
lease="$(git -C "$worktree" rev-parse --verify --quiet FETCH_HEAD || true)"

if [[ "$lease" == "$commit" ]]; then
  echo "already published: $remote/$branch is $commit (tree $expected_tree)"
  exit 0
fi

echo "publishing $commit (tree $expected_tree) to $remote/$branch"
if [[ -n "$lease" ]]; then
  git -C "$worktree" push "--force-with-lease=refs/heads/$branch:$lease" \
    "$remote" "$commit:refs/heads/$branch"
else
  git -C "$worktree" push "$remote" "$commit:refs/heads/$branch"
fi

if [[ -n "$tag_prefix" ]]; then
  tag="$tag_prefix-$(date -u +%Y%m%d-%H%M%S)"
  git -C "$worktree" push "$remote" "$commit:refs/tags/$tag"
  echo "tagged $tag"
fi
