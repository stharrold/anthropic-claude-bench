# Claude Code Testing Environment

This repository contains a comprehensive 76-test benchmark suite for testing Claude Code's capabilities across multiple domains.

## Quick Start

### First Time Setup

1. **Run the environment setup script:**
   ```bash
   chmod +x setup_environment.sh
   ./setup_environment.sh
   ```

2. **Review setup results:**
   - Check `setup_environment.log` for detailed setup information
   - Review `environment_capabilities.txt` for available features
   - See `setup_report.md` for initial environment validation results

3. **Verify test data:**
   ```bash
   ls -la /tmp/test-data/
   ```

### Session Start Checks

Each time you start a new Claude Code session, the SessionStart hook (configured in `.claude/settings.json`) will automatically:
- Display environment information
- Check for required tools (Python, Node, Git)
- Verify test data availability
- Show quick capability summary

## Project Structure

```
anthropic-claude-bench/
├── .claude/
│   └── settings.json          # SessionStart hooks and environment config
├── setup_environment.sh        # Main environment setup script
├── setup_report.md            # Initial setup phase results (5 tests)
├── judge_rubric.yaml          # Evaluation criteria for judge agent
├── test_data_manifest.txt     # Test data inventory
├── environment_capabilities.txt # Current environment capabilities
├── log_YYYYMMDDTHHMMSSZ.jsonl # Test execution logs
└── CLAUDE.md                  # This file
```

## Test Suite Overview

### 76-Test Benchmark Categories

The test suite is divided into several categories:

1. **File Operations (Tests 1-5)**
   - Basic file read/write operations
   - File system navigation
   - Permission handling

2. **JSON Processing (Tests 6-10)**
   - JSON parsing and validation
   - Large file handling
   - Error recovery

3. **Container Operations (Tests 16-20, 36-40)**
   - Docker/Podman image management
   - Container lifecycle operations
   - **Note:** Requires container runtime (Podman or Docker)

4. **Image Processing (Tests 11-15)**
   - Image metadata extraction
   - Format conversion
   - Batch processing

5. **Medical Data (FHIR) (Tests 21-25)**
   - FHIR resource validation
   - Healthcare data standards
   - Privacy compliance

6. **GDPR Compliance (Tests 26-30)**
   - Data protection validation
   - User consent management
   - Right to erasure

7. **RAG/Search (Tests 31-35)**
   - Document retrieval
   - Semantic search
   - Context extraction

8. **Git Operations (Tests 41-45)**
   - Repository management
   - Branch operations
   - Merge conflict resolution

9. **API Integration (Tests 46-50)**
   - RESTful API interactions
   - Authentication handling
   - Rate limiting

10. **Research/Citations (Tests 51-55)**
    - Academic citation parsing
    - DOI resolution
    - Bibliography management

11. **Privacy & Security (Tests 68, 71-72)**
    - Data leak prevention
    - Network monitoring
    - Secure communications
    - **Note:** May require network packet capture tools

12. **Long-running Operations (Tests 56-60, 76)**
    - Session stability
    - Progress tracking
    - State management

## Dependencies

### Required (Pre-installed in Claude Code)

- **Python 3.x** - Core scripting and test execution
- **Node.js LTS** - JavaScript tooling
- **Git** - Version control operations

### Optional (Install via setup script)

- **Podman/Docker** - Container runtime for tests 16-20, 36-40, 71-72, 76
- **Python packages:**
  - `Pillow` - Image processing
  - `Faker` - Synthetic data generation
  - `scapy` - Network packet capture (for tests 68, 71-72)

### Network Tools (Optional)

- **tcpdump** - Packet capture (requires root privileges)
- **tshark** - Wireshark CLI tool

## Test Data

### Generated Datasets

The setup script generates comprehensive test data in `/tmp/test-data/`:

| Dataset | Count | Location | Purpose |
|---------|-------|----------|---------|
| JSON Files | 50 | `json-files/` | JSON processing tests (45 valid, 5 invalid) |
| Images | 1000 | `images/` | Image processing tests (various formats) |
| FHIR Patients | 100 | `medical/fhir/` | Healthcare data tests |
| GDPR Users | 1000 | `gdpr/users.json` | Privacy compliance tests |
| RAG Articles | 99 | `rag/articles/` | Search and retrieval tests |
| Research Papers | 15 | `research/papers.json` | Citation tests |

