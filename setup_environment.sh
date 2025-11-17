#!/bin/bash
# Claude Code Testing Environment Setup Script
# Based on: https://code.claude.com/docs/en/claude-code-on-the-web
#
# This script prepares the environment for running the 76-test Claude Code benchmark suite
# It addresses the limitations discovered during the setup phase.

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Setup variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATA_DIR="${TEST_DATA_DIR:-/tmp/test-data}"
LOG_FILE="${SCRIPT_DIR}/setup_environment.log"

# Functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}========================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}========================================${NC}" | tee -a "$LOG_FILE"
}

# Initialize log
echo "Setup started at $(date)" > "$LOG_FILE"

section "Claude Code Environment Setup"
log "Setup script directory: $SCRIPT_DIR"
log "Test data directory: $TEST_DATA_DIR"
log "Log file: $LOG_FILE"

# Step 1: Verify pre-installed Claude Code tools
section "Step 1: Verifying Pre-installed Tools"
log "Checking Claude Code pre-installed tools..."

if command -v check-tools &> /dev/null; then
    log "Running check-tools command..."
    check-tools | tee -a "$LOG_FILE" || true
else
    warning "check-tools command not available (may not be in Claude Code Web environment)"
fi

# Check key tools
log "Verifying key development tools..."
for tool in python3 node npm git; do
    if command -v "$tool" &> /dev/null; then
        version=$("$tool" --version 2>&1 | head -1)
        success "$tool: $version"
    else
        warning "$tool: NOT FOUND"
    fi
done

# Step 2: Check containerization tools
section "Step 2: Container Runtime Check"
CONTAINER_AVAILABLE=false

if command -v podman &> /dev/null; then
    PODMAN_VERSION=$(podman --version)
    success "Podman found: $PODMAN_VERSION"
    CONTAINER_RUNTIME="podman"
    CONTAINER_AVAILABLE=true
elif command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log "Docker found: $DOCKER_VERSION"

    # Test if Docker daemon is running
    if docker ps &> /dev/null; then
        success "Docker daemon is running"
        CONTAINER_RUNTIME="docker"
        CONTAINER_AVAILABLE=true
    else
        warning "Docker is installed but daemon is not running"
        log "Attempting to start Docker daemon..."
        # Note: May require user intervention or system privileges
        error "Cannot start Docker daemon automatically - requires manual intervention"
        CONTAINER_AVAILABLE=false
    fi
else
    warning "No container runtime found (Podman or Docker)"
    log "Tests 16-20, 36-40, 71-72, 76 will need to be skipped"
    CONTAINER_AVAILABLE=false
fi

# Step 3: Install Python dependencies
section "Step 3: Python Dependencies"
log "Installing required Python packages..."

PYTHON_PACKAGES=(
    "Pillow"
    "Faker"
    "scapy"
)

for package in "${PYTHON_PACKAGES[@]}"; do
    log "Installing $package..."
    if pip3 install --user "$package" >> "$LOG_FILE" 2>&1; then
        success "$package installed successfully"
    else
        warning "Failed to install $package - check log for details"
    fi
done

# Verify installations
log "Verifying Python package installations..."
python3 << 'EOF' | tee -a "$LOG_FILE"
import sys
packages_status = []

try:
    from PIL import Image
    packages_status.append(("Pillow", "✓ Available"))
except ImportError as e:
    packages_status.append(("Pillow", f"✗ Not available: {e}"))

try:
    from faker import Faker
    packages_status.append(("Faker", "✓ Available"))
except ImportError as e:
    packages_status.append(("Faker", f"✗ Not available: {e}"))

try:
    from scapy.all import sniff
    packages_status.append(("scapy", "✓ Available"))
except ImportError as e:
    packages_status.append(("scapy", f"✗ Not available: {e}"))

print("\nPython Package Status:")
for pkg, status in packages_status:
    print(f"  {pkg}: {status}")
EOF

# Step 4: Check network monitoring tools
section "Step 4: Network Monitoring Tools"
NETWORK_TOOLS_AVAILABLE=false

if command -v tcpdump &> /dev/null; then
    TCPDUMP_VERSION=$(tcpdump --version 2>&1 | head -1)
    log "tcpdump found: $TCPDUMP_VERSION"

    # Test if we can use it (may require root)
    if tcpdump -i any -c 1 &> /dev/null; then
        success "tcpdump is usable"
        NETWORK_TOOLS_AVAILABLE=true
    else
        warning "tcpdump requires elevated privileges"
    fi
