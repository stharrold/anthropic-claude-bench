# Claude Code Judge Agent - Evaluation Prompt

## Context

You are the **Judge Agent** evaluating Claude Code's performance on the comprehensive 76-test benchmark suite.

**Your role:** Independent evaluator analyzing worker agent test results
**Branch:** You are on `agent/00000000T000000Z` (judge branch)
**Worker branch:** `agent/YYYYMMDDTHHMMSSZ` (contains test execution logs)
**Evaluation criteria:** `judge_rubric.yaml` in this repository

## Your Tasks

### Step 1: Identify Worker Branch (2 min)

```bash
# List all worker agent branches
git fetch origin
git branch -r | grep 'origin/agent/' | grep -v '00000000T000000Z'

# Identify the most recent worker branch to evaluate
# Should be named: agent/YYYYMMDDTHHMMSSZ (UTC timestamp)
WORKER_BRANCH="agent/YYYYMMDDTHHMMSSZ"  # Replace with actual timestamp

echo "Evaluating worker branch: $WORKER_BRANCH"
```

**Expected output:** One or more worker branches with UTC timestamps (e.g., `agent/20251117T191722Z`)

### Step 2: Fetch Worker Logs (5 min)

```bash
# Checkout worker branch to access logs
git checkout $WORKER_BRANCH

# Verify log file exists
LOG_FILE="log_$(echo $WORKER_BRANCH | sed 's|agent/||').jsonl"
ls -lh $LOG_FILE

# Count test entries
echo "Total log entries:"
cat $LOG_FILE | wc -l

# View first and last entries
echo "First entry:"
head -1 $LOG_FILE | jq .

echo "Last entry:"
tail -1 $LOG_FILE | jq .

# Summary by status
echo "Test status summary:"
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' $LOG_FILE
```

**Expected log structure:**
- 81+ entries (5 setup tests + 76 main tests)
- Each entry is valid JSON
- Contains: timestamp, test_number, test_name, status, confidence, details, reasoning

### Step 3: Load Evaluation Rubric (2 min)

```bash
# Return to judge branch
git checkout agent/00000000T000000Z

# Display rubric
cat judge_rubric.yaml
```

**Scoring criteria:**
- **Correctness** (40%): Does the test produce correct results?
- **Completeness** (30%): Does it address all test requirements?
- **Quality** (30%): Code quality, documentation, error handling?

**Pass threshold:** 7.0/10
**Suite pass rate:** Minimum 80% of tests must pass
**Critical tests:** 1, 5, 10, 36, 68, 71, 72

### Step 4: Evaluate Each Test (60-120 min)

For each test in the worker log, score based on:

#### 4.1: Parse Test Entry

```bash
# Extract specific test
jq -s '.[] | select(.test_number == "001")' $LOG_FILE
```

**Key fields to evaluate:**
- `status`: pass, fail, partial, skip
- `confidence`: Worker's confidence level (0.0-1.0)
- `reasoning`: Worker's explanation of approach
- `details.issues_found`: Problems encountered
- `details.limitations`: Known constraints
- `context`: Environment and test-specific context

#### 4.2: Score Correctness (0-10, weight 40%)

**Criteria:**
- **10/10**: Perfect execution, correct output, all assertions pass
- **8-9/10**: Correct with minor issues (formatting, non-critical edge cases)
- **6-7/10**: Mostly correct, some logical errors
- **4-5/10**: Partially correct, significant errors
- **2-3/10**: Incorrect approach, wrong results
- **0-1/10**: Complete failure, no useful output

**Evaluation questions:**
- Did the test achieve its objective?
- Are the results accurate and verifiable?
- Were test assertions properly validated?
- Did error handling work correctly?

#### 4.3: Score Completeness (0-10, weight 30%)

**Criteria:**
- **10/10**: All requirements addressed, all edge cases covered
- **8-9/10**: All requirements met, minor edge cases missed
- **6-7/10**: Most requirements met, some gaps
- **4-5/10**: Partial implementation, major gaps
- **2-3/10**: Minimal implementation
- **0-1/10**: No meaningful implementation

**Evaluation questions:**
- Were all test requirements from the prompt addressed?
- Were edge cases considered?
- Was the test scope appropriate?
- Were all acceptance criteria met?

