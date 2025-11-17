# Claude Code Setup Phase - Execution Prompt

## Context

You are testing Claude Code's capabilities through a comprehensive 76-test suite. Before executing the main tests, you must run 5 setup tests to validate the environment and generate test data.

**Your role:** Worker agent executing setup tests
**Branch strategy:** You will work in `agent/YYYYMMDDTHHMMSSZ` (timestamp matches log file)
**Evaluation:** A separate judge agent on `agent/00000000T000000Z` will later evaluate your work

## Prerequisites (Already Complete)

✅ User created `develop` branch from `main`
✅ User created `agent/00000000T000000Z` (judge branch) with `judge_rubric.yaml`
✅ You are starting from `develop` branch

## Your Tasks

### Step 1: Create Your Worker Branch (2 min)

```bash
# Create timestamped branch
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
git checkout -b agent/$TIMESTAMP
echo "Created branch: agent/$TIMESTAMP"

# Initialize JSONL log
LOG_FILE="log_${TIMESTAMP}.jsonl"
cat > "$LOG_FILE" << EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","event":"test_suite_started","phase":"setup","total_tests":5}
EOF

# Commit initial log
git add "$LOG_FILE"
git commit -m "Initialize setup phase: $TIMESTAMP"
git push -u origin agent/$TIMESTAMP

echo "Log file: $LOG_FILE"
echo "Branch: agent/$TIMESTAMP"
```

### Step 2: Execute Setup Tests (1-2 hours)

Run each setup test sequentially. After each test, log results to JSONL and commit.

---

## Setup Test 1: Podman Availability (10 min)

**Objective:** Verify Podman installation and basic functionality

**Actions:**
```bash
# Check Podman version
podman --version

# Pull test image
podman pull docker.io/library/alpine:latest

# Run test container
podman run --rm alpine echo "Podman test successful"

# Test network operations
podman network create test-net
podman network ls | grep test-net
podman network rm test-net

# Verify cleanup
podman ps -a
```

**Acceptance Criteria:**
- Podman version ≥4.0
- Image pulls successfully
- Container runs and exits with code 0
- Network create/remove succeeds
- No orphaned containers

**If Failed:** Document failure reason. Main test suite will skip container tests (16-20, 36-40, 71-72, 76).

**Log Entry:**
```json
{
  "timestamp": "2025-11-05T14:30:22Z",
  "test_number": "setup_01",
  "test_name": "podman_availability",
  "category": "environment_validation",
  "status": "pass|fail",
  "confidence": 0.0-1.0,
  "estimated_duration_seconds": 600,
  "actual_duration_seconds": 0,
  "context": {
    "podman_version": "",
    "image_pulled": true|false,
    "container_ran": true|false,
    "network_ops": true|false
  },
  "details": {
    "approach": "Sequential validation of Podman functionality",
    "issues_found": [],
    "limitations": []
  },
  "reasoning": "Why this test passed or failed",
  "decision": "proceed_with_containers|skip_container_tests"
}
```

**Commit:**
```bash
git add "$LOG_FILE"
git commit -m "Setup Test #1: podman_availability - pass"
git push origin agent/$TIMESTAMP
```

---

## Setup Test 2: Nested Containerization (15 min)

**Objective:** Verify Podman-in-Podman capability

**Actions:**
```bash
# Test nested Podman
podman run --privileged \
  quay.io/podman/stable \
  podman run alpine echo "Nested container works"

# Test resource limits
podman run --rm \
  --memory=512m \
  --cpus=0.5 \
  alpine sh -c 'echo "Memory: $(free -m | grep Mem | awk '\''{print $2}'\'')MB"; echo "CPUs: $(nproc)"'

# Test volume mounts
mkdir -p /tmp/test-volume
echo "test data" > /tmp/test-volume/test.txt
podman run --rm \
  -v /tmp/test-volume:/data:ro \
  alpine cat /data/test.txt

# Cleanup
rm -rf /tmp/test-volume
```

**Acceptance Criteria:**
- Nested Podman container executes successfully
- Resource limits are enforced (memory ~512MB, CPUs limited)
- Volume mounts are accessible

**If Failed:** Document capabilities. May need to use Docker API or skip advanced container tests.

**Log Entry:**
```json
{
  "timestamp": "2025-11-05T14:45:22Z",
  "test_number": "setup_02",
  "test_name": "nested_containerization",
  "category": "environment_validation",
  "status": "pass|fail|partial",
  "confidence": 0.0-1.0,
  "estimated_duration_seconds": 900,
  "actual_duration_seconds": 0,
  "context": {
    "nested_podman": true|false,
    "resource_limits_enforced": true|false,
    "volumes_accessible": true|false
  },
  "details": {
    "approach": "Test Podman advanced features",
    "issues_found": [],
    "limitations": []
  },
  "reasoning": "",
  "decision": "use_nested_containers|use_docker_api|skip_advanced_container_tests"
}
```