else
    warning "tcpdump not found"
fi

if command -v tshark &> /dev/null; then
    TSHARK_VERSION=$(tshark --version 2>&1 | head -1)
    success "tshark found: $TSHARK_VERSION"
    NETWORK_TOOLS_AVAILABLE=true
else
    warning "tshark not found"
fi

if [ "$NETWORK_TOOLS_AVAILABLE" = false ]; then
    warning "Network packet capture not available - tests 68, 71-72 will use app-level logging"
fi

# Step 5: Create test data directory structure
section "Step 5: Test Data Directory Setup"
log "Creating test data directory structure at $TEST_DATA_DIR..."

mkdir -p "$TEST_DATA_DIR"/{json-files,images,medical/fhir,gdpr,rag/articles,research}
success "Test data directories created"

# Step 6: Generate test datasets
section "Step 6: Generating Test Datasets"
log "Generating comprehensive test datasets..."

python3 << 'PYEOF' 2>&1 | tee -a "$LOG_FILE"
import json
import random
import os
from datetime import datetime, timedelta

TEST_DATA_DIR = os.environ.get('TEST_DATA_DIR', '/tmp/test-data')

print(f"Generating test data in: {TEST_DATA_DIR}")

# 1. JSON Files (50 files: 45 valid, 5 invalid)
print("\n1. Generating JSON files...")
for i in range(50):
    size_kb = random.randint(100, 1000)
    is_valid = i < 45

    data = {
        "id": i,
        "timestamp": "2025-11-17T00:00:00Z",
        "records": [
            {"key": f"record_{j}", "value": random.randint(1, 1000)}
            for j in range(size_kb)
        ]
    }

    if not is_valid:
        data["records"] = "invalid_should_be_array"

    with open(f"{TEST_DATA_DIR}/json-files/data_{i:03d}.json", "w") as f:
        json.dump(data, f)

print(f"  ✓ Generated 50 JSON files")

# 2. Images (1000 files)
print("\n2. Generating image files...")
try:
    from PIL import Image
    for i in range(1000):
        width = random.randint(500, 2000)
        height = random.randint(500, 2000)
        img = Image.new('RGB', (width, height),
                        color=(random.randint(0, 255), random.randint(0, 255), random.randint(0, 255)))
        format_choice = ['JPEG', 'PNG', 'WEBP'][i % 3]
        ext = format_choice.lower() if format_choice != 'JPEG' else 'jpg'
        img.save(f"{TEST_DATA_DIR}/images/image_{i:04d}.{ext}", format=format_choice, quality=85)

        if (i + 1) % 100 == 0:
            print(f"  Generated {i + 1}/1000 images")
    print(f"  ✓ Generated 1000 valid images")
except ImportError:
    print("  ⚠ PIL not available, generating placeholder files...")
    for i in range(1000):
        format_choice = ['jpg', 'png', 'webp'][i % 3]
        size = random.randint(50000, 200000)
        data = bytes([random.randint(0, 255) for _ in range(size)])
        with open(f"{TEST_DATA_DIR}/images/image_{i:04d}.{format_choice}", "wb") as f:
            f.write(data)
        if (i + 1) % 100 == 0:
            print(f"  Generated {i + 1}/1000 placeholder images")
    print(f"  ✓ Generated 1000 placeholder image files")

# 3. FHIR Medical Data (100 patients)
print("\n3. Generating FHIR medical data...")
first_names = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda"]
last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia"]
states = ["NY", "CA", "IL", "TX", "AZ", "PA"]

for i in range(100):
    birth_date = datetime.now() - timedelta(days=random.randint(18*365, 90*365))
    patient = {
        "resourceType": "Patient",
        "id": f"patient-{i:03d}",
        "name": [{"given": [random.choice(first_names)], "family": random.choice(last_names)}],
        "gender": random.choice(["male", "female"]),
        "birthDate": birth_date.strftime("%Y-%m-%d"),
        "address": [{
            "city": random.choice(cities),
            "state": random.choice(states),
            "postalCode": f"{random.randint(10000, 99999)}"
        }]
    }
    with open(f"{TEST_DATA_DIR}/medical/fhir/patient_{i:03d}.json", "w") as f:
        json.dump(patient, f, indent=2)

print(f"  ✓ Generated 100 FHIR patients")

