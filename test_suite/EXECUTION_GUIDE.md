# Test Suite Execution Guide

Complete step-by-step guide for executing the Claude Code test suite on Claude Code Web (claude.ai/code).

## Table of Contents

1. [Pre-Execution Checklist](#pre-execution-checklist)
2. [Phase 1: Setup Tests](#phase-1-setup-tests)
3. [Phase 2: Main Test Suite](#phase-2-main-test-suite)
4. [Phase 3: Judge Evaluation](#phase-3-judge-evaluation)
5. [Session Management](#session-management)
6. [Troubleshooting](#troubleshooting)

---

## Pre-Execution Checklist

### Step 1: Verify Repository Setup

```bash
cd /Users/stharrold/Documents/GitHub/anthropic-claude-bench

# Check SessionStart hooks configured
cat .claude/settings.json

# Verify branches exist
git branch -a | grep -E "(develop|agent/00000000T000000Z)"

# Confirm judge rubric exists
cat judge_rubric.yaml

# Check environment setup script
ls -l setup_environment.sh
```

**Expected output:**
- ✅ `.claude/settings.json` contains SessionStart hooks
- ✅ `develop` branch exists
- ✅ `agent/00000000T000000Z` (judge branch) exists with `judge_rubric.yaml`
- ✅ `setup_environment.sh` is executable

### Step 2: Verify Local Environment (Optional)

Run environment setup locally to pre-validate:

```bash
# Run setup script
./setup_environment.sh

# Check test data
ls -lh /tmp/test-data/

# Verify capabilities
cat environment_capabilities.txt
```

**Note:** This step is optional. Claude Code Web will run SessionStart hooks automatically, but local verification helps catch issues early.

### Step 3: Push All Changes to Remote

```bash
# Ensure all changes committed and pushed
git status
git push origin develop
git push origin agent/00000000T000000Z

# Verify remote state
git log --oneline -5
```

---

## Phase 1: Setup Tests

**Duration:** 1-2 hours
**Tests:** 5 setup tests
**Purpose:** Validate environment and determine which main tests are executable

### Step 1: Open Claude Code Web

1. Navigate to https://claude.ai/code
2. Connect your GitHub account (if not already connected)
3. Select repository: `anthropic-claude-bench`
4. Select branch: `develop`

### Step 2: Copy Setup Prompt

```bash
# In local terminal, display the prompt
cat test_suite/prompt_0_setup.md
```

**Copy the entire content** (all ~500+ lines including all 5 test specifications)

### Step 3: Submit to Claude Code Web

1. Paste the entire `prompt_0_setup.md` content into Claude Code chat
2. Press Enter/Submit
3. Claude will respond confirming it understands the task

**Expected initial response:**
- Creates timestamped worker branch (`agent/YYYYMMDDTHHMMSSZ`)
- Initializes JSONL log file (`log_YYYYMMDDTHHMMSSZ.jsonl`)
- Begins executing Setup Test 1

### Step 4: Monitor Execution

Claude will sequentially execute:

1. **Setup Test 1: Podman Availability** (~10 min)
   - Checks for Podman or Docker
   - Tests container operations
   - Logs results

2. **Setup Test 2: Nested Containerization** (~15 min)
   - Tests Docker-in-Docker capability
   - Requires Setup Test 1 to pass

3. **Setup Test 3: Session Duration** (~30-60 min)
   - Long-running stability test
   - Creates periodic heartbeat files
   - Tests session persistence

4. **Setup Test 4: Network Monitoring Tools** (~10 min)
   - Validates tshark, tcpdump, scapy
   - Tests packet capture capability

5. **Setup Test 5: Test Data Generation** (~20-40 min)
   - Generates 124MB test data
   - Creates JSON, images, FHIR, GDPR, RAG datasets
   - Validates all datasets

### Step 5: Verify Completion

After all 5 tests complete, verify:

```bash
# Check worker branch exists
git fetch origin
git branch -a | grep agent/

# View the log file
git checkout agent/YYYYMMDDTHHMMSSZ
cat log_YYYYMMDDTHHMMSSZ.jsonl | jq .

# Review setup report
cat setup_report.md
```

**Expected artifacts:**
- ✅ New branch: `agent/YYYYMMDDTHHMMSSZ`
- ✅ Log file: `log_YYYYMMDDTHHMMSSZ.jsonl` (5+ entries)
- ✅ Report: `setup_report.md`
- ✅ Test data: `/tmp/test-data/` (if Setup Test 5 passed)

### Step 6: Review Environment Capabilities

Check `setup_report.md` to understand which main tests will be available:

```bash
# Quick summary
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' log_*.jsonl
```

**Possible outcomes:**
- **All 5 pass**: 76/76 main tests available (100%)
- **Container tests fail**: 63/76 tests available (skip tests 16-20, 36-40, 71-72, 76)
- **Network tests fail**: Use application-level logging fallback

---

## Phase 2: Main Test Suite

**Duration:** 13.5 hours (estimated)
**Tests:** 76 comprehensive capability tests
**Purpose:** Full Claude Code capability benchmark

### Option A: Single Session (Recommended if setup passed)

If Setup Test 3 validated 30+ minutes of session stability:

#### Step 1: Continue in Same Session

**In the same Claude Code Web session** where you ran Phase 1:

```bash
# Display main test prompt
cat test_suite/prompt_1_tests.md
```

**Copy and paste the entire content** (all ~3000+ lines including all 76 test specifications)

#### Step 2: Submit Main Tests

1. Paste entire `prompt_1_tests.md` content
2. Submit to Claude Code
3. Claude continues on the same worker branch
4. Logs append to the same JSONL file

#### Step 3: Monitor Progress

Claude will execute tests sequentially or in logical groups:

- **Tests 1-5**: File operations (~30 min)
- **Tests 6-10**: JSON processing (~45 min)
- **Tests 11-15**: Image processing (~1 hour)
- **Tests 16-20**: Container operations (~1.5 hours) *if available*
- **Tests 21-25**: Medical/FHIR data (~1 hour)
- **Tests 26-30**: GDPR compliance (~1 hour)
- **Tests 31-35**: RAG/Search (~1.5 hours)
- **Tests 36-40**: Docker API (~1.5 hours) *if available*
- **Tests 41-45**: Git operations (~1 hour)
- **Tests 46-50**: API integration (~1 hour)
- **Tests 51-55**: Research/citations (~1 hour)
- **Tests 56-60**: Long-running ops (~2 hours)
- **Tests 61-76**: Mixed categories (~3 hours)

### Option B: Multi-Session (If session limits exist)

If you encounter session limits, split into phases:

#### Session 1: Tests 1-20
```bash
cat test_suite/prompt_1_tests.md | sed -n '1,/^## Test 021:/p'
```

#### Session 2: Tests 21-40
```bash
git checkout agent/YYYYMMDDTHHMMSSZ
# Submit next batch with context: "Continue test suite from Test 21"
```

#### Session 3: Tests 41-60
#### Session 4: Tests 61-76

**Important:** Always start new sessions on the worker branch to maintain JSONL log continuity.

### Step 4: Verify Main Test Completion

```bash
# Count test entries in log
jq -s '. | length' log_YYYYMMDDTHHMMSSZ.jsonl

# Should show 81+ entries (5 setup + 76 main tests)

# Summary by status
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' log_*.jsonl
```

---

## Phase 3: Judge Evaluation

**Duration:** 30-60 minutes
**Purpose:** Independent evaluation of test results by judge agent

### Step 1: Create Evaluation Prompt

First, create the judge evaluation prompt:

```bash
cat test_suite/prompt_2_evaluation.md
```

### Step 2: Open New Claude Code Session

1. Navigate to https://claude.ai/code
2. Select repository: `anthropic-claude-bench`
3. **Important:** Select branch: `agent/00000000T000000Z` (judge branch)

### Step 3: Submit Evaluation Prompt

1. Copy entire `prompt_2_evaluation.md` content
2. Paste into Claude Code Web
3. Submit

**Judge agent will:**
1. Read worker branch logs via `git log` and `git show`
2. Parse all JSONL entries
3. Apply `judge_rubric.yaml` scoring criteria
4. Generate comprehensive evaluation report
5. Identify critical test failures
6. Provide improvement recommendations

### Step 4: Review Evaluation Report

```bash
# Switch to judge branch
git checkout agent/00000000T000000Z
git pull

# View evaluation report
cat evaluation_report_YYYYMMDDTHHMMSSZ.md
```

**Expected report sections:**
- Executive summary (pass rate, critical tests)
- Per-test scores (correctness, completeness, quality)
- Category-level analysis
- Failed test root cause analysis
- Recommendations for improvement
- Overall verdict (PASS/FAIL)

---

## Session Management

### SessionStart Hooks

Every new Claude Code Web session automatically runs:

```bash
# Defined in .claude/settings.json
python3 --version
node --version
git --version
ls -la /tmp/test-data/ || echo "Run setup_environment.sh"
```

This ensures:
- ✅ Development tools available
- ✅ Test data presence verified
- ✅ Quick environment validation

### Detecting Remote Environment

Claude Code can detect if running in Web environment:

```bash
if [ -n "$CLAUDE_CODE_REMOTE" ]; then
  echo "Running on Claude Code Web"
else
  echo "Running in local CLI"
fi
```

### Session Recovery

If a session disconnects mid-test:

1. **Check last commit:**
   ```bash
   git checkout agent/YYYYMMDDTHHMMSSZ
   git log -1 --oneline
   ```

2. **Review last JSONL entry:**
   ```bash
   tail -1 log_YYYYMMDDTHHMMSSZ.jsonl | jq .
   ```

3. **Resume from next test:**
   - Open new Claude Code Web session
   - Checkout worker branch
   - Submit: "Continue test suite from Test [N+1]"

### Committing Strategy

Claude commits after each test:

```bash
git commit -m "Test #042: passed - git_branch_operations

Details: Successfully created, merged, and deleted branches

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

This enables:
- ✅ Checkpoint/recovery at test granularity
- ✅ Git-based log analysis by judge agent
- ✅ Visual progress tracking

---

## Troubleshooting

### Issue: Test Data Not Found

**Symptoms:**
```
ls: /tmp/test-data/: No such file or directory
```

**Solution:**
```bash
./setup_environment.sh
# Or let SessionStart hooks regenerate automatically
```

### Issue: Container Tests Failing

**Symptoms:**
```
Cannot connect to Podman socket
Docker daemon not available
```

**Solution:**
This is expected if Setup Test 1 failed. Claude will:
- Log failure with confidence score
- Skip tests 16-20, 36-40, 71-72, 76
- Continue with remaining tests

**No action needed** - graceful degradation is intentional.

### Issue: Network Monitoring Limited

**Symptoms:**
```
tshark: Permission denied
scapy: PermissionError during packet capture
```

**Solution:**
Claude will automatically fall back to application-level logging:
- Uses Python `http.client` with verbose logging
- Captures request/response at application layer
- Tests 68, 71-72 use alternative validation

### Issue: Session Timeout

**Symptoms:**
- Session disconnects after 30-60 minutes
- Tests incomplete

**Solution:**

1. **Check progress:**
   ```bash
   git log --oneline | head -20
   tail -5 log_*.jsonl | jq .
   ```

2. **Resume testing:**
   - Start new Claude Code session
   - Checkout worker branch
   - Submit remaining tests explicitly

3. **Use multi-session approach:**
   - Split into 4 sessions (20 tests each)
   - Commit after each session

### Issue: JSONL Parsing Errors

**Symptoms:**
```
jq: parse error
```

**Solution:**
```bash
# Validate JSONL format
while IFS= read -r line; do
  echo "$line" | jq . > /dev/null || echo "Invalid JSON: $line"
done < log_*.jsonl

# Find last valid entry
jq -s '.[-1]' log_*.jsonl
```

### Issue: Python Package Import Errors

**Symptoms:**
```
ModuleNotFoundError: No module named 'Pillow'
```

**Solution:**
SessionStart hooks should auto-install. Manually verify:
```bash
pip3 show Pillow Faker scapy
```

If missing:
```bash
pip3 install --user Pillow Faker scapy
```

---

## Best Practices

### 1. Run Setup Phase First
Always complete Phase 1 before Phase 2. Setup results inform test execution strategy.

### 2. Monitor JSONL Logs
Periodically check logs during execution:
```bash
tail -f log_*.jsonl | jq .
```

### 3. Commit Frequently
Claude should commit after every test. Verify with:
```bash
git log --oneline | wc -l
# Should be 76+ commits
```

### 4. Use Example Logs
Compare your logs to `examples/example_*_log.jsonl` to verify format.

### 5. Plan for Long Duration
76 tests take ~13.5 hours. Consider:
- Running overnight
- Multi-session approach
- Monitoring progress via git

### 6. Review Before Evaluation
Before running judge agent, verify:
- All tests executed
- JSONL log complete
- No parse errors

---

## Quick Reference

### Key Commands

```bash
# View test prompt
cat test_suite/prompt_[0-2]_*.md

# Check worker branch
git checkout agent/YYYYMMDDTHHMMSSZ

# Analyze logs
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' log_*.jsonl

# Find failed tests
jq -s '.[] | select(.status == "fail")' log_*.jsonl

# Check test duration
jq -s 'map(.actual_duration_seconds) | add' log_*.jsonl

# Verify test data
ls -lh /tmp/test-data/ | tail -20

# View latest commit
git log -1 --stat

# Switch to judge branch
git checkout agent/00000000T000000Z
```

### Key Files

- `prompt_0_setup.md` - Setup phase (5 tests)
- `prompt_1_tests.md` - Main tests (76 tests)
- `prompt_2_evaluation.md` - Judge evaluation
- `log_YYYYMMDDTHHMMSSZ.jsonl` - Test results log
- `setup_report.md` - Setup phase summary
- `evaluation_report_*.md` - Judge evaluation report

### Key URLs

- **Claude Code Web**: https://claude.ai/code
- **Documentation**: https://code.claude.com/docs/en/claude-code-on-the-web
- **GitHub Repo**: https://github.com/anthropics/claude-code

---

## Summary Workflow

```
1. Verify pre-execution checklist ✓
   └─> .claude/settings.json, branches, rubric

2. Phase 1: Setup (1-2 hours)
   └─> Submit prompt_0_setup.md to Claude Code Web
   └─> Creates agent/YYYYMMDDTHHMMSSZ branch
   └─> Executes 5 setup tests
   └─> Generates setup_report.md

3. Phase 2: Main Tests (13.5 hours)
   └─> Submit prompt_1_tests.md to SAME session
   └─> Executes 76 capability tests
   └─> Appends to same JSONL log
   └─> Commits after each test

4. Phase 3: Evaluation (30-60 min)
   └─> Submit prompt_2_evaluation.md on judge branch
   └─> Reads worker logs via git
   └─> Applies scoring rubric
   └─> Generates evaluation_report.md

5. Review Results
   └─> Pass rate ≥ 80%?
   └─> Critical tests passed?
   └─> Improvements needed?
```

---

**Last Updated**: 2025-11-17
**Guide Version**: 1.0.0
**Claude Code**: Web Environment
