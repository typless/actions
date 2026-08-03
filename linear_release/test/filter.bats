#!/usr/bin/env bats
# Unit tests for the pure helpers used by the linear_release action.

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

@test "extract_issue_ids extracts a ticket after the category/service prefix" {
  run extract_issue_ids <<< "fix[billing]: COR-716 raw_request returns StripResponse"
  [ "$status" -eq 0 ]
  [ "$output" = "COR-716" ]
}

@test "extract_issue_ids extracts multiple tickets from one line, sorted" {
  run extract_issue_ids <<< "feature[ui,authorization] TYP-1234 TYP-1235 Example commit message"
  [ "$output" = $'TYP-1234\nTYP-1235' ]
}

@test "extract_issue_ids accepts a trailing colon after the ticket" {
  run extract_issue_ids <<< "improvement[ui] TYP-717: Navigation update"
  [ "$output" = "TYP-717" ]
}

@test "extract_issue_ids uppercases lowercase tickets" {
  run extract_issue_ids <<< "fix typ-1234 thing"
  [ "$output" = "TYP-1234" ]
}

@test "extract_issue_ids expands slash-joined ticket numbers" {
  run extract_issue_ids <<< "fix[received_invoices,ui] TYP-3246/3247/3248 code-review fixes"
  [ "$output" = $'TYP-3246\nTYP-3247\nTYP-3248' ]
}

@test "extract_issue_ids keeps only the base when a slash continuation exceeds 5 digits" {
  run extract_issue_ids <<< "fix TYP-3246/324789 thing"
  [ "$output" = "TYP-3246" ]
}

@test "extract_issue_ids rejects tickets with more than 5 digits" {
  run extract_issue_ids <<< "fix TYP-123456 thing"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "extract_issue_ids rejects a 4-letter prefix" {
  run extract_issue_ids <<< "fix ABCD-1234 thing"
  [ "$output" = "" ]
}

@test "extract_issue_ids rejects a 2-letter prefix" {
  run extract_issue_ids <<< "fix AB-1234 thing"
  [ "$output" = "" ]
}

@test "extract_issue_ids rejects tickets embedded in a word" {
  run extract_issue_ids <<< $'xTYP-1234 thing\nTYP-1234x thing'
  [ "$output" = "" ]
}

@test "extract_issue_ids returns empty output and status 0 for a ticketless message" {
  run extract_issue_ids <<< "feature[received_invoices]: add is_protected to TagEntity"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "extract_issue_ids returns empty output and status 0 on empty input" {
  run extract_issue_ids <<< ""
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "extract_issue_ids dedupes across lines and sorts lexicographically" {
  run extract_issue_ids <<< $'fix TYP-9 msg\nfeature TYP-10 msg\nchore typ-9 msg'
  [ "$output" = $'TYP-10\nTYP-9' ]
}

@test "extract_issue_ids extracts a ticket from a merge-commit branch name" {
  run extract_issue_ids <<< "Merge pull request #677 from typless/janbatic/typ-2663-add-ui-component"
  [ "$output" = "TYP-2663" ]
}

@test "extract_issue_ids scans body lines, not just the subject" {
  run extract_issue_ids <<< $'improvement[ml] tune search\n\nAlso closes TYP-42 as a side effect.'
  [ "$output" = "TYP-42" ]
}

@test "extract_issue_ids matches a ticket at end of line" {
  run extract_issue_ids <<< "final touches for TYP-55"
  [ "$output" = "TYP-55" ]
}
