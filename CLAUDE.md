# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# Claude Code Testing Environment

This repository contains a **meta-testing framework** where Claude Code tests itself through a comprehensive 76-test benchmark suite across multiple domains.

## Common Commands Quick Reference

### Essential Operations

```bash
# Environment setup and validation
./setup_environment.sh                    # First-time setup (installs deps, generates test data)
cat environment_capabilities.txt          # Check what capabilities are available
python3 test_network_monitor.py          # Test network monitoring capabilities

# Test data management
rm -rf /tmp/test-data && ./setup_environment.sh  # Regenerate test data
cat test_data_manifest.txt                       # View test data inventory
ls -lh /tmp/test-data/*/                         # Check generated datasets

# Log analysis (worker perspective)
tail -1 log_*.jsonl | jq -r '.test_number'       # Last completed test
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' log_*.jsonl  # Status summary
jq -s '.[] | select(.status == "fail")' log_*.jsonl  # All failed tests

# Cross-branch log reading (judge perspective)
git show agent/20251117T191722Z:log_20251117T191722Z.jsonl | jq -s '.'  # Read worker log from judge branch

# Git workflow
git checkout -b agent/$(date -u +%Y%m%dT%H%M%SZ)  # Create timestamped worker branch
git log --oneline --grep="Test #"                  # View test execution history
git push --force-with-lease origin agent/00000000T000000Z  # Safe force-push after rebase

# Session recovery
git branch -a | grep 'agent/2'             # Find worker branches
tail -1 log_*.jsonl | jq '.test_number'    # Resume from last test + 1
```

### Verification Commands

```bash
# Check dependencies
python3 --version && node --version && git --version  # Core tools
podman --version || docker --version                   # Container runtime
python3 -c "from PIL import Image; from faker import Faker; from scapy.all import sniff; print('All Python packages OK')"

# Validate test data
test -d /tmp/test-data && echo "Test data exists" || echo "Run ./setup_environment.sh"
find /tmp/test-data -type f | wc -l                    # Count generated files
```

---

## Architecture Overview

### Meta-Testing Concept

This is NOT a traditional software project—it's a **self-evaluation framework**:

```
Claude Code tests Claude Code
├── Worker Agents (execute tests) → create timestamped branches
├── Judge Agent (evaluates results) → scores worker performance
└── Test Prompts (76 specifications) → detailed test instructions
```

**Key Insight:** Test prompts in `test_suite/` are given TO Claude Code instances to execute. The results are logged in JSONL format and later evaluated by a separate judge agent.

### Multi-Agent Pattern

**Worker Agent Workflow:**
1. Creates branch: `agent/YYYYMMDDTHHMMSSZ` (UTC timestamp)
2. Initializes log: `log_YYYYMMDDTHHMMSSZ.jsonl` (matches branch timestamp)
3. Executes tests sequentially from `test_suite/prompt_1_tests.md`
4. After each test: appends to JSONL → git commit → git push
5. Generates summary reports

**Judge Agent Workflow:**
1. Operates on branch: `agent/00000000T000000Z`
2. Reads worker's JSONL logs cross-branch
3. Scores based on `judge_rubric.yaml` criteria
4. Generates evaluation reports

**Design Philosophy:** Separation of execution (worker) and evaluation (judge) enables reproducible, unbiased assessment.

### Three-Phase Testing

**Phase 0: Setup (5 tests)** - Environment validation
- `test_suite/prompt_0_setup.md` contains detailed specifications
- Tests: Podman, nested containers, session duration, network tools, data generation
- **Purpose:** Determine which of the 76 main tests can be executed
- **Decision-making:** Failed setup tests trigger test skipping (graceful degradation)

**Phase 1: Main Tests (76 tests)** - Capability benchmark
- `test_suite/prompt_1_tests.md` contains all 76 test specifications
- Categories: Security, performance, containers, databases, multi-agent, privacy, RAG, etc.
- **Pass threshold:** 80% (61/76 tests) with confidence ≥0.75
- **Critical tests:** #1, 5, 10, 36, 68, 71, 72 (must pass)

