#!/bin/bash
# Run all branchfs tests

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       BranchFS Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check FUSE
if ! command -v fusermount3 &> /dev/null && ! command -v fusermount &> /dev/null; then
    echo -e "${RED}Error: fusermount not found. Please install fuse3.${NC}"
    exit 1
fi
echo "  ✓ FUSE available"

# Check /dev/fuse permissions
if [[ ! -r /dev/fuse ]] || [[ ! -w /dev/fuse ]]; then
    echo -e "${RED}Error: Cannot access /dev/fuse. Check permissions.${NC}"
    exit 1
fi
echo "  ✓ /dev/fuse accessible"

# Build if needed
echo ""
echo -e "${YELLOW}Building branchfs...${NC}"
(cd "$PROJECT_ROOT" && cargo build --release 2>&1) || {
    echo -e "${RED}Build failed${NC}"
    exit 1
}
echo -e "${GREEN}  ✓ Build successful${NC}"

# Run tests
echo ""
echo -e "${YELLOW}Running tests...${NC}"
echo ""

TOTAL_TESTS=0
PASSED_SUITES=0
FAILED_SUITES=0
FAILED_SUITE_NAMES=()

run_test_suite() {
    local test_script="$1"
    local test_name="$(basename "$test_script" .sh)"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if bash "$test_script"; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
        echo -e "${GREEN}Suite $test_name: PASSED${NC}"
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
        FAILED_SUITE_NAMES+=("$test_name")
        echo -e "${RED}Suite $test_name: FAILED${NC}"
    fi

    echo ""
}

# Run each test suite
for test_file in "$SCRIPT_DIR"/test_*.sh; do
    if [[ -f "$test_file" && "$test_file" != *"test_helper.sh" ]]; then
        run_test_suite "$test_file"
    fi
done

# Final summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       Final Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Test suites run: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_SUITES${NC}"
echo -e "Failed: ${RED}$FAILED_SUITES${NC}"

if [[ $FAILED_SUITES -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed suites:${NC}"
    for name in "${FAILED_SUITE_NAMES[@]}"; do
        echo -e "  ${RED}✗ $name${NC}"
    done
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}All tests passed!${NC}"
exit 0