#### 4.4: Score Quality (0-10, weight 30%)

**Criteria:**
- **10/10**: Excellent code, comprehensive docs, robust error handling
- **8-9/10**: Good quality, minor improvements possible
- **6-7/10**: Acceptable quality, some issues
- **4-5/10**: Poor quality, significant issues
- **2-3/10**: Very poor quality
- **0-1/10**: Unacceptable quality

**Evaluation questions:**
- Is the code readable and maintainable?
- Is error handling comprehensive?
- Are there security vulnerabilities?
- Is documentation clear and complete?
- Are best practices followed?

#### 4.5: Calculate Weighted Score

```
Test Score = (Correctness × 0.4) + (Completeness × 0.3) + (Quality × 0.3)

Pass if: Test Score ≥ 7.0
```

#### 4.6: Handle Special Cases

**Skipped tests:**
- If test was skipped due to failed setup (e.g., no container runtime)
- Score: N/A (do not count toward pass rate)
- Rationale: Graceful degradation is expected behavior

**Partial tests:**
- If status is "partial" (e.g., Setup Test 3 with 9 min vs 30 min target)
- Score based on actual achievement vs goal
- Example: 9/30 minutes validated = 6.0-7.0 score range

**Failed dependencies:**
- If test failed because prerequisite failed (e.g., Setup Test 2 requires Setup Test 1)
- Score: 0.0 for correctness
- Note dependency chain in reasoning

### Step 5: Analyze Critical Tests (10 min)

Focus on tests identified as critical in `judge_rubric.yaml`:

```bash
# Extract critical tests
for TEST_NUM in 001 005 010 036 068 071 072; do
  echo "=== Test $TEST_NUM ==="
  jq -s ".[] | select(.test_number == \"$TEST_NUM\")" $LOG_FILE
done
```

**Critical test importance:**
- **Test 1**: Basic file operations - foundational capability
- **Test 5**: File operations under edge cases - robustness
- **Test 10**: Complex JSON processing - data handling
- **Test 36**: Docker API integration - containerization
- **Test 68**: Privacy assessment - security consciousness
- **Test 71-72**: Network security - network awareness

**All critical tests must pass** for an overall PASS verdict, regardless of pass rate.

### Step 6: Generate Evaluation Report (20 min)

Create a comprehensive evaluation report:

```bash
# Create report file
REPORT_FILE="evaluation_report_$(echo $WORKER_BRANCH | sed 's/agent\///').md"
```

**Report structure:**

