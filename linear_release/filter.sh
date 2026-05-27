#!/usr/bin/env bash
# Pure path-scoping helpers for the linear_release action.
# Intentionally free of network/gh calls so the matching logic is unit-testable.

# normalize_service_path: strip a leading "./" and any trailing "/", then append
# exactly one trailing "/". The trailing slash makes prefix matching reject a
# sibling directory (e.g. "services/user" must not match "services/user2/...").
normalize_service_path() {
  local p="$1"
  p="${p#./}"
  p="${p%/}"
  printf '%s/' "$p"
}

# any_path_under: read newline-separated file paths from stdin; return 0 if any
# path begins with the given prefix (which must already include its trailing
# slash, e.g. from normalize_service_path), else return 1.
any_path_under() {
  local prefix="$1" f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      "$prefix"*) return 0 ;;
    esac
  done
  return 1
}