**Phase 2: Evaluation** - Judge agent scoring
- `test_suite/prompt_2_evaluation.md` contains judge instructions
- Judge reads worker JSONL logs cross-branch
- Applies rubric: Correctness (40%), Completeness (30%), Quality (30%)
- Generates evaluation report with pass/fail determination

---

## JSONL Logging Architecture

### Log Structure

Each test execution creates ONE JSONL file: `log_YYYYMMDDTHHMMSSZ.jsonl`

**Every test produces one line** with this structure:

```json
{
  "timestamp": "2025-11-17T19:30:00Z",
  "test_number": "setup_01" | "001",
  "test_name": "podman_availability",
  "category": "environment_validation",
  "status": "pass|fail|partial|timeout",
  "confidence": 0.0-1.0,
  "estimated_duration_seconds": 600,
  "actual_duration_seconds": 120,
  "context": {
    "system_state": {"cpu_usage_percent": 25, "memory_available_gb": 4},
    "environment": {"python_version": "3.9.6", "podman_version": "5.7.0"},
    "test_inputs": {"parameters": {...}, "data_samples": {...}}
  },
  "details": {
    "approach": "Sequential validation of Podman functionality",
    "issues_found": ["Docker daemon not running"],
    "limitations": ["Cannot test nested containers"],
    "complete_error": {"message": "", "stack_trace": [], "relevant_code": ""}
  },
  "artifacts_created": ["/tmp/test-data/json-files/"],
  "reasoning": "Why this test passed or failed",
  "decision": "skip_container_tests|proceed_with_containers"
}
```

### Self-Contained Logs

**Critical Design Principle:** Each log entry contains everything needed for another Claude instance to understand what happened—enabling **Test 67: Meta-self-test and root cause analysis**.

### Querying Logs

```bash
# Summary of test statuses
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' log_*.jsonl

# Get all failed tests
jq -s '.[] | select(.status == "fail") | {test_name, reasoning}' log_*.jsonl

# Check confidence scores
jq -s '.[] | select(.test_number) | {test_name, confidence, status}' log_*.jsonl

# Find tests that timed out
jq -s '.[] | select(.timeout_triggered == true)' log_*.jsonl
```

### Timestamp Correlation

The UTC timestamp (`YYYYMMDDTHHMMSSZ`) is the **universal key** linking:
- Branch name: `agent/20251117T191722Z`
- Log filename: `log_20251117T191722Z.jsonl`
- Git commits: `"Initialize setup phase: 20251117T191722Z"`

---

## Environment Capability Adaptation

### Decision Tree

Setup test failures **trigger adaptive behavior** (not hard failures):

```
setup_01 (Podman Availability) FAIL
  ↓ decision: "skip_container_tests"
  → Tests 16-20, 36-40, 71-72, 76 → SKIPPED

setup_04 (Network Tools) PARTIAL
  ↓ decision: "use_app_level_logging"
  → Tests 68, 71-72 → Use HTTP logging instead of packet capture

setup_03 (Session Duration) TIMEOUT at 15min
  ↓ decision: "split_into_multiple_sessions"
  → Tests 56-60, 76 → Execute in separate sessions
```

### Capability Detection

**File:** `environment_capabilities.txt` (auto-generated by `setup_environment.sh`)

```
CONTAINER RUNTIME
-----------------
Available: true
Runtime: podman
Impact: All container tests available

NETWORK MONITORING
------------------
Available: true (tshark + scapy with BPF access)
Impact: Full packet capture for privacy tests

PYTHON PACKAGES
---------------
Pillow: ✓ Available
Faker: ✓ Available
scapy: ✓ Available

TEST DATA
---------
Location: /tmp/test-data
Generated: 2025-11-17T15:18:55Z
Datasets: JSON (50), Images (1000), FHIR (100), GDPR (1000), RAG (99), Research (15)
```

Check current capabilities:
```bash
cat environment_capabilities.txt
```

---

## Test Data Architecture

### Why Ephemeral (/tmp)?

