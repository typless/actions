#!/usr/bin/env bats
# Unit tests for the pure path-scoping helpers used by the linear_release action.

setup() {
  source "${BATS_TEST_DIRNAME}/../filter.sh"
}

@test "normalize_service_path strips leading ./ and keeps single trailing /" {
  run normalize_service_path "./services/user/"
  [ "$status" -eq 0 ]
  [ "$output" = "services/user/" ]
}

@test "normalize_service_path adds a trailing / when missing" {
  run normalize_service_path "services/ui"
  [ "$output" = "services/ui/" ]
}

@test "any_path_under matches a file directly under the prefix" {
  run any_path_under "services/user/" <<< "services/user/main.py"
  [ "$status" -eq 0 ]
}

@test "any_path_under matches a file in a nested subdirectory" {
  run any_path_under "services/user/" <<< $'README.md\nservices/user/app/handler.py'
  [ "$status" -eq 0 ]
}

@test "any_path_under returns non-zero when no file is under the prefix" {
  run any_path_under "services/user/" <<< $'services/ui/x.vue\nservices/ml/y.py'
  [ "$status" -eq 1 ]
}

@test "any_path_under does not partial-match a sibling directory" {
  run any_path_under "services/user/" <<< "services/user2/main.py"
  [ "$status" -eq 1 ]
}

@test "any_path_under returns non-zero on empty input" {
  run any_path_under "services/user/" <<< ""
  [ "$status" -eq 1 ]
}

@test "any_path_under distinguishes nested service subtrees (text_blocks)" {
  run any_path_under "services/text_blocks/lambda_handlers/" <<< "services/text_blocks/text_blocks_api/main.py"
  [ "$status" -eq 1 ]
}

@test "any_path_under matches its own nested subtree (text_blocks)" {
  run any_path_under "services/text_blocks/lambda_handlers/" <<< "services/text_blocks/lambda_handlers/handler.py"
  [ "$status" -eq 0 ]
}
