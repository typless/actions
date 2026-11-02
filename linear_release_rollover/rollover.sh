#!/usr/bin/env bash
# Pure helpers for the linear_release_rollover action.
# Free of network and git calls so the logic is unit-testable. Uses
# tag_version from ../linear_release/filter.sh, which callers source first.

# tag_prefix TAG: print TAG without its trailing version
# (tapp-v3.0.4 -> tapp-v). Fails when TAG does not end in a version or has
# nothing before it.
tag_prefix() {
  [[ $1 =~ ^(.*[^0-9.])[0-9]+(\.[0-9]+)*$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

# next_patch_version X.Y.Z: print X.Y.(Z+1). Only accepts exactly three
# numeric components, so a malformed version fails instead of producing a
# surprising release name.
next_patch_version() {
  [[ $1 =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || return 1
  printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$((10#${BASH_REMATCH[3]} + 1))"
}

# version_cmp A B: print lt, eq or gt for dotted-numeric versions.
version_cmp() {
  if [ "$1" = "$2" ]; then
    echo eq
  elif [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; then
    echo lt
  else
    echo gt
  fi
}

# The jq helpers below read a JSON array of releases
# ([{id, name, version, url, createdAt, stage: {type}}]) from stdin.
# A release's version is taken from the trailing version of its *name*, not
# its `version` field: hand-created releases have been inconsistent there
# (tapp-v3.0.3 was created with version "tapp-3.0.3").

# newest_started_release: the most recently created release whose stage type
# is `started`, as compact JSON. Same rule as attach mode in linear_release.
# Fails with no output when there is none.
newest_started_release() {
  jq -ce '[.[] | select(.stage.type == "started")] | sort_by(.createdAt) | last | select(. != null)'
}

# release_with_version VERSION: the most recently created release whose name
# ends in VERSION, as compact JSON. Fails with no output when there is none.
release_with_version() {
  jq -ce --arg v "$1" '
    [.[] | select(((.name | capture("(?<v>[0-9]+(\\.[0-9]+)*)$")?) | .v) == $v)]
    | sort_by(.createdAt) | last | select(. != null)'
}

# stage_id TYPE: read a pipeline's stage nodes ([{id, type, position}]) from
# stdin and print the id of the first stage of TYPE (planned, started,
# completed, canceled). Fails with no output when the pipeline has none.
stage_id() {
  jq -re --arg t "$1" '[.[] | select(.type == $t)] | sort_by(.position) | .[0].id // empty'
}