Test data lives in `/tmp/test-data/` (gitignored) because:
1. **124MB of binary data** shouldn't be in git
2. **Reproducible generation** > versioning binary files
3. **Setup script documents** the generation process
4. **Manifest file** (`test_data_manifest.txt`) tracks what should exist

### Generated Datasets

| Dataset | Count | Size | Purpose | Invalid % |
|---------|-------|------|---------|-----------|
| JSON Files | 50 | ~20MB | JSON processing tests | 10% (5 invalid) |
| Images | 1000 | ~100MB | Image processing (PNG, JPEG, WEBP) | 0% |
| FHIR Patients | 100 | <1MB | Healthcare data standards | 0% |
| GDPR Users | 1000 | ~5MB | Privacy compliance (EU localized) | 0% |
| RAG Articles | 99 | ~10MB | Document retrieval (schema.org) | 0% |
| Research Papers | 15 | <1MB | Citation management | 0% |

**Note:** JSON files intentionally include 5 invalid files (10%) to test error handling.

### Realistic Data Generation

- Uses **Faker library** with EU localizations (`en_GB`, `fr_FR`, `de_DE`, `it_IT`, `es_ES`)
- **FHIR-compliant** medical records
- **Schema.org** structured data for RAG articles
- **Real DOIs** for 4 papers, synthetic for remaining 11

### Real vs Placeholder Images

**With Pillow installed:**
- Generates 1000 real images (PNG, JPEG, WEBP) with valid headers
- Uses PIL.Image to create actual binary image data
- Total size: ~100MB

**Without Pillow:**
- Falls back to placeholder files (empty or minimal content)
- `test_data_manifest.txt` will note: "Pillow not available - placeholder files created"
- Image processing tests (11-15) will be skipped or receive partial credit

---

## Git Workflow Patterns

### Branch Strategy

```
main (stable baseline)
├── develop (integration)
├── agent/00000000T000000Z (judge - persistent, holds rubric)
└── agent/YYYYMMDDTHHMMSSZ (workers - one per test run)
    └── Example: agent/20251117T191722Z
```

### Commit After Every Test

**Critical Pattern:** Git commit after each individual test execution.

**Why?**
- ✅ **Checkpointing** - Resume from failures
- ✅ **Audit trail** - Track progress through git history
- ✅ **Recovery** - Don't lose work if session crashes
- ✅ **Judge visibility** - Can see incremental progress

**Commit Message Format:**
```
Test #XX: test_name - status

Category: test_category
Duration: 120s / 600s (estimated)
Confidence: 0.95
```

**Examples from history:**
```
Setup Test #1: podman_availability - fail
Setup Test #5: test_data_generation - pass
Test #38: complex_query_optimization - pass
```

### Push Strategy

After each commit, push with retry logic:
```bash
for i in {1..3}; do
  if git push origin agent/20251117T191722Z; then
    break
  else
    sleep $((2**i))  # Exponential backoff: 2s, 4s, 8s
  fi
done
```

**Design:** Don't block test execution on git failures—log errors and continue.

---

## Network Monitoring Tiers

### Three-Tier Approach

Tests 68, 71-72 require **verifying zero data exfiltration** when processing sensitive data (SSN, credit cards, PHI, PII).

**Tier 1 (Preferred):** `tshark` (Wireshark CLI)
- Packet-level capture
- Requires: ChmodBPF on macOS (`brew install --cask wireshark-chmodbpf`)
- Usage: `tshark -i en0 -c 10 -f "host anthropic.com"`

**Tier 2 (Alternative):** `scapy` (Python)
- Programmatic packet analysis
- Requires: BPF access (same as tshark)
- Usage: `python3 -c "from scapy.all import sniff; packets = sniff(count=10)"`

**Tier 3 (Fallback):** Application-level logging
- HTTP request inspection
- No special privileges required
- Usage: Intercept with `unittest.mock.patch` or logging hooks

### Capability Testing

```bash
python3 test_network_monitor.py
```

**Output:**
```
✓ PASS - Scapy Import
✓ PASS - Passive Monitoring
✓ PASS - Interface Listing
✓ PASS - Packet Capture (requires BPF on macOS)
✓ PASS - Application Logging

✓ All network monitoring capabilities available!
```