**Commit:**
```bash
git add "$LOG_FILE"
git commit -m "Setup Test #2: nested_containerization - pass"
git push origin agent/$TIMESTAMP
```

---

## Setup Test 3: Session Duration Test (30 min)

**Objective:** Determine maximum continuous session time

**Actions:**
```bash
# Start long-running process with heartbeat monitoring
(
  START_TIME=$(date +%s)
  TARGET_DURATION=1800  # 30 minutes
  
  echo "Starting 30-minute session test at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  while [ $(($(date +%s) - START_TIME)) -lt $TARGET_DURATION ]; do
    ELAPSED=$(($(date +%s) - START_TIME))
    echo "Heartbeat: ${ELAPSED}s elapsed"
    
    # Test git operations during long-running process
    if [ $((ELAPSED % 300)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
      echo "Testing git push at ${ELAPSED}s..."
      date > heartbeat_${ELAPSED}.txt
      git add heartbeat_${ELAPSED}.txt
      git commit -m "Heartbeat check at ${ELAPSED}s"
      git push origin agent/$TIMESTAMP
      echo "Git push successful at ${ELAPSED}s"
    fi
    
    sleep 60
  done
  
  echo "30-minute session test completed successfully at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
)
```

**Acceptance Criteria:**
- Process completes 30 minutes without interruption
- Git operations succeed throughout
- No session timeout warnings
- Heartbeat logs created at 5, 10, 15, 20, 25, 30 minute marks

**If Timeout Occurs:** Document when timeout happened. Plan to split main test phases into separate sessions.

**Log Entry:**
```json
{
  "timestamp": "2025-11-05T15:30:22Z",
  "test_number": "setup_03",
  "test_name": "session_duration",
  "category": "environment_validation",
  "status": "pass|timeout",
  "confidence": 0.0-1.0,
  "estimated_duration_seconds": 1800,
  "actual_duration_seconds": 0,
  "timeout_triggered": false,
  "context": {
    "target_duration_seconds": 1800,
    "achieved_duration_seconds": 0,
    "git_operations_during_test": 6,
    "git_operations_successful": 0
  },
  "details": {
    "approach": "Long-running process with periodic git operations",
    "issues_found": [],
    "limitations": [],
    "heartbeat_timestamps": []
  },
  "reasoning": "",
  "decision": "single_session_viable|split_into_multiple_sessions"
}
```

**Commit:**
```bash
# Clean up heartbeat files
rm -f heartbeat_*.txt
git add "$LOG_FILE"
git commit -m "Setup Test #3: session_duration - pass"
git push origin agent/$TIMESTAMP
```

---

## Setup Test 4: Network Tools Access (10 min)

**Objective:** Verify packet capture tools for privacy tests

**Actions:**
```bash
# Check for tcpdump (requires root)
if command -v tcpdump &> /dev/null; then
  echo "tcpdump found"
  tcpdump --version
  
  # Test capture (requires privileges)
  timeout 5 tcpdump -i any -c 10 port 443 2>&1 || echo "tcpdump requires root"
else
  echo "tcpdump not available"
fi

# Check for tshark
if command -v tshark &> /dev/null; then
  echo "tshark found"
  tshark --version
else
  echo "tshark not available"
fi

# Fallback: Python scapy
python3 << 'EOF'
try:
    from scapy.all import sniff, IP
    print("scapy available")
    # Test basic capture (may require privileges)
    # packets = sniff(count=1, timeout=2)
    print("scapy import successful")
except ImportError:
    print("scapy not available - install with: pip install scapy")
except Exception as e:
    print(f"scapy available but capture failed: {e}")
EOF

# Determine best option
echo "Network monitoring strategy determined"
```

**Acceptance Criteria:**
- At least one packet capture tool is available
- Tool can be executed (even if requires privileges)

**If Failed:** Tests 68, 71-72 will use application-level logging instead of network monitoring.

**Log Entry:**
```json
{
  "timestamp": "2025-11-05T15:45:22Z",
  "test_number": "setup_04",
  "test_name": "network_tools",
  "category": "environment_validation",
  "status": "pass|partial|fail",
  "confidence": 0.0-1.0,
  "estimated_duration_seconds": 600,
  "actual_duration_seconds": 0,
  "context": {
    "tcpdump_available": false,
    "tshark_available": false,
    "scapy_available": false,
    "requires_root": false
  },
  "details": {
    "approach": "Check multiple packet capture tools",
    "issues_found": [],
    "limitations": ["No root access for tcpdump"],
    "selected_tool": "scapy|app_level_logging"
  },
  "reasoning": "",
  "decision": "use_packet_capture|use_app_level_logging"
}
```

