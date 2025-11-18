#!/bin/bash
# Claude Code SessionStart Hook
# Auto-validates environment on every new session

echo '=== Claude Code Session Started ==='
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ''

echo 'Environment Check:'
python3 --version
node --version
git --version
echo ''

echo 'Test data directory:'
ls -la /tmp/test-data 2>/dev/null | head -5 || echo 'Test data not found - run setup_environment.sh'
echo ''

echo 'Quick capability check:'
command -v podman &>/dev/null && echo '✓ Podman available' || echo '✗ Podman not available'
command -v docker &>/dev/null && docker ps &>/dev/null 2>&1 && echo '✓ Docker available' || echo '✗ Docker not available'

python3 -c 'try:
    from PIL import Image
    print("✓ Pillow available")
except:
    print("✗ Pillow not available")'

python3 -c 'try:
    from faker import Faker
    print("✓ Faker available")
except:
    print("✗ Faker not available")'

echo ''
echo 'See CLAUDE.md for setup instructions and test suite documentation'
echo '=============================='