---

## Development Commands

### Environment Setup

```bash
# First time setup (installs dependencies, generates test data)
chmod +x setup_environment.sh
./setup_environment.sh

# Regenerate test data only
rm -rf /tmp/test-data
./setup_environment.sh

# Check current capabilities
cat environment_capabilities.txt

# View detailed setup log
less setup_environment.log
```

### Test Execution

```bash
# Worker agent would execute tests from test_suite/prompt_1_tests.md
# Each test specification includes detailed instructions

# Verify test data exists
ls -la /tmp/test-data/

# Check test data manifest
cat test_data_manifest.txt
```

### Log Analysis

```bash
# View all test statuses
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' log_*.jsonl

# Get summary statistics
jq -s '.[] | select(.test_number) | {test_name, status, duration: .actual_duration_seconds, confidence}' log_*.jsonl

# Find failing tests with reasoning
jq -s '.[] | select(.status == "fail") | {test_number, test_name, reasoning, issues_found: .details.issues_found}' log_*.jsonl

# Check environment at test time
jq -s '.[0].context.system_state' log_*.jsonl
```

### Network Monitoring

```bash
# Test network capture capabilities
python3 test_network_monitor.py

# Verify scapy available
python3 -c "from scapy.all import sniff; print('scapy OK')"

# Check tshark version
tshark --version
```

### Git Operations

```bash
# View test execution history
git log --oneline --graph agent/20251117T191722Z

# See which tests were committed
git log --oneline --grep="Test #" agent/20251117T191722Z

# Compare worker and judge branches
git log --oneline --left-right agent/20251117T191722Z...agent/00000000T000000Z

# View specific test commit
git show agent/20251117T191722Z:log_20251117T191722Z.jsonl | jq -s '.[] | select(.test_number == "005")'
```

---

## Judge Agent Evaluation

### Scoring Rubric

Located on judge branch: `agent/00000000T000000Z` in `judge_rubric.yaml`

```yaml
evaluation_rubric:
  per_test:
    correctness: {weight: 0.4, scale: 0-10}
    completeness: {weight: 0.3, scale: 0-10}
    quality: {weight: 0.3, scale: 0-10}
    pass_threshold: 7.0
  suite_level:
    minimum_pass_rate: 0.80
    critical_tests: [1, 5, 10, 36, 68, 71, 72]
```

### Critical Tests (Must Pass)

- **Test 1, 5:** File operations (basic capability) - Foundation for all file-based tests
- **Test 10:** JSON processing (data handling) - 40+ tests depend on JSON parsing
- **Test 36:** Database operations (complex systems) - Tests multi-step orchestration
- **Test 68:** Privacy/sensitive data handling (zero exfiltration) - Security cornerstone
- **Test 71:** HIPAA-compliant medical data - Healthcare privacy requirement
- **Test 72:** GDPR compliance with right to be forgotten - Data protection law

**Why These Are Critical:**
1. **Foundational capabilities** - Tests 1, 5, 10 enable 60+ downstream tests
2. **Security/Privacy** - Tests 68, 71, 72 verify no data leakage (non-negotiable)
3. **Complex orchestration** - Test 36 validates multi-agent coordination
4. **Legal compliance** - Tests 71-72 ensure regulatory adherence (HIPAA, GDPR)

**Implication:** These tests have higher weight. If any critical test fails, suite-level evaluation may fail even if ≥80% total pass rate.

### Reading Judge Evaluations

Judge stores evaluations in: `agent/00000000T000000Z/judge_evaluations/eval_YYYYMMDDTHHMMSSZ.jsonl`

```bash
# View judge evaluation for a worker run
git show agent/00000000T000000Z:judge_evaluations/eval_20251117T191722Z.jsonl
```

---

## Test Cascade Dependency Map

### Setup Test Failures → Test Skipping

Understanding which setup tests affect which main tests is critical for graceful degradation:

