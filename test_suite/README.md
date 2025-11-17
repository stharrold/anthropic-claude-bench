# Claude Code Test Suite

A comprehensive meta-testing framework for evaluating Claude Code's capabilities through self-testing.

## Overview

This test suite contains **81 total tests** divided into three phases:

| Phase | Prompt File | Tests | Duration | Purpose |
|-------|------------|-------|----------|---------|
| **Phase 1: Setup** | `prompt_0_setup.md` | 5 tests | 1-2 hours | Environment validation |
| **Phase 2: Main** | `prompt_1_tests.md` | 76 tests | 13.5 hours | Comprehensive capability testing |
| **Phase 3: Evaluation** | `prompt_2_evaluation.md` | N/A | 30-60 min | Judge agent scoring |

## Quick Start

### Prerequisites

1. ✅ `.claude/settings.json` configured (SessionStart hooks)
2. ✅ Environment setup script available (`../setup_environment.sh`)
3. ✅ Judge rubric on branch `agent/00000000T000000Z`
4. ✅ Access to Claude Code on the Web (claude.ai/code)

### Execution Steps

```bash
# 1. Verify environment
cat ../.claude/settings.json
ls -la /tmp/test-data/ || ../setup_environment.sh

# 2. Open Claude Code Web (claude.ai/code)
# 3. Submit Phase 1 prompt:
cat prompt_0_setup.md  # Copy entire content

# 4. Wait for setup completion (~1-2 hours)
# 5. Submit Phase 2 prompt to SAME session:
cat prompt_1_tests.md  # Copy entire content

# 6. (Later) Submit Phase 3 prompt on judge branch:
cat prompt_2_evaluation.md  # Copy entire content
```

See [EXECUTION_GUIDE.md](./EXECUTION_GUIDE.md) for detailed instructions.

## File Structure

```
test_suite/
├── README.md                          # This file
├── EXECUTION_GUIDE.md                 # Detailed workflow instructions
├── prompt_0_setup.md                  # Phase 1: Setup tests
├── prompt_1_tests.md                  # Phase 2: Main test suite
├── prompt_2_evaluation.md             # Phase 3: Judge evaluation
└── examples/
    ├── example_setup_log.jsonl        # Sample setup phase log
    ├── example_test_log.jsonl         # Sample main phase log
    └── example_evaluation_report.md   # Sample judge report
```

## Test Categories

The 76 main tests cover:

- **File Operations** (Tests 1-5)
- **JSON Processing** (Tests 6-10)
- **Image Processing** (Tests 11-15)
- **Container Operations** (Tests 16-20, 36-40)
- **Medical/FHIR Data** (Tests 21-25)
- **GDPR Compliance** (Tests 26-30)
- **RAG/Search** (Tests 31-35)
- **Git Operations** (Tests 41-45)
- **API Integration** (Tests 46-50)
- **Research/Citations** (Tests 51-55)
- **Long-running Operations** (Tests 56-60)
- **Privacy & Security** (Tests 68, 71-72, 76)
- **Additional Tests** (Tests 61-67, 69-70, 73-75)

## Architecture

### Worker/Judge Pattern

```
┌─────────────────────────────────────┐
│  Worker Agent                       │
│  Branch: agent/YYYYMMDDTHHMMSSZ     │
│  ├─ Executes setup tests            │
│  ├─ Executes main tests             │
│  ├─ Logs to JSONL                   │
│  └─ Commits after each test         │
└─────────────────────────────────────┘
              ↓ (logs via git)
┌─────────────────────────────────────┐
│  Judge Agent                        │
│  Branch: agent/00000000T000000Z     │
│  ├─ Reads worker logs               │
│  ├─ Applies rubric scoring          │
│  └─ Generates evaluation report     │
└─────────────────────────────────────┘
```

### Logging Format

All test results are logged in JSONL format:

```json
{
  "timestamp": "2025-11-17T19:30:00Z",
  "test_number": "001",
  "test_name": "file_read_operation",
  "category": "file_operations",
  "status": "pass",
  "confidence": 0.95,
  "estimated_duration_seconds": 300,
  "actual_duration_seconds": 245,
  "context": {...},
  "details": {...},
  "reasoning": "...",
  "decision": "..."
}
```

### Graceful Degradation

Setup phase tests determine environment capabilities. Failed setup tests trigger adaptive behavior:

- ❌ **Setup Test 1 fails** → Skip container tests (16-20, 36-40, 71-72, 76)
- ❌ **Setup Test 4 fails** → Use application-level logging for network tests
- ⚠️ **Setup Test 3 partial** → Split long-running tests into phases

## Scoring Rubric

Per-test scoring (scale: 0-10):
- **Correctness**: 40% - Produces correct results
- **Completeness**: 30% - Addresses all requirements
- **Quality**: 30% - Code quality, documentation, robustness

**Pass threshold**: 7.0/10
**Suite pass rate**: 80% minimum
**Critical tests**: 1, 5, 10, 36, 68, 71, 72

## Environment Requirements

### Pre-installed (Claude Code Web)
- ✅ Python 3.9+
- ✅ Node.js LTS
- ✅ Git

### Auto-installed (via SessionStart hooks)
- ✅ Python packages: Pillow, Faker, scapy
- ✅ Test data: 124MB in /tmp/test-data/

### Optional (for full test coverage)
- ⚠️ Podman or Docker (container tests)
- ⚠️ tshark + ChmodBPF (network monitoring)

## Example Queries

Analyze test results with `jq`:

```bash
# Summary by status
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' log_*.jsonl

# All failed tests
jq -s '.[] | select(.status == "fail") | {test_name, reasoning}' log_*.jsonl

# Tests by category
jq -s 'group_by(.category) | map({category: .[0].category, count: length})' log_*.jsonl

# Duration analysis
jq -s 'map(.actual_duration_seconds) | add / length' log_*.jsonl

# Find specific test
jq -s '.[] | select(.test_number == "036")' log_*.jsonl
```

## Troubleshooting

### "Test data not found"
```bash
cd /Users/stharrold/Documents/GitHub/anthropic-claude-bench
./setup_environment.sh
```

### "Container runtime not available"
Setup phase will detect this and skip container tests automatically.

### "Session timeout"
Submit prompts in phases:
1. Complete setup phase first
2. Submit main tests in multiple sessions if needed
3. Commit after each test to save state

## Support

- **Project Documentation**: `../CLAUDE.md`
- **Setup Results**: `../setup_report.md`
- **Environment Status**: `../environment_status_final.md`
- **Capabilities**: `../environment_capabilities.txt`

## Version History

- **v1.0.0** (2025-11-17): Initial release
  - 5 setup tests
  - 76 main tests
  - Judge evaluation framework

---

**Last Updated**: 2025-11-17
**Test Suite Version**: 1.0.0
**Claude Code**: Web Environment
