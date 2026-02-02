#!/bin/bash
# Test unmount functionality (single-level discard)

source "$(dirname "$0")/test_helper.sh"

test_unmount_main() {
    setup
    do_mount

    # Unmount main
    do_unmount

    # Should be unmounted
    assert "! mountpoint -q '$TEST_MNT'" "Mount point unmounted"

    # Main branch should still exist in storage
    # (We'd need to remount to check, but the storage structure should remain)
}

test_unmount_discards_single_branch() {
    setup
    do_mount
    do_create "unmount_test" "main" "-m"

    echo "branch content" > "$TEST_MNT/branch_file.txt"

    # Unmount (should discard the branch)
    do_unmount

    # Should be unmounted
    assert "! mountpoint -q '$TEST_MNT'" "Mount point unmounted"

    # No changes to base
    assert_file_not_exists "$TEST_BASE/branch_file.txt" "No changes to base"
}

test_unmount_nested_discards_only_current() {
    setup
    do_mount

    # Create nested branches
    do_create "parent_branch" "main" "-m"
    echo "parent content" > "$TEST_MNT/parent_file.txt"

    do_create "child_branch" "parent_branch" "-m"
    echo "child content" > "$TEST_MNT/child_file.txt"

    # Unmount (should discard only child_branch, keep parent_branch)
    do_unmount

    # Should be unmounted
    assert "! mountpoint -q '$TEST_MNT'" "Mount point unmounted"

    # Remount to check state
    do_mount

    # Parent branch should still exist
    assert_branch_exists "parent_branch" "Parent branch preserved"

    # Child branch should be gone
    assert_branch_not_exists "child_branch" "Child branch discarded"

    do_unmount
}

test_unmount_cleanup() {
    setup
    do_mount
    do_create "cleanup_test" "main" "-m"

    # Create some files
    echo "test" > "$TEST_MNT/test.txt"

    # Unmount
    do_unmount

    # Storage for the branch should be cleaned up
    local branch_dir="$TEST_STORAGE/branches/cleanup_test"
    assert "[[ ! -d '$branch_dir' ]]" "Branch storage directory cleaned up"
}

# Run tests
run_test "Unmount Main" test_unmount_main
run_test "Unmount Discards Single Branch" test_unmount_discards_single_branch
run_test "Unmount Nested Discards Only Current" test_unmount_nested_discards_only_current
run_test "Unmount Cleanup" test_unmount_cleanup

print_summary
