#!/bin/bash

################################################################################
# AUTHORIZED DARK WEB SERVICE SCANNER - SIMPLE INSTALLER
################################################################################
# Copy and paste this entire script to install
# Usage: bash simple_install.sh
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
PROJECT_FOLDER="darknet-authorized-scanner"
PROJECT_DIR="./${PROJECT_FOLDER}"

# Helper functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
cmd_exists() { command -v "$1" >/dev/null 2>&1; }

# Main installation
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Authorized Dark Web Service Scanner - Installer       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check Python
    print_info "Checking Python 3..."
    if ! cmd_exists python3; then
        print_error "Python 3 not found. Install Python 3.7+ and try again."
    fi
    print_success "Python 3 found"
    
    # Create project directory
    print_info "Creating project directory..."
    mkdir -p "${PROJECT_DIR}/{logs,results}"
    print_success "Directory created: ${PROJECT_DIR}"
    
    # Create scanner.py
    print_info "Creating scanner.py..."
    create_scanner
    print_success "scanner.py created"
    
    # Create settings.txt
    print_info "Creating settings.txt..."
    create_settings
    print_success "settings.txt created"
    
    # Create urls.txt
    print_info "Creating urls.txt..."
    create_urls
    print_success "urls.txt created"
    
    # Create run_scan.sh
    print_info "Creating run_scan.sh..."
    create_run_script
    print_success "run_scan.sh created"
    
    # Make scripts executable
    chmod +x "${PROJECT_DIR}/scanner.py"
    chmod +x "${PROJECT_DIR}/run_scan.sh"
    
    # Print success message
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Quick start:"
    echo "  1. cd ${PROJECT_FOLDER}"
    echo "  2. Edit urls.txt with your targets"
    echo "  3. python3 scanner.py -f urls.txt -p common"
    echo ""
    print_info "Project location: ${PROJECT_DIR}"
}

# Create scanner.py
create_scanner() {
    cat > "${PROJECT_DIR}/scanner.py" << 'SCANNER_EOF'
#!/usr/bin/env python3
"""Authorized Dark Web Service Scanner - Multi-threaded port scanner"""

import socket, threading, json, os, sys, time, logging, argparse
from datetime import datetime
from queue import Queue, Empty
from urllib.parse import urlparse
from pathlib import Path
import xml.etree.ElementTree as ET

# ====== CONFIGURATION ======
class Config:
    def __init__(self, file='settings.txt'):
        self.data = {
            'MAX_THREADS': 20, 'SOCKET_TIMEOUT': 5, 'BANNER_SIZE': 1024,
            'COMMON_PORTS': '21,22,23,25,53,80,443,465,587,993,995,3128,3306,5432,8000,8080,8888,9050,9051,9100,9200,27017,6379',
            'RETRY_COUNT': 3, 'RETRY_DELAY': 1, 'LOG_LEVEL': 'INFO',
            'LOG_FILE': 'logs/scanner.log', 'OUTPUT_DIR': 'results',
            'SITEMAP_ENABLED': True, 'BANNER_GRAB': True, 'VERSION_DETECTION': True,
            'SERVICE_FINGERPRINT': True, 'THREAD_TIMEOUT': 30, 'SLOW_MODE': False,
            'DELAY_BETWEEN_SCANS': 0.1
        }
        # Load from file if exists
        if os.path.exists(file):
            with open(file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        k, v = k.strip().upper(), v.strip()
                        if v.lower() in ('true', 'false'): self.data[k] = v.lower() == 'true'
                        elif v.isdigit(): self.data[k] = int(v)
                        else: self.data[k] = v
    def get(self, key, default=None): return self.data.get(key, default)

# ====== LOGGING ======
def setup_logging(config):
    Path(config.get('LOG_FILE')).parent.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=getattr(logging, config.get('LOG_LEVEL', 'INFO')),
        format='%(asctime)s [%(levelname)s] %(message)s',
        handlers=[logging.FileHandler(config.get('LOG_FILE')), logging.StreamHandler(sys.stdout)]
    )
    return logging.getLogger(__name__)

# ====== SERVICE IDENTIFICATION ======
class ServiceID:
    KNOWN = {
        21: ('FTP', b'220'), 22: ('SSH', b'SSH'), 80: ('HTTP', b'HTTP'),
        443: ('HTTPS', b'HTTP'), 3306: ('MySQL', b'5.'), 5432: ('PostgreSQL', b'FATAL'),
        8080: ('HTTP-Proxy', b'HTTP'), 9050: ('Tor SOCKS', b'Tor'),
        27017: ('MongoDB', b'MongoDB'), 6379: ('Redis', b'REDIS')
    }
    
    @staticmethod
    def identify(port, banner):
        info = ServiceID.KNOWN.get(port, ('Unknown', None))
        if banner:
            try:
                b_str = banner.decode('utf-8', errors='ignore').lower()
                if 'ssh' in b_str: return ('SSH', 'Detected')
                elif 'http' in b_str: return ('HTTP/HTTPS', 'Detected')
                elif 'ftp' in b_str: return ('FTP', 'Detected')
                elif 'mongodb' in b_str: return ('MongoDB', 'Detected')
                elif 'redis' in b_str: return ('Redis', 'Detected')
            except: pass
        return (info[0], 'Unknown')

# ====== PORT SCANNER ======
class Scanner:
    def __init__(self, config, logger):
        self.config, self.logger = config, logger
        self.results, self.queue, self.lock = [], Queue(), threading.Lock()
    
    def scan_port(self, host, port):
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(self.config.get('SOCKET_TIMEOUT'))
            result = sock.connect_ex((host, port))
            banner = None
            if result == 0:
                if self.config.get('BANNER_GRAB'):
                    try: banner = sock.recv(self.config.get('BANNER_SIZE'))
                    except: banner = b'[No banner]'
                svc, ver = ServiceID.identify(port, banner)
                res = {'host': host, 'port': port, 'status': 'OPEN', 'service': svc,
                       'version': ver, 'banner': banner.decode('utf-8', errors='ignore') if banner else '',
                       'timestamp': datetime.now().isoformat()}
                with self.lock:
                    self.results.append(res)
                    self.logger.info(f"[OPEN] {host}:{port} - {svc} {ver}")
            sock.close()
        except socket.timeout: self.logger.debug(f"[TIMEOUT] {host}:{port}")
        except Exception as e: self.logger.debug(f"[ERROR] {host}:{port} - {e}")
    
    