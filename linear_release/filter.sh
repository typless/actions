#!/usr/bin/env bash
# Pure helpers for the linear_release action.
# Intentionally free of network/git calls so the logic is unit-testable.

# normalize_service_path: strip a leading "./" and any trailing "/", then append
# exactly one trailing "/". The result is used as a git pathspec; the trailing
# slash documents directory intent (git pathspec matching is component-wise, so
# "services/user/" can never match "services/user2/...").
normalize_service_path() {
  local p="$1"
  p="${p#./}"
  p="${p%/}"
  printf '%s/' "$p"
}

# extract_issue_ids: read arbitrary text (e.g. `git log --format=%B` output)
# from stdin; print each referenced Linear issue ID on its own line,
# uppercased, sorted, unique. Always exits 0 (empty output when no matches).
# An ID is a strict 3-letter team prefix plus 1-5 digits (TYP-1234), matched
# case-insensitively at word boundaries. Slash-joined continuations share the
# prefix: "TYP-3246/3247" yields TYP-3246 and TYP-3247.
# Word boundaries are emulated with explicit groups instead of \b, and matching
# uses bash's [[ =~ ]] instead of grep/awk, so behavior is identical across
# BSD/macOS and GNU userlands.
extract_issue_ids() {
  local re='(^|[^A-Z0-9_])([A-Z][A-Z][A-Z]-[0-9]{1,5}(/[0-9]{1,5})*)([^A-Z0-9_]|$)'
  local line rest match prefix nums n
  tr '[:lower:]' '[:upper:]' | while IFS= read -r line || [ -n "$line" ]; do
    rest="$line"
    while [[ $rest =~ $re ]]; do
      match="${BASH_REMATCH[2]}"
      prefix="${match%%-*}"
      nums="${match#*-}"
      while :; do
        n="${nums%%/*}"
        printf '%s-%s\n' "$prefix" "$n"
        [ "$n" = "$nums" ] && break
        nums="${nums#*/}"
      done
      rest="${rest#*"${BASH_REMATCH[0]}"}"
    done
  done | sort -u
}

# pick_started_release: read a Linear `releases` query response from stdin and
# print the most recently created release as compact JSON {id, name, url}.
# The caller is expected to have already filtered by name prefix and
# stage type "started" in the query; ordering is done here (by createdAt)
# rather than trusting the API's pagination direction.
pick_started_release() {
  jq -ce '.data.releases.nodes | sort_by(.createdAt) | last | select(. != null) | {id, name, url}'
}

# issue_release_status TARGET_RELEASE_ID: read a Linear `issue` query response
# (with `releases { nodes { id name } }`) from stdin and print one word
# describing the issue's membership relative to the target release:
#   target          already on the target release (re-run: nothing to do)
#   other <names>   on one or more other releases (comma-joined names)
#   none            not on any release
issue_release_status() {
  jq -r --arg target "$1" '
    .data.issue.releases.nodes as $r
    | if any($r[]; .id == $target) then "target"
      elif ($r | length) > 0 then "other " + ([$r[].name] | join(", "))
      else "none" end'
}

# tag_version NAME: print the trailing dotted-numeric version of a git tag or
# Linear release name (tapp-v2.10.1 -> 2.10.1, "TAPP 2.10.1" -> 2.10.1).
# Fails silently when NAME does not end in a version.
tag_version() {
  [[ $1 =~ ([0-9]+(\.[0-9]+)*)$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

# tag_family_glob TAG: print a `git tag --list` glob that matches the tags in
# TAG's family, i.e. everything before its trailing version followed by a
# digit: tapp-v2.10.1 -> 'tapp-v[0-9]*'. Component-wise, so tapp-v never
# matches tapp-desktop-app-v. Fails when TAG has no trailing version.
tag_family_glob() {
  [[ $1 =~ ^(.*[^0-9.])?[0-9]+(\.[0-9]+)*$ ]] || return 1
  printf '%s[0-9]*\n' "${BASH_REMATCH[1]}"
}

# previous_tag TAG: read tag names (one per line, any order) from stdin and
# print the highest one that sorts strictly below TAG in version order. TAG
# need not be present in the input. Fails with no output when nothing is
# below TAG (first release of the family).
previous_tag() {
  { printf '%s\n' "$1"; cat; } | sort -uV | awk -v t="$1" '
    $0 == t { if (prev != "") { print prev; found = 1 }; exit }
    { prev = $0 }
    END { exit !found }'
}