**setup_01 (Podman Availability) FAIL:**
- **Skips:** Tests 16-20, 36-40, 71-72, 76
- **Reason:** These tests require container runtime (Docker/Podman)
- **Impact:** 14 tests skipped (~18% of suite)
- **Fallback:** None - container tests cannot run without runtime

**setup_02 (Nested Container Support) FAIL:**
- **Skips:** Tests 39-40
- **Reason:** Require Docker-in-Docker or Podman-in-Podman
- **Impact:** 2 tests skipped (~3% of suite)
- **Fallback:** Run non-nested container tests only

**setup_03 (Session Duration) TIMEOUT:**
- **Skips:** Tests 56-60, 76
- **Reason:** Long-running tests require 30+ min sessions
- **Impact:** 6 tests skipped (~8% of suite)
- **Fallback:** Split into multiple sessions with checkpointing

**setup_04 (Network Tools) PARTIAL:**
- **Affects:** Tests 68, 71-72
- **Reason:** Packet capture requires tshark/scapy with BPF access
- **Impact:** Tests downgraded to Tier 3 (app-level logging)
- **Fallback:** Application-level HTTP request monitoring

**setup_05 (Test Data Generation) FAIL:**
- **Skips:** All 76 main tests
- **Reason:** No test data = cannot execute any tests
- **Impact:** 100% of suite blocked
- **Fallback:** Regenerate with `./setup_environment.sh`

### Critical Test Dependencies

These tests MUST pass for downstream tests to succeed:

- **Test 1 → Tests 2-76:** File reading enables all subsequent file operations
- **Test 10 → Tests 6-9, 21-35, 51-55:** JSON parsing used across 30+ tests
- **Test 36 → Tests 37-40:** Database setup required for advanced queries
- **Tests 68, 71, 72 → Judge evaluation:** Privacy tests gate final approval

---

## Pass Rate Calculation Rules

### 80% Threshold Clarification

**The 80% pass rate (61/76 tests) applies to AVAILABLE tests, not total tests.**

**Scenario 1: Full environment (all setup tests pass)**
- Available tests: 76
- Required passes: 61 (80% of 76)
- Critical tests: All 7 must pass

**Scenario 2: No container runtime (setup_01 fails)**
- Available tests: 62 (76 - 14 skipped)
- Required passes: 50 (80% of 62)
- Critical tests: 5 must pass (excluding 36, 71, 72 which require containers)

**Scenario 3: Multiple setup failures**
- Calculate: `available = 76 - sum(skipped_per_setup_test)`
- Required: `ceil(available * 0.80)`
- Critical: Only those in available set

### Confidence Weighting

Tests with confidence < 0.75 are treated as "partial pass":
- Counts as 0.5 toward pass rate
- Example: Test passes but confidence=0.6 → adds 0.5 to numerator
- This prevents inflating pass rate with uncertain results

### Judge Override Authority

Judge can fail the suite even at ≥80% if:
1. Any critical test fails
2. Multiple tests in same category fail (indicates systemic issue)
3. Security/privacy tests show data leakage
4. Quality metrics consistently below threshold

---

## Session Recovery Procedures

### Detecting Interruptions

When resuming after session disconnect:

```bash
# 1. Check which worker branch was active
git branch -a | grep 'agent/2'

# 2. Checkout the worker branch
git checkout agent/20251117T191722Z

# 3. Find the log file
LOG_FILE="log_20251117T191722Z.jsonl"

# 4. Check last completed test
tail -1 $LOG_FILE | jq -r '.test_number'
```

### Resuming Execution

**If last test shows status="timeout" or "in_progress":**
```bash
# Mark as failed and continue to next test
# Add entry to log with status="fail" and reasoning="Session timeout during execution"
```

**If last test completed successfully:**
```bash
# Continue from next test number
# Example: Last was test 023, resume at 024
```

### Checkpointing Strategy

**Every test completion:**
1. Append JSONL entry
2. Git commit with test number in message
3. Git push to remote
4. **Recovery point established**

**After every 10 tests:**
1. Generate intermediate summary
2. Verify all tests 001-010 have JSONL entries
3. Check for missing test numbers (indicates skipped tests)