# 4. GDPR Users (1000 users)
print("\n4. Generating GDPR user data...")
try:
    from faker import Faker
    fake = Faker(['en_GB', 'fr_FR', 'de_DE', 'it_IT', 'es_ES'])

    users = []
    for i in range(1000):
        reg_date = datetime.now() - timedelta(days=random.randint(1, 730))
        last_login = datetime.now() - timedelta(days=random.randint(0, 30))

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
            "registration_date": reg_date.isoformat(),
            "last_login": last_login.isoformat(),
            "consent_given": datetime.now().isoformat()
        }
        users.append(user)

    print(f"  ✓ Generated using Faker library")
except ImportError:
    print("  ⚠ Faker not available, using simple generator...")
    users = []
    for i in range(1000):
        reg_date = datetime.now() - timedelta(days=random.randint(1, 730))
        last_login = datetime.now() - timedelta(days=random.randint(0, 30))

        user = {
            "id": i,
            "name": f"{random.choice(first_names)} {random.choice(last_names)}",
            "email": f"user{i}@example.com",
            "address": {
                "street": f"{random.randint(1, 999)} Main Street",
                "city": random.choice(cities),
                "postal_code": f"{random.randint(10000, 99999)}",
                "country": random.choice(['UK', 'France', 'Germany', 'Italy', 'Spain'])
            },
            "phone": f"+44-{random.randint(1000000000, 9999999999)}",
            "registration_date": reg_date.isoformat(),
            "last_login": last_login.isoformat(),
            "consent_given": datetime.now().isoformat()
        }
        users.append(user)

with open(f"{TEST_DATA_DIR}/gdpr/users.json", "w") as f:
    json.dump(users, f, indent=2)

print(f"  ✓ Generated 1000 GDPR users")

# 5. RAG Articles (100 articles)
print("\n5. Generating RAG articles...")
topics = {
    "climate": ["climate change", "global warming", "renewable energy", "carbon emissions"],
    "technology": ["artificial intelligence", "machine learning", "quantum computing", "blockchain"],
    "health": ["nutrition", "mental health", "vaccines", "public health"]
}

authors = ["Dr. John Smith", "Prof. Jane Doe", "Dr. Alice Johnson", "Prof. Bob Wilson"]
paragraphs = [
    "Recent research has shown significant developments in this field.",
    "The implications of these findings are far-reaching and important.",
    "Experts agree that this represents a major breakthrough.",
    "Further studies are needed to confirm these initial results.",
    "This work builds on previous research and extends our understanding."
]

article_id = 0
for category, keywords in topics.items():
    for i in range(33):
        if article_id >= 100:
            break
        keyword = keywords[i % len(keywords)]
        pub_date = datetime.now() - timedelta(days=random.randint(0, 365))

        article = {
            "@context": "https://schema.org",
            "@type": "Article",
            "headline": f"Recent developments in {keyword}: A comprehensive review",
            "author": {"@type": "Person", "name": random.choice(authors)},
            "datePublished": pub_date.strftime("%Y-%m-%d"),
            "articleBody": " ".join([paragraphs[j % len(paragraphs)] for j in range(5)]),
            "keywords": keyword,
            "category": category
        }

        with open(f"{TEST_DATA_DIR}/rag/articles/article_{article_id:03d}.json", "w") as f:
            json.dump(article, f, indent=2)

        article_id += 1
    if article_id >= 100:
        break

print(f"  ✓ Generated {article_id} RAG articles")

# 6. Research Papers (15 papers)
print("\n6. Generating research paper references...")
papers = [
    {"title": "Attention Is All You Need", "authors": ["Vaswani et al."], "year": 2017,
     "doi": "10.48550/arXiv.1706.03762", "url": "https://arxiv.org/abs/1706.03762"},
    {"title": "BERT: Pre-training of Deep Bidirectional Transformers", "authors": ["Devlin et al."],
     "year": 2018, "doi": "10.48550/arXiv.1810.04805", "url": "https://arxiv.org/abs/1810.04805"},
    {"title": "GPT-3: Language Models are Few-Shot Learners", "authors": ["Brown et al."],
     "year": 2020, "doi": "10.48550/arXiv.2005.14165", "url": "https://arxiv.org/abs/2005.14165"},
    {"title": "Constitutional AI: Harmlessness from AI Feedback", "authors": ["Bai et al."],
     "year": 2022, "doi": "10.48550/arXiv.2212.08073", "url": "https://arxiv.org/abs/2212.08073"}
]

