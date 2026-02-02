#!/bin/bash
# Test basic mount/unmount functionality

source "$(dirname "$0")/test_helper.sh"

test_mount_unmount() {
    setup

    # Mount
    do_mount
    assert "mountpoint -q '$TEST_MNT'" "Mount point is mounted"

    # Check base files are visible
    assert_file_exists "$TEST_MNT/file1.txt" "Base file1.txt is visible"
    assert_file_exists "$TEST_MNT/file2.txt" "Base file2.txt is visible"
    assert_file_exists "$TEST_MNT/subdir/nested.txt" "Nested file is visible"

    # Check content
    assert_file_contains "$TEST_MNT/file1.txt" "base content" "file1.txt has correct content"

    # Unmount
    do_unmount
    assert "! mountpoint -q '$TEST_MNT'" "Mount point is unmounted"
}

test_mount_creates_directories() {
    setup

    # Remove mount directory to test auto-creation
    rmdir "$TEST_MNT"

    # Mount should create the directory
    do_mount
    assert "[[ -d '$TEST_MNT' ]]" "Mount directory was created"
    assert "mountpoint -q '$TEST_MNT'" "Mount point is mounted"

    do_unmount
}

test_daemon_auto_start_stop() {
    setup

    # No daemon should be running
    assert "[[ ! -S '$TEST_STORAGE/daemon.sock' ]]" "No daemon socket before mount"

    # Mount starts daemon
    do_mount
    assert "[[ -S '$TEST_STORAGE/daemon.sock' ]]" "Daemon socket exists after mount"

    # Unmount stops daemon (last mount)
    do_unmount
    sleep 0.5
    assert "[[ ! -S '$TEST_STORAGE/daemon.sock' ]]" "Daemon socket removed after unmount"
}

# Run tests
run_test "Mount and Unmount" test_mount_unmount
run_test "Mount Creates Directories" test_mount_creates_directories
run_test "Daemon Auto Start/Stop" test_daemon_auto_start_stop

print_summary