### Multi-Session Execution

For long-running suites:
```bash
# Session 1: Tests 001-025 (file ops, JSON, images)
# Session 2: Tests 026-050 (GDPR, RAG, containers)
# Session 3: Tests 051-076 (research, long-running, privacy)
```

**Between sessions:**
1. Commit all work on worker branch
2. Push to remote
3. New session: checkout same worker branch
4. Resume from next test number

---

## Document Trust Hierarchy

### Which Status Document to Trust?

Multiple status documents exist. Here's the priority order:

**1. `log_YYYYMMDDTHHMMSSZ.jsonl` (HIGHEST AUTHORITY)**
- Ground truth for test execution
- Each line is immutable record of what happened
- Used by judge for evaluation
- **Trust level: 100%**

**2. `environment_capabilities.txt`**
- Auto-generated by `setup_environment.sh`
- Reflects capabilities at setup time
- May become stale if environment changes mid-execution
- **Trust level: 95% (during same session)**

**3. `setup_report.md`**
- Human-readable summary of setup phase
- Derived from first 5 entries in JSONL log
- **Trust level: 90% (if timestamp matches log file)**

**4. `environment_status_final.md`**
- Final status report after all tests complete
- Summarizes overall results
- May contain human interpretation/analysis
- **Trust level: 80% (useful for overview, verify against JSONL)**

**5. `test_data_manifest.txt`**
- Inventory of generated test data
- Updated during setup, static thereafter
- **Trust level: 85% (for data availability checks)**

### Reconciling Conflicts

**If documents disagree:**
1. Always defer to JSONL log as source of truth
2. Check timestamps - newer documents may reflect environment changes
3. For capabilities, run verification commands directly:
   ```bash
   python3 -c "from PIL import Image; print('Pillow OK')"
   podman --version
   ```

**Example conflict:**
- `environment_status_final.md` says "76/76 tests available"
- `log_20251117T191722Z.jsonl` shows 14 tests with status="skip"
- **Resolution:** Trust JSONL - only 62 tests were actually executed

---

## Advanced Analysis Queries

### Cross-Branch Log Reading (For Judge)

Judge agent reads worker logs from different branch:

```bash
# Judge is on agent/00000000T000000Z
# Worker log is on agent/20251117T191722Z

# Method 1: Checkout worker branch temporarily
git checkout agent/20251117T191722Z
cat log_20251117T191722Z.jsonl | jq -s '.'
git checkout agent/00000000T000000Z

# Method 2: Use git show (no branch switching)
git show agent/20251117T191722Z:log_20251117T191722Z.jsonl | jq -s '.'

# Method 3: Fetch and read from remote
git fetch origin agent/20251117T191722Z
git show origin/agent/20251117T191722Z:log_20251117T191722Z.jsonl | jq -s '.'
```

### Complex JSONL Queries

**Find all tests with low confidence:**
```bash
jq -s '.[] | select(.confidence < 0.75) | {test_number, test_name, confidence, status}' log_*.jsonl
```

**Calculate actual pass rate:**
```bash
jq -s '
  map(select(.test_number and (.test_number | startswith("0")))) |
  {
    total: length,
    passed: map(select(.status == "pass")) | length,
    failed: map(select(.status == "fail")) | length,
    skipped: map(select(.status == "skip")) | length,
    partial: map(select(.status == "partial")) | length
  } |
  .pass_rate = (.passed / .total * 100 | round)
' log_*.jsonl
```

**Find tests that took longer than estimated:**
```bash
jq -s '.[] | select(.actual_duration_seconds > .estimated_duration_seconds) |
  {test_name, estimated: .estimated_duration_seconds, actual: .actual_duration_seconds,
   overage: (.actual_duration_seconds - .estimated_duration_seconds)}' log_*.jsonl
```

**Extract all decisions made during setup:**
```bash
jq -s '.[] | select(.test_number | startswith("setup")) | {test_name, decision}' log_*.jsonl
```