**Total Size:** ~124 MB

### Data Regeneration

To regenerate test data:
```bash
rm -rf /tmp/test-data
./setup_environment.sh
```

## Environment Capabilities

### Current Limitations (as of setup phase)

Based on the initial setup tests (`setup_report.md`):

1. **Container Runtime:**
   - Status: Not available
   - Impact: Tests 16-20, 36-40, 71-72, 76 must be skipped
   - Fix: Install Podman or start Docker daemon

2. **Network Monitoring:**
   - Status: Limited (tcpdump requires root)
   - Impact: Tests 68, 71-72 will use application-level logging
   - Fix: Install tshark or configure tcpdump with privileges

3. **Session Duration:**
   - Validated: 9 minutes of stable operation
   - Target: 30 minutes
   - Impact: May need to split long-running tests into phases

### Strengths

- ✅ Full Python environment with package management
- ✅ Complete test data generation (all datasets)
- ✅ Git operations fully functional
- ✅ File and data processing capabilities
- ✅ Stable session management (validated 9+ minutes)

## Running Tests

### Manual Test Execution

```bash
# Run specific test
python3 tests/test_001_file_operations.py

# Run test category
python3 tests/run_category.py --category json

# Run all tests (excluding skipped)
python3 tests/run_all.py --skip-containers
```

### Automated Test Execution

The worker agent on branch `agent/YYYYMMDDTHHMMSSZ` will execute tests and log results to `log_YYYYMMDDTHHMMSSZ.jsonl`.

### Evaluation

The judge agent on branch `agent/00000000T000000Z` will evaluate test results based on `judge_rubric.yaml`:

- **Per-test scoring:** Correctness (40%), Completeness (30%), Quality (30%)
- **Pass threshold:** 7.0/10
- **Suite-level:** Minimum 80% pass rate
- **Critical tests:** 1, 5, 10, 36, 68, 71, 72

## Git Workflow

### Branch Strategy

- `main` - Stable baseline
- `develop` - Integration branch
- `agent/00000000T000000Z` - Judge agent branch (evaluation)
- `agent/YYYYMMDDTHHMMSSZ` - Worker agent branches (test execution)

### Logging

All test execution is logged in JSONL format:
```json
{
  "timestamp": "2025-11-17T19:30:00Z",
  "test_number": "001",
  "test_name": "file_read_operation",
  "status": "pass",
  "confidence": 0.95,
  "details": {...}
}
```

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

## Troubleshooting

### Test Data Not Found

```bash
# Regenerate test data
./setup_environment.sh
```

### Container Tests Failing

```bash
# Check container runtime
podman --version || docker --version

# Start Docker daemon (if installed)
# System-specific - may require manual intervention
```

### Python Package Import Errors

```bash
# Reinstall Python dependencies
pip3 install --user Pillow Faker scapy
```

### Session Timeout

For long-running tests, consider:
1. Splitting tests into multiple sessions
2. Using checkpoint/resume mechanisms
3. Periodic git commits to save state

## Additional Resources

- **Setup Log:** `setup_environment.log` - Detailed setup process
- **Capabilities:** `environment_capabilities.txt` - Current environment status
- **Setup Report:** `setup_report.md` - Initial validation results (5 tests)
- **Judge Rubric:** `judge_rubric.yaml` - Evaluation criteria
- **Test Logs:** `log_*.jsonl` - Test execution logs

## Documentation References

- [Claude Code on the Web](https://code.claude.com/docs/en/claude-code-on-the-web)
- [Claude Code Documentation](https://code.claude.com/docs)

## Support

For issues or questions:
1. Check the setup log: `setup_environment.log`
2. Review environment capabilities: `environment_capabilities.txt`
3. Consult the setup report: `setup_report.md`
4. Check test execution logs: `log_*.jsonl`

---

**Last Updated:** 2025-11-17
**Environment:** Claude Code on the Web
**Test Suite Version:** 1.0
**Total Tests:** 76 (setup) + 76 (main suite)
