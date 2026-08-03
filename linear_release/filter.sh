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