for i in range(11):
    papers.append({
        "title": f"Advances in Machine Learning: Case Study {i+5}",
        "authors": [f"Author {chr(65+i)} et al."],
        "year": 2023 + (i % 2),
        "doi": f"10.1234/example.{i+5:04d}",
        "url": f"https://example.com/paper{i+5}"
    })

with open(f"{TEST_DATA_DIR}/research/papers.json", "w") as f:
    json.dump(papers, f, indent=2)

print(f"  ✓ Generated 15 research papers")

# Validation
print("\n7. Validating generated data...")
validation_results = {
    "json_files": len(os.listdir(f"{TEST_DATA_DIR}/json-files")),
    "images": len(os.listdir(f"{TEST_DATA_DIR}/images")),
    "fhir_patients": len(os.listdir(f"{TEST_DATA_DIR}/medical/fhir")),
    "gdpr_users": len(json.load(open(f"{TEST_DATA_DIR}/gdpr/users.json"))),
    "rag_articles": len(os.listdir(f"{TEST_DATA_DIR}/rag/articles")),
    "research_papers": len(json.load(open(f"{TEST_DATA_DIR}/research/papers.json")))
}

print("\nValidation Results:")
for key, count in validation_results.items():
    print(f"  {key}: {count}")

# Validate JSON files
valid_count = 0
invalid_count = 0
for i in range(50):
    try:
        with open(f"{TEST_DATA_DIR}/json-files/data_{i:03d}.json") as f:
            data = json.load(f)
            if isinstance(data.get("records"), list):
                valid_count += 1
            else:
                invalid_count += 1
    except:
        invalid_count += 1

print(f"\nJSON Files Quality Check:")
print(f"  Valid: {valid_count}")
print(f"  Invalid: {invalid_count}")

print(f"\n✓ Test data generation complete!")
PYEOF

# Step 7: Generate environment summary
section "Step 7: Environment Summary"
log "Generating environment capabilities summary..."

cat > "${SCRIPT_DIR}/environment_capabilities.txt" << EOF
Claude Code Testing Environment - Capabilities Summary
Generated: $(date)

CONTAINER RUNTIME
-----------------
Available: ${CONTAINER_AVAILABLE}
$(if [ "$CONTAINER_AVAILABLE" = true ]; then echo "Runtime: $CONTAINER_RUNTIME"; fi)
Impact: $(if [ "$CONTAINER_AVAILABLE" = false ]; then echo "Tests 16-20, 36-40, 71-72, 76 must be skipped"; else echo "All container tests available"; fi)

NETWORK MONITORING
------------------
Available: ${NETWORK_TOOLS_AVAILABLE}
Impact: $(if [ "$NETWORK_TOOLS_AVAILABLE" = false ]; then echo "Tests 68, 71-72 will use app-level logging"; else echo "Packet capture available"; fi)

PYTHON PACKAGES
---------------
(See log file for detailed package status)

TEST DATA
---------
Location: $TEST_DATA_DIR
Generated: $(date)
Datasets: JSON (50), Images (1000), FHIR (100), GDPR (1000), RAG (99), Research (15)

RECOMMENDATIONS
---------------
$(if [ "$CONTAINER_AVAILABLE" = false ]; then echo "- Install Podman or start Docker daemon to enable container tests"; fi)
$(if [ "$NETWORK_TOOLS_AVAILABLE" = false ]; then echo "- Install tshark or configure tcpdump for network monitoring tests"; fi)
- Review $LOG_FILE for detailed setup information
- Test data is ready in $TEST_DATA_DIR
- See CLAUDE.md for project documentation
EOF

cat "${SCRIPT_DIR}/environment_capabilities.txt" | tee -a "$LOG_FILE"

# Final summary
section "Setup Complete!"
success "Environment setup completed successfully"
log "Review the following files:"
log "  - Setup log: $LOG_FILE"
log "  - Capabilities: ${SCRIPT_DIR}/environment_capabilities.txt"
log "  - Project docs: ${SCRIPT_DIR}/CLAUDE.md"
log "  - Test data: $TEST_DATA_DIR"
echo ""
log "Next steps:"
log "  1. Review setup_report.md for setup test results"
log "  2. Check environment_capabilities.txt for available features"
log "  3. Run the test suite when ready"
echo ""

exit 0