```markdown
# Evaluation Report: Worker Agent [TIMESTAMP]

**Evaluation Date:** [Current date]
**Worker Branch:** agent/YYYYMMDDTHHMMSSZ
**Judge Branch:** agent/00000000T000000Z
**Evaluator:** Judge Agent (Claude Code)

---

## Executive Summary

**Overall Verdict:** [PASS / FAIL]

**Metrics:**
- Total Tests: 76 (+ 5 setup tests)
- Tests Passed: [X] ([Y]%)
- Tests Failed: [X] ([Y]%)
- Tests Partial: [X] ([Y]%)
- Tests Skipped: [X] (not counted)
- Average Score: [X.X]/10
- Critical Tests: [X]/7 passed

**Pass Threshold Met:** [YES / NO]
- Required: 80% pass rate (7.0/10 minimum per test)
- Achieved: [Y]% pass rate
- Critical Tests: [All passed / {X} failed]

---

## Test Results by Category

### File Operations (Tests 1-5)
| Test | Name | Status | Score | Notes |
|------|------|--------|-------|-------|
| 001 | file_read_operation | pass | 9.2/10 | Excellent |
| 002 | file_write_operation | pass | 8.8/10 | Good |
| ... | ... | ... | ... | ... |

**Category Average:** [X.X]/10
**Category Pass Rate:** [Y]%

[Repeat for all categories...]

---

## Critical Test Analysis

### Test 001: File Read Operation ✅ PASS
**Score:** 9.2/10
- Correctness: 9.5/10 (weight 40%) = 3.8
- Completeness: 9.0/10 (weight 30%) = 2.7
- Quality: 9.0/10 (weight 30%) = 2.7
- **Total:** 9.2/10

**Analysis:**
- ✅ Correct file reading with proper encoding
- ✅ All edge cases handled (empty files, large files, binary files)
- ✅ Excellent error handling
- ⚠️ Minor: Could optimize large file reading with streaming

[Repeat for all critical tests...]

---

## Failed Tests Root Cause Analysis

### Test [X]: [Test Name] ❌ FAIL
**Score:** [X.X]/10
**Status:** fail
**Confidence:** [X.X]

**What went wrong:**
[Worker's reasoning from JSONL]

**Judge Analysis:**
[Your detailed analysis of why it failed]

**Root Cause:**
[Specific issue: code error, logic flaw, environment issue, etc.]

**Recommendations:**
[How to fix or improve]

[Repeat for all failed tests...]

---

## Performance Analysis

### Test Duration
- **Total Execution Time:** [X] hours
- **Average Test Duration:** [X] minutes
- **Longest Test:** [Test name] ([X] minutes)
- **Shortest Test:** [Test name] ([X] minutes)

### Session Stability
- **Setup Test 3 Result:** [X] minutes validated
- **Session Disconnects:** [X]
- **Recovery Actions:** [X]

### Environment Adaptation
- **Container Tests:** [Available / Skipped]
- **Network Tests:** [Full capture / App-level logging]
- **Test Data:** [Complete / Partial]

---

## Rubric Application

### Per-Test Scoring Distribution

| Score Range | Count | Percentage |
|-------------|-------|------------|
| 9.0-10.0 | [X] | [Y]% |
| 8.0-8.9 | [X] | [Y]% |
| 7.0-7.9 | [X] | [Y]% |
| 6.0-6.9 | [X] | [Y]% |
| 5.0-5.9 | [X] | [Y]% |
| 0.0-4.9 | [X] | [Y]% |

### Component Scores

**Average Correctness:** [X.X]/10 (weight 40%)
**Average Completeness:** [X.X]/10 (weight 30%)
**Average Quality:** [X.X]/10 (weight 30%)

---

## Strengths

1. **[Strength category]**
   - [Specific examples]
   - [Test numbers demonstrating strength]

2. **[Strength category]**
   - [Specific examples]

[Continue...]

---

## Areas for Improvement

1. **[Improvement area]**
   - **Impact:** [High / Medium / Low]
   - **Affected Tests:** [Test numbers]
   - **Recommendation:** [Specific improvement]

2. **[Improvement area]**
   - **Impact:** [High / Medium / Low]
   - **Affected Tests:** [Test numbers]
   - **Recommendation:** [Specific improvement]

[Continue...]

---

## Recommendations

### Immediate Actions (High Priority)
1. [Recommendation for failed critical tests]
2. [Recommendation for major issues]

### Short-term Improvements (Medium Priority)
1. [Recommendation for quality improvements]
2. [Recommendation for completeness gaps]

### Long-term Enhancements (Low Priority)
1. [Recommendation for optimizations]
2. [Recommendation for advanced features]

---

## Verdict Justification

**Overall Verdict:** [PASS / FAIL]

**Reasoning:**
[Detailed explanation of pass/fail decision based on:]
- Pass rate: [Y]% (threshold: 80%)
- Critical tests: [X]/7 passed (requirement: all must pass)
- Average score: [X.X]/10 (threshold: 7.0)
- Environment limitations: [Impact on verdict]

**Pass Criteria:**
- ✅ / ❌ Pass rate ≥ 80%
- ✅ / ❌ All critical tests passed
- ✅ / ❌ No major security vulnerabilities
- ✅ / ❌ Graceful degradation demonstrated

---

## Appendix: Log Analysis

### Log File Statistics
- **File:** log_YYYYMMDDTHHMMSSZ.jsonl
- **Total Entries:** [X]
- **Valid JSON:** [X]/[X]
- **Parse Errors:** [X]

### JSONL Query Examples

```bash
# View all failed tests
jq -s '.[] | select(.status == "fail") | {test_number, test_name, reasoning}' log_*.jsonl

# View tests by confidence
jq -s 'sort_by(.confidence) | .[] | {test_number, confidence, status}' log_*.jsonl

