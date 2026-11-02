#!/usr/bin/env bats
# Unit tests for the pure helpers used by the linear_release_rollover action.

setup() {
  source "${BATS_TEST_DIRNAME}/../../linear_release/filter.sh"
  source "${BATS_TEST_DIRNAME}/../rollover.sh"
}

@test "tag_prefix strips the trailing version" {
  run tag_prefix "tapp-v3.0.4"
  [ "$status" -eq 0 ]
  [ "$output" = "tapp-v" ]
}

@test "tag_prefix keeps digits that are part of the family name" {
  run tag_prefix "tapp2-v10.1.0"
  [ "$output" = "tapp2-v" ]
}

@test "tag_prefix fails on a bare version" {
  run tag_prefix "3.0.4"
  [ "$status" -ne 0 ]
}

@test "next_patch_version bumps the patch component" {
  run next_patch_version "3.0.4"
  [ "$output" = "3.0.5" ]
}

@test "next_patch_version rolls over to two digits" {
  run next_patch_version "3.1.9"
  [ "$output" = "3.1.10" ]
}

@test "next_patch_version does not read a leading zero as octal" {
  run next_patch_version "3.0.08"
  [ "$output" = "3.0.9" ]
}

@test "next_patch_version rejects anything but X.Y.Z" {
  run next_patch_version "3.1"
  [ "$status" -ne 0 ]
  run next_patch_version "3.1.0-rc1"
  [ "$status" -ne 0 ]
  run next_patch_version "tapp-v3.1.0"
  [ "$status" -ne 0 ]
}

@test "version_cmp orders numerically, not lexically" {
  run version_cmp "3.0.9" "3.0.10"
  [ "$output" = "lt" ]
  run version_cmp "3.1.0" "3.0.5"
  [ "$output" = "gt" ]
  run version_cmp "3.0.4" "3.0.4"
  [ "$output" = "eq" ]
}

releases='[
  {"id":"r302","name":"tapp-v3.0.2","createdAt":"2026-10-16T13:01:50Z","stage":{"type":"completed"}},
  {"id":"r303","name":"tapp-v3.0.3","version":"tapp-3.0.3","createdAt":"2026-10-23T12:15:37Z","stage":{"type":"completed"}},
  {"id":"r304","name":"tapp-v3.0.4","createdAt":"2026-10-29T13:08:54Z","stage":{"type":"started"}},
  {"id":"r305","name":"tapp-v3.0.5","createdAt":"2026-10-30T09:00:00Z","stage":{"type":"planned"}},
  {"id":"rx","name":"tapp hotfix notes","createdAt":"2026-10-31T09:00:00Z","stage":{"type":"started"}}
]'

@test "newest_started_release picks the newest started release" {
  run newest_started_release <<< "$releases"
  [ "$status" -eq 0 ]
  [ "$(jq -r .id <<< "$output")" = "rx" ]
}

@test "newest_started_release fails when nothing is started" {
  run newest_started_release <<< '[{"id":"a","name":"tapp-v1.0.0","createdAt":"2026-01-01","stage":{"type":"completed"}}]'
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "release_with_version matches on the name, not the version field" {
  run release_with_version "3.0.3" <<< "$releases"
  [ "$status" -eq 0 ]
  [ "$(jq -r .id <<< "$output")" = "r303" ]
}

@test "release_with_version does not match a longer version" {
  run release_with_version "0.4" <<< "$releases"
  [ "$status" -ne 0 ]
  run release_with_version "3.0.5" <<< "$releases"
  [ "$(jq -r .id <<< "$output")" = "r305" ]
}

@test "release_with_version skips names without a version" {
  run release_with_version "3.0.6" <<< "$releases"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

stages='[
  {"id":"s-done","type":"completed","position":0},
  {"id":"s-cancel","type":"canceled","position":0},
  {"id":"s-plan","type":"planned","position":0},
  {"id":"s-prog2","type":"started","position":2},
  {"id":"s-prog","type":"started","position":1}
]'

@test "stage_id returns the first stage of a type by position" {
  run stage_id started <<< "$stages"
  [ "$output" = "s-prog" ]
  run stage_id completed <<< "$stages"
  [ "$output" = "s-done" ]
}

@test "stage_id fails when the pipeline has no stage of that type" {
  run stage_id planned <<< '[{"id":"s","type":"completed","position":0}]'
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}