**Commit:**
```bash
git add "$LOG_FILE"
git commit -m "Setup Test #4: network_tools - pass"
git push origin agent/$TIMESTAMP
```

---

## Setup Test 5: Test Data Generation (30-45 min)

**Objective:** Generate all test datasets required for main tests

**Actions:**

### 5a. JSON Files (5 min)
```bash
mkdir -p /test-data/json-files

python3 << 'EOF'
import json
import random
import os

# Generate 50 JSON files
for i in range(50):
    size_kb = random.randint(100, 1000)
    
    # 90% valid, 10% invalid
    is_valid = i < 45
    
    data = {
        "id": i,
        "timestamp": "2025-11-05T00:00:00Z",
        "records": [
            {"key": f"record_{j}", "value": random.randint(1, 1000)}
            for j in range(size_kb)
        ]
    }
    
    if not is_valid:
        # Introduce error for testing
        data["records"] = "invalid_should_be_array"
    
    with open(f"/test-data/json-files/data_{i:03d}.json", "w") as f:
        json.dump(data, f)

print("Generated 50 JSON files")
EOF
```

### 5b. Images (15 min)
```bash
mkdir -p /test-data/images

python3 << 'EOF'
from PIL import Image
import random

# Generate 1000 test images
for i in range(1000):
    # Random size between 500x500 and 2000x2000
    width = random.randint(500, 2000)
    height = random.randint(500, 2000)
    
    # Create image with random color
    img = Image.new('RGB', (width, height), 
                    color=(random.randint(0, 255), 
                           random.randint(0, 255), 
                           random.randint(0, 255)))
    
    # Save in different formats
    format_choice = ['JPEG', 'PNG', 'WEBP'][i % 3]
    ext = format_choice.lower() if format_choice != 'JPEG' else 'jpg'
    
    img.save(f"/test-data/images/image_{i:04d}.{ext}", format=format_choice, quality=85)
    
    if (i + 1) % 100 == 0:
        print(f"Generated {i + 1}/1000 images")

print("Generated 1000 images")
EOF
```

### 5c. Medical Data (10 min)
```bash
mkdir -p /test-data/medical/fhir

# Install and run Synthea
# Note: This may take 10-15 minutes
pip install --break-system-packages synthea || pip install synthea

# Generate 100 synthetic patients
python3 << 'EOF'
import subprocess
import json
from pathlib import Path

# Alternative: Use Faker to generate FHIR-like synthetic data
from faker import Faker
fake = Faker()

for i in range(100):
    patient = {
        "resourceType": "Patient",
        "id": f"patient-{i:03d}",
        "name": [{"given": [fake.first_name()], "family": fake.last_name()}],
        "gender": fake.random_element(["male", "female"]),
        "birthDate": fake.date_of_birth(minimum_age=18, maximum_age=90).isoformat(),
        "address": [{
            "city": fake.city(),
            "state": fake.state(),
            "postalCode": fake.zipcode()
        }]
    }
    
    with open(f"/test-data/medical/fhir/patient_{i:03d}.json", "w") as f:
        json.dump(patient, f, indent=2)

print("Generated 100 synthetic FHIR patients")
EOF
```

### 5d. GDPR Users (5 min)
```bash
mkdir -p /test-data/gdpr

python3 << 'EOF'
import json
from faker import Faker
from datetime import datetime, timedelta
import random

fake = Faker(['en_GB', 'fr_FR', 'de_DE', 'it_IT', 'es_ES'])

users = []
for i in range(1000):
    user = {
        "id": i,
        "name": fake.name(),
        "email": fake.email(),
        "address": {
            "street": fake.street_address(),
            "city": fake.city(),
            "postal_code": fake.postcode(),
            "country": fake.random_element(['UK', 'France', 'Germany', 'Italy', 'Spain'])
        },
        "phone": fake.phone_number(),
        "registration_date": (datetime.now() - timedelta(days=random.randint(1, 730))).isoformat(),
        "last_login": (datetime.now() - timedelta(days=random.randint(0, 30))).isoformat(),
        "consent_given": datetime.now().isoformat()
    }
    users.append(user)

with open("/test-data/gdpr/users.json", "w") as f:
    json.dump(users, f, indent=2)

print("Generated 1000 GDPR users")
EOF
```