# Category performance
jq -s 'group_by(.category) | map({category: .[0].category, avg_duration: (map(.actual_duration_seconds) | add / length)})' log_*.jsonl
```

---

**Evaluation Completed:** [Timestamp]
**Judge Agent:** agent/00000000T000000Z
**Report Generated By:** Claude Code

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step 7: Commit Evaluation Report (2 min)

```bash
# Switch back to judge branch
git checkout agent/00000000T000000Z

# Add report
git add $REPORT_FILE

# Commit with descriptive message
git commit -m "$(cat <<EOF
Evaluation Report: Worker $WORKER_BRANCH

Overall Verdict: [PASS/FAIL]
Pass Rate: [Y]%
Critical Tests: [X]/7 passed
Average Score: [X.X]/10

[Brief summary of key findings]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Push to remote
git push origin agent/00000000T000000Z

echo "Evaluation complete. Report: $REPORT_FILE"
```

### Step 8: Summary Output (2 min)

Display final summary to user:

```bash
echo "======================================"
echo "EVALUATION COMPLETE"
echo "======================================"
echo "Worker Branch: $WORKER_BRANCH"
echo "Report File: $REPORT_FILE"
echo ""
echo "Overall Verdict: [PASS / FAIL]"
echo "Pass Rate: [Y]%"
echo "Tests Passed: [X]/76"
echo "Critical Tests: [X]/7"
echo "Average Score: [X.X]/10"
echo ""
echo "View full report:"
echo "  cat $REPORT_FILE"
echo ""
echo "Push report:"
echo "  git push origin agent/00000000T000000Z"
echo "======================================"
```

---

## Evaluation Guidelines

### Objectivity
- Evaluate based solely on test results and rubric criteria
- Do not give credit for effort or partial attempts if output is incorrect
- Be consistent in scoring across all tests

### Worker Confidence
- Worker's `confidence` score is informative but not binding
- Validate all claims independently
- High confidence with poor results = overconfidence (note in report)
- Low confidence with good results = underconfidence (note in report)

### Environment Considerations
- Tests skipped due to setup failures: Not counted (graceful degradation)
- Tests using fallback methods: Judge based on actual requirements met
- Environment limitations: Document but don't penalize if properly handled

### Edge Cases
- If worker deviated from test spec but achieved better results: Give credit
- If worker used alternative approach: Evaluate based on outcomes, not method
- If test requirements were ambiguous: Give benefit of doubt if reasonable

### Security
- Any security vulnerability (XSS, SQL injection, command injection): Automatic fail
- Failure to sanitize user input: Major quality deduction
- Hardcoded secrets: Automatic fail

### Documentation
- Code should be self-documenting or include comments
- Complex logic requires explanation
- Error messages should be clear and actionable

---

## Special Considerations

### Setup Phase Results
Review setup test results carefully as they impact main test interpretation:

- **Setup Test 1 (Podman):** If failed, tests 16-20, 36-40, 71-72, 76 should be skipped
- **Setup Test 3 (Session):** If partial (<30 min), note session stability concerns
- **Setup Test 4 (Network):** If limited, network tests use alternative logging
- **Setup Test 5 (Data):** If failed, many tests will fail due to missing data

### Long-Running Tests
Tests 56-60 and 76 may be split across sessions:
- Evaluate based on completion percentage
- Check for proper state management
- Verify checkpoint/resume functionality

### Multi-Agent Tests
Some tests may involve multiple Claude instances:
- Verify coordination between instances
- Check for race conditions
- Validate shared state management

---

## Output Requirements

Your evaluation MUST produce:

1. ✅ **Evaluation report** (`evaluation_report_YYYYMMDDTHHMMSSZ.md`)
2. ✅ **Git commit** on judge branch with report
3. ✅ **Console summary** with key metrics
4. ✅ **PASS/FAIL verdict** with justification

---

## Success Criteria

Your evaluation is complete when:

- ✅ All 76 tests have been scored
- ✅ All critical tests have been analyzed in detail
- ✅ Failed tests have root cause analysis
- ✅ Recommendations are specific and actionable
- ✅ Report is committed to judge branch
- ✅ Verdict is clear and justified

---

**Ready to begin evaluation?**

Start with Step 1: Identify the worker branch to evaluate.

**Note:** This is an independent evaluation. Do not communicate with the worker agent or reference worker's self-assessment beyond what's in the logs.