**Find tests affected by specific setup failure:**
```bash
# If setup_01 failed, find all container tests that were skipped
jq -s '.[] | select(.category == "container_operations" and .status == "skip") | .test_name' log_*.jsonl
```

**Compare two worker runs:**
```bash
# Worker 1
jq -s 'map(select(.test_number and (.test_number | startswith("0")))) |
       map({test: .test_number, status: .status})' log_20251117T191722Z.jsonl > run1.json

# Worker 2
jq -s 'map(select(.test_number and (.test_number | startswith("0")))) |
       map({test: .test_number, status: .status})' log_20251118T083045Z.jsonl > run2.json

# Diff
diff <(jq -S '.' run1.json) <(jq -S '.' run2.json)
```

---

## Project Structure

```
anthropic-claude-bench/
├── .claude/
│   └── settings.json              # SessionStart hook (auto-validates environment)
├── test_suite/
│   ├── prompt_0_setup.md          # 5 setup tests (detailed specifications)
│   └── prompt_1_tests.md          # 76 main tests (complete test suite)
├── setup_environment.sh           # Automated environment setup
├── test_network_monitor.py        # Network capability tester
├── setup_report.md                # Setup phase results
├── environment_capabilities.txt   # Auto-generated capability summary
├── environment_status_final.md    # Final status (100% capability achieved)
├── judge_rubric.yaml              # Evaluation criteria (on judge branch)
├── log_YYYYMMDDTHHMMSSZ.jsonl     # Test execution logs (worker branches)
├── test_data_manifest.txt         # Test data inventory
├── .env.example                   # Configuration template
└── CLAUDE.md                      # This file
```

---

## Test Suite Categories

### 76-Test Benchmark

The test suite is divided into 15+ categories:

1. **File Operations (Tests 1-5)** - Basic file read/write, navigation, permissions
2. **JSON Processing (Tests 6-10)** - Parsing, validation, large files, error recovery
3. **Image Processing (Tests 11-15)** - Metadata extraction, format conversion, batch processing
4. **Container Operations (Tests 16-20, 36-40)** - Docker/Podman lifecycle, orchestration
5. **Medical Data/FHIR (Tests 21-25)** - Healthcare standards, privacy compliance
6. **GDPR Compliance (Tests 26-30)** - Data protection, consent, right to erasure
7. **RAG/Search (Tests 31-35)** - Document retrieval, semantic search, context extraction
8. **Git Operations (Tests 41-45)** - Repository management, branching, conflict resolution
9. **API Integration (Tests 46-50)** - RESTful APIs, authentication, rate limiting
10. **Research/Citations (Tests 51-55)** - Academic parsing, DOI resolution, bibliography
11. **Long-running Operations (Tests 56-60, 76)** - Session stability, progress tracking
12. **Privacy & Security (Tests 68, 71-72)** - Data leak prevention, network monitoring
13. **Multi-Agent Systems (Tests 31-35)** - Agent hierarchies, DSPy, BAML, GEPA
14. **Database Operations (Tests 36-40)** - Schema design, migrations, optimization
15. **Skills & MCP Servers (Tests 41-50)** - Skill management, FastMCP, tool schemas

**Complete specifications:** See `test_suite/prompt_1_tests.md` for all 76 tests with acceptance criteria, duration estimates, and detailed requirements.

---

## Dependencies

### Pre-installed in Claude Code

- **Python 3.x** - Core scripting
- **Node.js LTS** - JavaScript tooling
- **Git** - Version control

### Optional (Installed via setup script)

**Container Runtime:**
- **Podman 5.x** (preferred) OR **Docker**
- Required for: Tests 16-20, 36-40, 71-72, 76

**Python Packages:**
- **Pillow** - Image processing (real PNG/JPEG/WEBP generation)
- **Faker** - Realistic synthetic data (EU localized)
- **scapy** - Network packet analysis

**Network Tools:**
- **tcpdump** (pre-installed on macOS, requires root)
- **tshark** (Wireshark CLI) - Install: `brew install wireshark`
- **ChmodBPF** (macOS) - Install: `brew install --cask wireshark-chmodbpf` (requires reboot)

---

## Environment Variables