### 5e. RAG Articles (10 min)
```bash
mkdir -p /test-data/rag/articles

python3 << 'EOF'
import json
from faker import Faker
fake = Faker()

topics = {
    "climate": ["climate change", "global warming", "renewable energy", "carbon emissions"],
    "technology": ["artificial intelligence", "machine learning", "quantum computing", "blockchain"],
    "health": ["nutrition", "mental health", "vaccines", "public health"]
}

article_id = 0
for category, keywords in topics.items():
    for i in range(33):  # ~100 total articles
        article = {
            "@context": "https://schema.org",
            "@type": "Article",
            "headline": f"{fake.sentence()} about {keywords[i % len(keywords)]}",
            "author": {
                "@type": "Person",
                "name": fake.name()
            },
            "datePublished": fake.date_this_year().isoformat(),
            "articleBody": " ".join([fake.paragraph() for _ in range(5)]),
            "keywords": keywords[i % len(keywords)]
        }
        
        with open(f"/test-data/rag/articles/article_{article_id:03d}.json", "w") as f:
            json.dump(article, f, indent=2)
        
        article_id += 1

print(f"Generated {article_id} schema.org articles")
EOF
```

### 5f. Research Papers (5 min)
```bash
mkdir -p /test-data/research

python3 << 'EOF'
import json

# Curated list of real research papers (DOIs verified)
papers = [
    {
        "title": "Attention Is All You Need",
        "authors": ["Vaswani et al."],
        "year": 2017,
        "doi": "10.48550/arXiv.1706.03762",
        "url": "https://arxiv.org/abs/1706.03762"
    },
    {
        "title": "BERT: Pre-training of Deep Bidirectional Transformers",
        "authors": ["Devlin et al."],
        "year": 2018,
        "doi": "10.48550/arXiv.1810.04805",
        "url": "https://arxiv.org/abs/1810.04805"
    },
    {
        "title": "GPT-3: Language Models are Few-Shot Learners",
        "authors": ["Brown et al."],
        "year": 2020,
        "doi": "10.48550/arXiv.2005.14165",
        "url": "https://arxiv.org/abs/2005.14165"
    },
    # Add 12 more papers...
    {
        "title": "Constitutional AI: Harmlessness from AI Feedback",
        "authors": ["Bai et al."],
        "year": 2022,
        "doi": "10.48550/arXiv.2212.08073",
        "url": "https://arxiv.org/abs/2212.08073"
    }
]

# Add more papers to reach 15
for i in range(11):
    papers.append({
        "title": f"Research Paper {i+4}",
        "authors": [f"Author {i}"],
        "year": 2023 + (i % 2),
        "doi": f"10.1234/example.{i:04d}",
        "url": f"https://example.com/paper{i}"
    })

with open("/test-data/research/papers.json", "w") as f:
    json.dump(papers, f, indent=2)

print(f"Generated {len(papers)} research paper references")
EOF
```

### 5g. Validation
```bash
# Verify all datasets
echo "Validating generated data..."

echo "JSON files: $(ls /test-data/json-files/*.json | wc -l)"
echo "Images: $(ls /test-data/images/* | wc -l)"
echo "FHIR patients: $(ls /test-data/medical/fhir/*.json | wc -l)"
echo "GDPR users: $(cat /test-data/gdpr/users.json | jq length)"
echo "RAG articles: $(ls /test-data/rag/articles/*.json | wc -l)"
echo "Research papers: $(cat /test-data/research/papers.json | jq length)"

# Check disk usage
du -sh /test-data

# Validate JSON files
python3 << 'EOF'
import json
import os

valid_count = 0
invalid_count = 0

for i in range(50):
    try:
        with open(f"/test-data/json-files/data_{i:03d}.json") as f:
            json.load(f)
        valid_count += 1
    except:
        invalid_count += 1

print(f"JSON validation: {valid_count} valid, {invalid_count} invalid")
assert valid_count == 45 and invalid_count == 5, "JSON validation failed"
EOF

echo "Data validation complete"
```

**Acceptance Criteria:**
- All datasets generated successfully
- JSON files: 50 (45 valid, 5 invalid)
- Images: 1000
- FHIR patients: 100
- GDPR users: 1000
- RAG articles: 100
- Research papers: 15
- Total disk usage < 3GB
- All JSON files parse correctly

**If Failed:** Cannot proceed with main tests (data is critical).

**Log Entry:**
```json
{
  "timestamp": "2025-11-05T16:30:22Z",
  "test_number": "setup_05",
  "test_name": "test_data_generation",
  "category": "environment_validation",
  "status": "pass|fail",
  "confidence": 0.0-1.0,
  "estimated_duration_seconds": 2700,
  "actual_duration_seconds": 0,
  "context": {
    "datasets_generated": {
      "json_files": 50,
      "images": 1000,
      "fhir_patients": 100,
      "gdpr_users": 1000,
      "rag_articles": 100,
      "research_papers": 15
    },
    "total_disk_usage_gb": 0.0,
    "validation_passed": true
  },
  "details": {
    "approach": "Generate realistic test data for all test categories",
    "issues_found": [],
    "limitations": []
  },
  "artifacts_created": [
    "/test-data/json-files/",
    "/test-data/images/",
    "/test-data/medical/fhir/",
    "/test-data/gdpr/users.json",
    "/test-data/rag/articles/",
    "/test-data/research/papers.json"
  ],
  "reasoning": ""
}
```

**Commit:**
```bash
# Note: Don't commit large binary data to git
# Instead, document data locations
echo "Test data location: /test-data" > test_data_manifest.txt
git add "$LOG_FILE" test_data_manifest.txt
git commit -m "Setup Test #5: test_data_generation - pass"
git push origin agent/$TIMESTAMP
```

---

## Step 3: Finalize Setup Log (2 min)

```bash
# Add completion event
cat >> "$LOG_FILE" << EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","event":"setup_phase_completed","tests_completed":5}
EOF

# Generate summary
echo "=== Setup Phase Summary ==="
jq -s 'group_by(.status) | map({status: .[0].status, count: length})' "$LOG_FILE"

# Commit final log
git add "$LOG_FILE"
git commit -m "Setup phase completed: 5/5 tests"
git push origin agent/$TIMESTAMP

echo "Setup complete. Branch: agent/$TIMESTAMP"
echo "Log file: $LOG_FILE"
```

---

## Step 4: Report Results

**Generate Go/No-Go Report:**

```bash
cat > setup_report.md << 'EOF'
# Setup Phase Results

## Environment Validation

| Test | Status | Decision |
|------|--------|----------|
| Podman Availability | PASS/FAIL | Proceed/Skip container tests |
| Nested Containerization | PASS/FAIL | Use nested/Use Docker/Skip |
| Session Duration | PASS/TIMEOUT | Single session/Split sessions |
| Network Tools | PASS/FAIL | Packet capture/App logging |
| Data Generation | PASS/FAIL | Proceed/ABORT |

## Capabilities Summary

- **Containerization:** Available/Limited/Unavailable
- **Session Limit:** 30+ min / <30 min
- **Network Monitoring:** Available/Limited/Unavailable
- **Test Data:** Complete (3GB)

## Recommendation

- [ ] **GO:** Proceed with full 76-test suite
- [ ] **GO (LIMITED):** Skip X tests, adjust Y
- [ ] **NO-GO:** Critical failure, cannot proceed

## Next Steps

If GO:
1. User reviews this report
2. User confirms: "Proceed with Phase 1"
3. Execute Tests 1-20 (2 hours)
EOF

git add setup_report.md
git commit -m "Add setup phase report"
git push origin agent/$TIMESTAMP

cat setup_report.md
```

---

## Success Criteria

**Setup phase passes if:**
- ✅ All 5 setup tests complete
- ✅ JSONL log is valid and complete
- ✅ Test data generated successfully (3GB)
- ✅ Environment capabilities documented
- ✅ 5 commits pushed to `agent/{timestamp}` branch

**Setup phase fails if:**
- ❌ Data generation fails (critical)
- ❌ Major environment issues prevent testing
- ❌ Git operations fail repeatedly

---

## Key Reminders

1. **Commit after every test** - This provides checkpointing
2. **JSONL must be valid** - Each line is a complete JSON object
3. **Log everything** - Judge agent only sees what's in the log
4. **Be explicit** - Document all assumptions and decisions
5. **Report honestly** - Self-assess confidence accurately

---

## After Completion

**Wait for user to:**
1. Review `log_{timestamp}.jsonl`
2. Review `setup_report.md`
3. Make go/no-go decision
4. If go, authorize: "Proceed with Phase 1 (Tests 1-20)"

**Do not proceed to main tests without explicit user approval.**

---

## Questions or Issues?

If you encounter:
- Git push failures → Retry 3 times, then log error
- Package installation failures → Try alternatives, document
- Timeouts or crashes → Log state, push what you have
- Unclear requirements → Make reasonable assumptions, document in log

Remember: Your work will be evaluated by a judge agent who only sees the logs. Make your reasoning transparent and complete.