Configure in `.env` file (see `.env.example`):

```bash
# Test configuration
TEST_DATA_DIR=/tmp/test-data
SKIP_CONTAINER_TESTS=true
USE_APP_LEVEL_LOGGING=true

# Optional: API keys for external services
# ANTHROPIC_API_KEY=sk-...
# GITHUB_TOKEN=ghp_...
```

---

## SessionStart Hook

Configured in `.claude/settings.json`, automatically runs on every new session:

**Displays:**
- Timestamp
- Python, Node, Git versions
- Test data availability check
- Quick capability summary:
  - ✓ Podman available
  - ✓ Docker available (daemon running)
  - ✓ Pillow available
  - ✓ Faker available
  - ✗ Podman not available → Install for container tests

**Purpose:** Instant environment validation without manual commands.

---

## Troubleshooting

### Test Data Not Found

```bash
# Regenerate all test data
rm -rf /tmp/test-data
./setup_environment.sh
```

### Container Tests Failing

```bash
# Check container runtime
podman --version || docker --version

# If Docker installed but daemon not running
# macOS: Open Docker Desktop app
# Linux: sudo systemctl start docker
```

### Network Monitoring Not Working

```bash
# Test capabilities
python3 test_network_monitor.py

# If packet capture fails:
# macOS: brew install --cask wireshark-chmodbpf && sudo reboot
# Linux: sudo setcap cap_net_raw+eip $(which python3)
```

### Python Package Import Errors

```bash
# Reinstall dependencies
pip3 install --user Pillow Faker scapy

# Verify installations
python3 -c "from PIL import Image; from faker import Faker; from scapy.all import sniff; print('All OK')"
```

### Session Timeout

For long-running tests:
1. Split into multiple sessions (checkpoint with git commits)
2. Use progress tracking mechanisms
3. Periodic git commits save state

---

## Additional Resources

**Generated by setup script:**
- `setup_environment.log` - Detailed setup process
- `environment_capabilities.txt` - Current capabilities
- `setup_report.md` - Initial validation (5 tests)

**On judge branch:**
- `judge_rubric.yaml` - Evaluation criteria
- `judge_evaluations/` - Evaluation reports

**Test execution:**
- `log_*.jsonl` - Test results in JSONL format
- `test_data_manifest.txt` - Test data inventory

**External documentation:**
- [Claude Code on the Web](https://code.claude.com/docs/en/claude-code-on-the-web)
- [Claude Code Documentation](https://code.claude.com/docs)

---

## Support

For issues or questions:

1. **Check setup log:** `setup_environment.log`
2. **Review capabilities:** `environment_capabilities.txt`
3. **Consult setup report:** `setup_report.md`
4. **Query test logs:** `jq -s '.[] | select(.status == "fail")' log_*.jsonl`
5. **Test network monitoring:** `python3 test_network_monitor.py`

---

## Summary

This meta-testing framework enables Claude Code to systematically evaluate its own capabilities across 76 diverse tests. The architecture separates execution (worker agents) from evaluation (judge agent), with comprehensive JSONL logging enabling cross-session analysis and reproducible assessments.

**Key Design Principles:**
1. **Graceful degradation** - Tests adapt to available environment capabilities
2. **Self-contained logs** - Each JSONL entry enables independent analysis
3. **Checkpointing** - Git commits after every test enable session recovery
4. **Cross-branch coordination** - Judge reads worker logs without branch switching
5. **Document hierarchy** - JSONL logs are ground truth, other docs are derived

**Success Criteria:**
- 80% pass rate on available tests (not total 76)
- All critical tests must pass (1, 5, 10, 36, 68, 71, 72)
- Confidence ≥0.75 for passing tests
- No data exfiltration in privacy tests

---

**Last Updated:** 2025-11-17 (v1.1 - Added dependency maps, pass rate rules, session recovery, document hierarchy, advanced queries)
**Environment:** Claude Code on the Web
**Test Suite Version:** 1.0
**Total Tests:** 5 setup + 76 main = 81 tests
**Framework:** Meta-testing (Claude Code tests Claude Code)
