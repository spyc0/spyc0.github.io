#!/bin/bash

################################################################################
# AUTHORIZED DARK WEB SERVICE SCANNER - AUTOMATED INSTALLER
################################################################################
# This script automates the complete installation of the scanner project
# It detects the OS, installs dependencies, creates directory structure,
# and validates the installation
#
# Usage: bash install.sh
# Or: chmod +x install.sh && ./install.sh
#
# Supports: Linux (Ubuntu, Debian, CentOS, Fedora), macOS, Raspberry Pi
################################################################################

# ============================================================================
# CONFIGURATION VARIABLES
# ============================================================================

# Set strict error handling - exit on any error, undefined variables, pipe errors
set -euo pipefail

# Define colors for output formatting
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_NC='\033[0m' # No Color

# Project information
readonly PROJECT_NAME="Authorized Dark Web Service Scanner"
readonly PROJECT_FOLDER="darknet-authorized-scanner"
readonly PYTHON_VERSION_REQUIRED="3.7"

# Installation paths
INSTALL_DIR="${INSTALL_DIR:-.}"
PROJECT_DIR="${INSTALL_DIR}/${PROJECT_FOLDER}"

# Script flags
SKIP_DEPENDENCIES=false
SKIP_TOR=false
SKIP_I2PD=false
VERBOSE=false
IS_RASPBERRY_PI=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print colored output
# Args: $1 = color code, $2 = message
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${COLOR_NC}"
}

# Print info message
print_info() {
    print_color "${COLOR_BLUE}" "[INFO] $1"
}

# Print success message
print_success() {
    print_color "${COLOR_GREEN}" "[SUCCESS] $1"
}

# Print warning message
print_warning() {
    print_color "${COLOR_YELLOW}" "[WARNING] $1"
}

# Print error message and exit
# Args: $1 = error message, $2 = exit code (optional, default 1)
print_error() {
    local message="$1"
    local exit_code="${2:-1}"
    print_color "${COLOR_RED}" "[ERROR] ${message}"
    exit "${exit_code}"
}

# Check if command exists
# Args: $1 = command name
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Run command with error handling
# Args: $1 = command description, $2 = command to run
run_command() {
    local description="$1"
    local command="$2"
    
    print_info "Running: ${description}"
    
    if eval "${command}"; then
        print_success "${description} completed"
        return 0
    else
        print_error "${description} failed with exit code $?"
    fi
}

# ============================================================================
# SYSTEM DETECTION
# ============================================================================

# Detect operating system
# Returns: linux, macos, or unknown
detect_os() {
    case "$(uname -s)" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect Linux distribution
# Returns: ubuntu, debian, fedora, centos, raspbian, or unknown
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        # Source the file to get variables like ID
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

# Check if running on Raspberry Pi
# Returns: true if Raspberry Pi, false otherwise
is_raspberry_pi() {
    if [ -f /proc/device-tree/model ] 2>/dev/null; then
        if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Detect system architecture
# Returns: armv7l, aarch64, x86_64, or unknown
detect_architecture() {
    uname -m
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

# Install Python 3 and required tools
install_python() {
    print_info "Installing Python 3..."
    
    local os="$1"
    local distro="$2"
    
    if command_exists python3; then
        local py_version
        py_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        print_success "Python 3 already installed (version ${py_version})"
        return 0
    fi
    
    case "${os}" in
        linux)
            case "${distro}" in
                ubuntu|debian)
                    # Update package manager and install Python 3
                    print_info "Updating package manager..."
                    sudo apt-get update >/dev/null 2>&1 || print_warning "apt-get update failed, continuing anyway"
                    
                    print_info "Installing Python 3 and pip..."
                    sudo apt-get install -y python3 python3-pip python3-venv >/dev/null 2>&1
                    ;;
                fedora|rhel|centos)
                    # Install Python 3 on Red Hat based systems
                    print_info "Installing Python 3 and pip..."
                    sudo dnf install -y python3 python3-pip >/dev/null 2>&1 || \
                        sudo yum install -y python3 python3-pip >/dev/null 2>&1
                    ;;
                raspbian)
                    # Raspberry Pi specific installation
                    print_info "Updating package manager (Raspberry Pi)..."
                    sudo apt-get update >/dev/null 2>&1
                    
                    print_info "Installing Python 3 (Raspberry Pi)..."
                    sudo apt-get install -y python3 python3-pip python3-venv >/dev/null 2>&1
                    ;;
                *)
                    print_error "Unsupported Linux distribution: ${distro}"
                    ;;
            esac
            ;;
        macos)
            # macOS installation using brew
            if ! command_exists brew; then
                print_error "Homebrew not found. Install from https://brew.sh/"
            fi
            
            print_info "Installing Python 3 via Homebrew..."
            brew install python3 >/dev/null 2>&1
            ;;
        *)
            print_error "Unsupported operating system"
            ;;
    esac
    
    # Verify Python installation
    if command_exists python3; then
        local py_version
        py_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        print_success "Python 3 installed (version ${py_version})"
    else
        print_error "Python 3 installation failed"
    fi
}

# Install Tor (optional, for .onion scanning)
install_tor() {
    print_info "Installing Tor..."
    
    local os="$1"
    local distro="$2"
    
    if command_exists tor; then
        local tor_version
        tor_version=$(tor --version | head -n1)
        print_success "Tor already installed (${tor_version})"
        return 0
    fi
    
    case "${os}" in
        linux)
            case "${distro}" in
                ubuntu|debian)
                    print_info "Installing Tor via apt..."
                    sudo apt-get install -y tor >/dev/null 2>&1
                    sudo systemctl start tor 2>/dev/null || true
                    sudo systemctl enable tor 2>/dev/null || true
                    ;;
                fedora|rhel|centos)
                    print_info "Installing Tor via dnf/yum..."
                    sudo dnf install -y tor >/dev/null 2>&1 || \
                        sudo yum install -y tor >/dev/null 2>&1
                    sudo systemctl start tor 2>/dev/null || true
                    sudo systemctl enable tor 2>/dev/null || true
                    ;;
                raspbian)
                    print_info "Installing Tor on Raspberry Pi..."
                    sudo apt-get install -y tor >/dev/null 2>&1
                    ;;
                *)
                    print_warning "Cannot automatically install Tor on ${distro}, install manually"
                    ;;
            esac
            ;;
        macos)
            print_info "Installing Tor via Homebrew..."
            brew install tor >/dev/null 2>&1
            brew services start tor 2>/dev/null || true
            ;;
        *)
            print_warning "Cannot automatically install Tor on this OS"
            ;;
    esac
    
    # Verify Tor installation
    if command_exists tor; then
        print_success "Tor installed and started"
    else
        print_warning "Tor installation skipped or failed (optional dependency)"
    fi
}

# Install i2pd (optional, for .i2p scanning)
install_i2pd() {
    print_info "Installing i2pd..."
    
    local os="$1"
    local distro="$2"
    
    if command_exists i2pd; then
        local i2pd_version
        i2pd_version=$(i2pd --version | head -n1)
        print_success "i2pd already installed (${i2pd_version})"
        return 0
    fi
    
    case "${os}" in
        linux)
            case "${distro}" in
                ubuntu|debian)
                    print_info "Installing i2pd via apt..."
                    sudo apt-get install -y i2pd >/dev/null 2>&1
                    sudo systemctl start i2pd 2>/dev/null || true
                    sudo systemctl enable i2pd 2>/dev/null || true
                    ;;
                fedora|rhel|centos)
                    print_info "Installing i2pd via dnf/yum..."
                    sudo dnf install -y i2pd >/dev/null 2>&1 || \
                        sudo yum install -y i2pd >/dev/null 2>&1
                    sudo systemctl start i2pd 2>/dev/null || true
                    sudo systemctl enable i2pd 2>/dev/null || true
                    ;;
                raspbian)
                    print_info "Installing i2pd on Raspberry Pi..."
                    sudo apt-get install -y i2pd >/dev/null 2>&1
                    ;;
                *)
                    print_warning "Cannot automatically install i2pd on ${distro}, install manually"
                    ;;
            esac
            ;;
        macos)
            print_info "Installing i2pd via Homebrew..."
            brew install i2pd >/dev/null 2>&1
            brew services start i2pd 2>/dev/null || true
            ;;
        *)
            print_warning "Cannot automatically install i2pd on this OS"
            ;;
    esac
    
    # Verify i2pd installation
    if command_exists i2pd; then
        print_success "i2pd installed and started"
    else
        print_warning "i2pd installation skipped or failed (optional dependency)"
    fi
}

# ============================================================================
# PROJECT SETUP
# ============================================================================

# Create project directory structure
create_directories() {
    print_info "Creating project directory structure..."
    
    # Create main directories
    mkdir -p "${PROJECT_DIR}/{logs,results}"
    
    # Create results subdirectories for organization
    mkdir -p "${PROJECT_DIR}/results/scans"
    mkdir -p "${PROJECT_DIR}/results/reports"
    
    print_success "Directories created in ${PROJECT_DIR}"
}

# Create project files
create_project_files() {
    print_info "Creating project files..."
    
    # Create scanner.py
    create_scanner_py
    
    # Create settings.txt
    create_settings_txt
    
    # Create urls.txt
    create_urls_txt
    
    # Create requirements.txt
    create_requirements_txt
    
    # Create run_scan.sh
    create_run_scan_sh
    
    # Create index.html
    create_index_html
    
    print_success "All project files created"
}

# Create scanner.py with all functionality
create_scanner_py() {
    print_info "Creating scanner.py..."
    cat > "${PROJECT_DIR}/scanner.py" << 'EOF'
#!/usr/bin/env python3
"""
Authorized Dark Web Service Scanner
=====================================
Multi-threaded port scanner, banner grabber, and service identifier
for authorized penetration testing of owned dark web services.

LEGAL: Only use on services you own or have explicit authorization to test.
"""

import socket
import threading
import json
import os
import sys
import time
import logging
import argparse
from datetime import datetime
from queue import Queue, Empty
from urllib.parse import urlparse
from pathlib import Path
import xml.etree.ElementTree as ET

# ============================================================================
# CONFIGURATION CLASS
# ============================================================================

class ScannerConfig:
    """Centralized configuration management - loads from settings.txt"""
    
    def __init__(self, config_file='settings.txt'):
        """Initialize configuration from file"""
        self.config_file = config_file
        self.settings = self._load_config()
    
    def _load_config(self):
        """Load settings from settings.txt file"""
        # Default configuration values
        defaults = {
            'MAX_THREADS': 20,
            'SOCKET_TIMEOUT': 5,
            'BANNER_SIZE': 1024,
            'PORT_RANGE': '1-65535',
            'COMMON_PORTS': '21,22,23,25,53,80,443,465,587,993,995,3128,3306,5432,8000,8080,8888,9050,9051,9100,9200,27017,6379',
            'RETRY_COUNT': 3,
            'RETRY_DELAY': 1,
            'LOG_LEVEL': 'INFO',
            'LOG_FILE': 'logs/scanner.log',
            'OUTPUT_DIR': 'results',
            'SITEMAP_ENABLED': True,
            'BANNER_GRAB': True,
            'VERSION_DETECTION': True,
            'SERVICE_FINGERPRINT': True,
            'THREAD_TIMEOUT': 30,
            'SLOW_MODE': False,
            'DELAY_BETWEEN_SCANS': 0.1,
        }
        
        # Try to load from config file
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    for line in f:
                        # Strip whitespace
                        line = line.strip()
                        # Skip empty lines and comments
                        if line and not line.startswith('#'):
                            # Parse key=value format
                            if '=' in line:
                                key, value = line.split('=', 1)
                                key = key.strip().upper()
                                value = value.strip()
                                
                                # Convert value types
                                if value.lower() in ('true', 'false'):
                                    defaults[key] = value.lower() == 'true'
                                elif value.isdigit():
                                    defaults[key] = int(value)
                                else:
                                    defaults[key] = value
            except Exception as e:
                logging.warning(f"Failed to load config: {e}. Using defaults.")
        
        return defaults
    
    def get(self, key, default=None):
        """Get configuration value"""
        return self.settings.get(key, default)

# ============================================================================
# LOGGING MANAGER
# ============================================================================

class LogManager:
    """Centralized logging management"""
    
    @staticmethod
    def setup_logging(config):
        """Setup logging to file and stdout"""
        log_dir = Path(config.get('LOG_FILE')).parent
        log_dir.mkdir(parents=True, exist_ok=True)
        
        logging.basicConfig(
            level=getattr(logging, config.get('LOG_LEVEL', 'INFO')),
            format='%(asctime)s [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler(config.get('LOG_FILE')),
                logging.StreamHandler(sys.stdout)
            ]
        )
        return logging.getLogger(__name__)

# ============================================================================
# SERVICE IDENTIFICATION
# ============================================================================

class ServiceIdentifier:
    """Identify services from banners and port numbers"""
    
    # Known services and their typical banners
    KNOWN_SERVICES = {
        21: {'name': 'FTP', 'banner': b'220'},
        22: {'name': 'SSH', 'banner': b'SSH'},
        23: {'name': 'Telnet', 'banner': b'Login'},
        25: {'name': 'SMTP', 'banner': b'220'},
        53: {'name': 'DNS', 'banner': None},
        80: {'name': 'HTTP', 'banner': b'HTTP'},
        443: {'name': 'HTTPS', 'banner': b'HTTP'},
        3128: {'name': 'Squid Proxy', 'banner': b'3128'},
        3306: {'name': 'MySQL', 'banner': b'5.'},
        5432: {'name': 'PostgreSQL', 'banner': b'FATAL'},
        8000: {'name': 'HTTP-Alt', 'banner': b'HTTP'},
        8080: {'name': 'HTTP-Proxy', 'banner': b'HTTP'},
        8888: {'name': 'HTTP-Alt', 'banner': b'HTTP'},
        9050: {'name': 'Tor SOCKS', 'banner': b'Tor'},
        9051: {'name': 'Tor Control', 'banner': b'250'},
        9100: {'name': 'Jetdirect', 'banner': b''},
        9200: {'name': 'Elasticsearch', 'banner': b'cluster'},
        27017: {'name': 'MongoDB', 'banner': b'MongoDB'},
        6379: {'name': 'Redis', 'banner': b'REDIS'},
    }
    
    @staticmethod
    def identify_service(port, banner):
        """Identify service from port number and banner"""
        service_info = ServiceIdentifier.KNOWN_SERVICES.get(port, {})
        
        if banner:
            try:
                banner_str = banner.decode('utf-8', errors='ignore').lower()
                
                # Detect SSH
                if 'ssh' in banner_str:
                    version = banner_str.split('_')[1] if '_' in banner_str else 'Unknown'
                    return 'SSH', version
                # Detect HTTP/HTTPS
                elif 'http' in banner_str or '200 ok' in banner_str:
                    return 'HTTP/HTTPS', 'Detected'
                # Detect FTP
                elif 'ftp' in banner_str or '220' in banner_str:
                    return 'FTP', 'Detected'
                # Detect MongoDB
                elif 'mongodb' in banner_str:
                    return 'MongoDB', banner_str.split()[0] if banner_str else 'Unknown'
                # Detect Redis
                elif 'redis' in banner_str:
                    return 'Redis', 'Detected'
                # Detect Elasticsearch
                elif 'elasticsearch' in banner_str:
                    return 'Elasticsearch', 'Detected'
            except Exception:
                pass
        
        # Return generic service name from port
        return service_info.get('name', 'Unknown'), 'Unknown'

# ============================================================================
# PORT SCANNER ENGINE
# ============================================================================

class PortScanner:
    """Multi-threaded port scanner with banner grabbing"""
    
    def __init__(self, config, logger):
        """Initialize scanner with config and logger"""
        self.config = config
        self.logger = logger
        self.results = []
        self.queue = Queue()
        self.lock = threading.Lock()
    
    def scan_port(self, host, port):
        """Scan a single port and grab banner if available"""
        try:
            # Create socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(self.config.get('SOCKET_TIMEOUT'))
            
            # Try to connect to port
            result = sock.connect_ex((host, port))
            banner = None
            
            # If connection successful (port open)
            if result == 0:
                # Try to grab banner if enabled
                if self.config.get('BANNER_GRAB'):
                    try:
                        banner = sock.recv(self.config.get('BANNER_SIZE'))
                    except socket.timeout:
                        banner = b'[No banner - timeout]'
                    except Exception:
                        banner = b'[Banner grab failed]'
                
                # Identify service
                service_name, version = ServiceIdentifier.identify_service(port, banner)
                
                # Create result record
                scan_result = {
                    'host': host,
                    'port': port,
                    'status': 'OPEN',
                    'service': service_name,
                    'version': version,
                    'banner': banner.decode('utf-8', errors='ignore') if banner else '',
                    'timestamp': datetime.now().isoformat()
                }
                
                # Thread-safe result storage
                with self.lock:
                    self.results.append(scan_result)
                    self.logger.info(f"[OPEN] {host}:{port} - {service_name} {version}")
            
            sock.close()
        
        except socket.timeout:
            self.logger.debug(f"[TIMEOUT] {host}:{port}")
        except Exception as e:
            self.logger.debug(f"[ERROR] {host}:{port} - {str(e)}")
    
    def worker(self):
        """Worker thread - processes ports from queue"""
        while True:
            try:
                # Get port from queue with timeout
                host, port = self.queue.get(timeout=1)
                
                # Retry logic
                for attempt in range(self.config.get('RETRY_COUNT')):
                    self.scan_port(host, port)
                    if attempt < self.config.get('RETRY_COUNT') - 1:
                        time.sleep(self.config.get('RETRY_DELAY'))
                
                # Delay for slow systems (Raspberry Pi)
                if self.config.get('SLOW_MODE'):
                    time.sleep(self.config.get('DELAY_BETWEEN_SCANS'))
                
                self.queue.task_done()
            
            except Empty:
                break
            except Exception as e:
                self.logger.error(f"Worker thread error: {e}")
    
    def scan_ports(self, host, ports):
        """Scan multiple ports using thread pool"""
        self.logger.info(f"Starting scan on {host} - Ports: {len(ports)}")
        self.results = []
        
        # Queue all ports
        for port in ports:
            self.queue.put((host, port))
        
        # Create and start worker threads
        threads = []
        num_threads = self.config.get('MAX_THREADS')
        
        for _ in range(num_threads):
            t = threading.Thread(target=self.worker, daemon=True)
            t.start()
            threads.append(t)
        
        # Wait for queue to empty and threads to complete
        self.queue.join()
        for t in threads:
            t.join(timeout=self.config.get('THREAD_TIMEOUT'))
        
        self.logger.info(f"Scan complete. Found {len(self.results)} open ports")
        return self.results

# ============================================================================
# RESULTS MANAGEMENT
# ============================================================================

class ResultsManager:
    """Manage and export scan results in multiple formats"""
    
    def __init__(self, config, logger):
        """Initialize results manager"""
        self.config = config
        self.logger = logger
        self.output_dir = Path(config.get('OUTPUT_DIR'))
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def save_results(self, host, results):
        """Save results in JSON, HTML, and XML formats"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        safe_host = host.replace(':', '_').replace('/', '_')
        
        # Save JSON results
        json_file = self.output_dir / f"{safe_host}_{timestamp}.json"
        with open(json_file, 'w') as f:
            json.dump(results, f, indent=2)
        self.logger.info(f"Results saved: {json_file}")
        
        # Generate HTML report
        self.generate_html_report(safe_host, results, timestamp)
        
        # Generate XML sitemap
        if self.config.get('SITEMAP_ENABLED'):
            self.generate_sitemap(safe_host, results, timestamp)
    
    def generate_html_report(self, host, results, timestamp):
        """Generate formatted HTML report"""
        html_file = self.output_dir / f"{host}_{timestamp}.html"
        
        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>Scan Report - {host}</title>
    <style>
        body {{ font-family: Arial; margin: 20px; background: #f5f5f5; }}
        .header {{ background: #333; color: white; padding: 20px; border-radius: 5px; }}
        .container {{ max-width: 1200px; margin: 20px auto; }}
        table {{ width: 100%; border-collapse: collapse; background: white; }}
        th {{ background: #4CAF50; color: white; padding: 12px; text-align: left; }}
        td {{ padding: 10px; border-bottom: 1px solid #ddd; }}
        tr:hover {{ background: #f5f5f5; }}
        .open {{ color: #d32f2f; font-weight: bold; }}
        .timestamp {{ color: #999; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Authorized Scan Report</h1>
            <p>Host: {host}</p>
            <p class="timestamp">Generated: {timestamp}</p>
        </div>
        <table>
            <thead>
                <tr>
                    <th>Port</th>
                    <th>Service</th>
                    <th>Version</th>
                    <th>Status</th>
                    <th>Banner</th>
                </tr>
            </thead>
            <tbody>
"""
        
        for result in sorted(results, key=lambda x: x['port']):
            html_content += f"""                <tr>
                    <td>{result['port']}</td>
                    <td>{result['service']}</td>
                    <td>{result['version']}</td>
                    <td class="open">{result['status']}</td>
                    <td><code>{result['banner'][:100]}</code></td>
                </tr>
"""
        
        html_content += """            </tbody>
        </table>
    </div>
</body>
</html>
"""
        
        with open(html_file, 'w') as f:
            f.write(html_content)
        self.logger.info(f"HTML report saved: {html_file}")
    
    def generate_sitemap(self, host, results, timestamp):
        """Generate XML sitemap of discovered services"""
        sitemap_file = self.output_dir / f"{host}_{timestamp}_sitemap.xml"
        
        root = ET.Element('urlset')
        root.set('xmlns', 'http://www.sitemaps.org/schemas/sitemap/0.9')
        
        for result in results:
            url_elem = ET.SubElement(root, 'url')
            loc = ET.SubElement(url_elem, 'loc')
            loc.text = f"http://{host}:{result['port']}/{result['service']}"
            lastmod = ET.SubElement(url_elem, 'lastmod')
            lastmod.text = result['timestamp']
        
        tree = ET.ElementTree(root)
        tree.write(sitemap_file)
        self.logger.info(f"Sitemap saved: {sitemap_file}")

# ============================================================================
# URL MANAGEMENT
# ============================================================================

class URLManager:
    """Load and manage target URLs"""
    
    @staticmethod
    def load_urls(filename='urls.txt'):
        """Load URLs from file"""
        urls = []
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        urls.append(line)
        return urls
    
    @staticmethod
    def parse_target(target):
        """Parse target (URL or IP:Port)"""
        try:
            if '://' in target:
                parsed = urlparse(target)
                host = parsed.hostname
                port = parsed.port or (443 if parsed.scheme == 'https' else 80)
            else:
                if ':' in target:
                    host, port = target.rsplit(':', 1)
                    port = int(port)
                else:
                    host = target
                    port = 80
            return host, port
        except Exception:
            return None, None

# ============================================================================
# MAIN SCANNER CLASS
# ============================================================================

class DarknetScanner:
    """Main scanner orchestrator"""
    
    def __init__(self, config_file='settings.txt'):
        """Initialize scanner"""
        self.config = ScannerConfig(config_file)
        self.logger = LogManager.setup_logging(self.config)
        self.scanner = PortScanner(self.config, self.logger)
        self.results_mgr = ResultsManager(self.config, self.logger)
    
    def parse_ports(self, port_spec):
        """Parse port specification (common, range, or list)"""
        ports = []
        
        if port_spec == 'common':
            ports = [int(p) for p in self.config.get('COMMON_PORTS').split(',')]
        elif '-' in port_spec:
            start, end = port_spec.split('-')
            ports = list(range(int(start), int(end) + 1))
        else:
            ports = [int(p) for p in port_spec.split(',')]
        
        return ports
    
    def scan_target(self, target, ports):
        """Scan a single target"""
        host, default_port = URLManager.parse_target(target)
        
        if not host:
            self.logger.error(f"Invalid target: {target}")
            return
        
        # Determine ports to scan
        if default_port and ports == 'common':
            ports_to_scan = [default_port]
        else:
            ports_to_scan = self.parse_ports(ports)
        
        results = self.scanner.scan_ports(host, ports_to_scan)
        self.results_mgr.save_results(host, results)
    
    def scan_urls_file(self, filename='urls.txt', ports='common'):
        """Scan all URLs from file"""
        urls = URLManager.load_urls(filename)
        
        if not urls:
            self.logger.error(f"No URLs found in {filename}")
            return
        
        self.logger.info(f"Found {len(urls)} targets to scan")
        
        for url in urls:
            self.scan_target(url, ports)

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Authorized Dark Web Service Scanner',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Scan single .onion address
  python3 scanner.py -t example.onion -p common
  
  # Scan all URLs in urls.txt
  python3 scanner.py -f urls.txt -p common
  
  # Scan specific port range
  python3 scanner.py -t 192.168.1.1 -p 1-10000
  
  # Scan multiple specific ports
  python3 scanner.py -t example.i2p -p 80,443,8080
        """
    )
    
    parser.add_argument('-t', '--target', help='Single target (IP, domain, or .onion)')
    parser.add_argument('-f', '--file', default='urls.txt', help='URLs file (default: urls.txt)')
    parser.add_argument('-p', '--ports', default='common', 
                       help='Ports: common, range (1-65535), or list (80,443,8080)')
    parser.add_argument('-c', '--config', default='settings.txt', help='Config file')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    scanner = DarknetScanner(args.config)
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    if args.target:
        scanner.scan_target(args.target, args.ports)
    else:
        scanner.scan_urls_file(args.file, args.ports)

if __name__ == '__main__':
    main()
EOF
    
    chmod +x "${PROJECT_DIR}/scanner.py"
    print_success "scanner.py created and made executable"
}

# Create settings.txt configuration file
create_settings_txt() {
    print_info "Creating settings.txt..."
    cat > "${PROJECT_DIR}/settings.txt" << 'EOF'
# ============================================================================
# AUTHORIZED DARK WEB SERVICE SCANNER - CONFIGURATION
# ============================================================================
# LEGAL NOTICE: Only scan services you own or have explicit authorization
# ============================================================================

# THREADING & PERFORMANCE
MAX_THREADS=20
SOCKET_TIMEOUT=5
THREAD_TIMEOUT=30
DELAY_BETWEEN_SCANS=0.1

# For Raspberry Pi Zero - set to True for slower systems
SLOW_MODE=False

# SCANNING OPTIONS
PORT_RANGE=1-65535
COMMON_PORTS=21,22,23,25,53,80,443,465,587,993,995,3128,3306,5432,8000,8080,8888,9050,9051,9100,9200,27017,6379
BANNER_GRAB=True
BANNER_SIZE=1024
VERSION_DETECTION=True
SERVICE_FINGERPRINT=True
SITEMAP_ENABLED=True

# RETRY LOGIC
RETRY_COUNT=3
RETRY_DELAY=1

# LOGGING
LOG_LEVEL=INFO
LOG_FILE=logs/scanner.log

# OUTPUT
OUTPUT_DIR=results
EOF
    
    print_success "settings.txt created"
}

# Create urls.txt template
create_urls_txt() {
    print_info "Creating urls.txt..."
    cat > "${PROJECT_DIR}/urls.txt" << 'EOF'
# ============================================================================
# TARGET URLS FOR AUTHORIZED SCANNING
# ============================================================================
# Format: hostname:port, domain.onion, domain.i2p, or full URLs
# Lines starting with # are comments
# ============================================================================

# Example .onion addresses (REPLACE WITH YOUR OWN AUTHORIZED TARGETS)
# example1.onion:8080
# example2.onion:443

# Example .i2p addresses
# example.i2p:80

# Example IP addresses with ports
# 192.168.1.1:8080

# You can use just the domain without port
# yourdomain.onion
EOF
    
    print_success "urls.txt created (template)"
}

# Create requirements.txt
create_requirements_txt() {
    print_info "Creating requirements.txt..."
    cat > "${PROJECT_DIR}/requirements.txt" << 'EOF'
# Authorized Dark Web Service Scanner Dependencies
# ================================================
# This project uses only Python standard library modules
# No external dependencies required!

# Python 3.7+ Standard Library Modules:
# - socket (network communication)
# - threading (concurrent scanning)
# - json (data serialization)
# - logging (logging system)
# - pathlib (file path handling)
# - xml (XML generation)
# - argparse (command line arguments)
# - queue (thread-safe queue)
# - urllib (URL parsing)

# Installation:
# This project requires NO external packages
# Just Python 3.7+ built-in modules
EOF
    
    print_success "requirements.txt created"
}

# Create run_scan.sh wrapper script
create_run_scan_sh() {
    print_info "Creating run_scan.sh..."
    cat > "${PROJECT_DIR}/run_scan.sh" << 'EOF'
#!/bin/bash

################################################################################
# AUTHORIZED DARK WEB SERVICE SCANNER - EXECUTION WRAPPER
################################################################################
# Convenient wrapper script for running scanner with common options
# Usage: ./run_scan.sh [options]
################################################################################

# Strict error handling
set -euo pipefail

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

# Define ANSI color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Print colored info message
# Args: message text
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print colored success message
# Args: message text
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print colored warning message
# Args: message text
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print colored error message and exit
# Args: message text, exit code
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit "${2:-1}"
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

echo -e "${GREEN}=== Authorized Dark Web Service Scanner ===${NC}"
echo -e "${YELLOW}LEGAL: Only scan services you own or have authorization${NC}\n"

# Create necessary directories
mkdir -p logs results

# Check Python 3 availability
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 not found. Please install Python 3.7 or higher."
fi

python_version=$(python3 --version 2>&1 | awk '{print $2}')
print_info "Python version: $python_version"

# Parse command line arguments
TARGETS_FILE="urls.txt"
PORTS="common"
VERBOSE=""
SINGLE_TARGET=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            # URLs file argument
            TARGETS_FILE="$2"
            shift 2
            ;;
        -p|--ports)
            # Ports specification argument
            PORTS="$2"
            shift 2
            ;;
        -t|--target)
            # Single target argument
            SINGLE_TARGET="$2"
            shift 2
            ;;
        -v|--verbose)
            # Verbose flag
            VERBOSE="-v"
            shift
            ;;
        -h|--help)
            # Show help message
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -t, --target TARGET     Scan single target (IP/.onion/.i2p)"
            echo "  -f, --file FILE         Load targets from file (default: urls.txt)"
            echo "  -p, --ports PORTS       Ports to scan (default: common)"
            echo "  -v, --verbose           Enable verbose output"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -t example.onion -p common"
            echo "  $0 -f urls.txt -p 80,443,8080"
            echo "  $0 -t 192.168.1.1 -p 1-1000 -v"
            exit 0
            ;;
        *)
            # Unknown argument
            print_error "Unknown option: $1"
            ;;
    esac
done

# Run scanner
if [ -n "$SINGLE_TARGET" ]; then
    print_info "Scanning single target: $SINGLE_TARGET"
    python3 scanner.py -t "$SINGLE_TARGET" -p "$PORTS" -c settings.txt $VERBOSE
else
    print_info "Scanning targets from: $TARGETS_FILE"
    if [ ! -f "$TARGETS_FILE" ]; then
        print_error "Target file not found: $TARGETS_FILE"
    fi
    python3 scanner.py -f "$TARGETS_FILE" -p "$PORTS" -c settings.txt $VERBOSE
fi

# Report results
print_success "Scan complete!"
print_info "Results saved to: results/"
print_info "Logs saved to: logs/"
EOF
    
    chmod +x "${PROJECT_DIR}/run_scan.sh"
    print_success "run_scan.sh created and made executable"
}

# Create index.html web dashboard
create_index_html() {
    print_info "Creating index.html..."
    cat > "${PROJECT_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Authorized Dark Web Service Scanner - Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #333;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container { max-width: 1400px; margin: 0 auto; }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            margin-bottom: 30px;
        }
        
        .header h1 { color: #1e3c72; margin-bottom: 10px; }
        .header p { color: #666; font-size: 14px; }
        
        .legal-notice {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin-top: 15px;
            border-radius: 5px;
            font-size: 13px;
        }
        
        .result-card {
            background: rgba(255, 255, 255, 0.95);
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            margin-bottom: 20px;
        }
        
        table { width: 100%; border-collapse: collapse; }
        th { background: #4CAF50; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        
        .port-open { color: #d32f2f; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Authorized Dark Web Service Scanner</h1>
            <p>Multi-threaded port scanner and service identifier</p>
            <div class="legal-notice">
                <strong>⚠️ LEGAL NOTICE:</strong> Only scan services you own or have explicit authorization to test.
            </div>
        </div>
        
        <div class="result-card" style="text-align: center; color: #999;">
            <p>Scan results will appear here. Run scanner.py to generate results.</p>
        </div>
    </div>
</body>
</html>
EOF
    
    print_success "index.html created"
}

# ============================================================================
# VALIDATION & VERIFICATION
# ============================================================================

# Verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    local all_good=true
    
    # Check Python
    if ! command_exists python3; then
        print_warning "Python 3 not found in PATH"
        all_good=false
    else
        local py_version
        py_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        print_success "Python 3 available (${py_version})"
    fi
    
    # Check project files
    local files=("scanner.py" "settings.txt" "urls.txt" "run_scan.sh" "index.html")
    for file in "${files[@]}"; do
        if [ -f "${PROJECT_DIR}/${file}" ]; then
            print_success "✓ ${file} exists"
        else
            print_warning "✗ ${file} missing"
            all_good=false
        fi
    done
    
    # Check directories
    local dirs=("logs" "results")
    for dir in "${dirs[@]}"; do
        if [ -d "${PROJECT_DIR}/${dir}" ]; then
            print_success "✓ ${dir}/ directory exists"
        else
            print_warning "✗ ${dir}/ directory missing"
            all_good=false
        fi
    done
    
    # Verify main script is executable
    if [ -x "${PROJECT_DIR}/scanner.py" ]; then
        print_success "✓ scanner.py is executable"
    else
        chmod +x "${PROJECT_DIR}/scanner.py"
        print_success "✓ scanner.py made executable"
    fi
    
    if [ -x "${PROJECT_DIR}/run_scan.sh" ]; then
        print_success "✓ run_scan.sh is executable"
    else
        chmod +x "${PROJECT_DIR}/run_scan.sh"
        print_success "✓ run_scan.sh made executable"
    fi
    
    if [ "$all_good" = true ]; then
        print_success "Installation verification passed!"
        return 0
    else
        print_warning "Some files may be missing, but continuing..."
        return 0
    fi
}

# ============================================================================
# POST-INSTALLATION SETUP
# ============================================================================

# Print post-installation instructions
print_instructions() {
    echo ""
    print_success "Installation Complete!"
    echo ""
    echo -e "${BLUE}=== QUICK START ===${NC}"
    echo ""
    echo "1. Navigate to project directory:"
    echo "   cd ${PROJECT_DIR}"
    echo ""
    echo "2. Edit urls.txt with your authorized targets:"
    echo "   nano urls.txt"
    echo ""
    echo "3. Run a scan:"
    echo "   python3 scanner.py -f urls.txt -p common"
    echo "   OR"
    echo "   ./run_scan.sh"
    echo ""
    echo -e "${BLUE}=== EXAMPLE TARGETS ===${NC}"
    echo "   example.onion:8080"
    echo "   example.i2p:80"
    echo "   192.168.1.1:443"
    echo ""
    echo -e "${BLUE}=== RESULTS ===${NC}"
    echo "   View results in: ${PROJECT_DIR}/results/"
    echo "   View logs in:    ${PROJECT_DIR}/logs/"
    echo ""
    echo -e "${BLUE}=== CONFIGURATION ===${NC}"
    echo "   Edit settings: ${PROJECT_DIR}/settings.txt"
    echo ""
    echo -e "${BLUE}=== HELP ===${NC}"
    echo "   python3 scanner.py --help"
    echo "   ./run_scan.sh --help"
    echo ""
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================

main() {
    print_info "Starting installation of ${PROJECT_NAME}..."
    echo ""
    
    # Detect system information
    print_info "Detecting system information..."
    local os
    os=$(detect_os)
    print_success "Detected OS: ${os}"
    
    if [ "${os}" = "linux" ]; then
        local distro
        distro=$(detect_linux_distro)
        print_success "Detected Linux distribution: ${distro}"
        
        if is_raspberry_pi; then
            IS_RASPBERRY_PI=true
            print_success "Detected Raspberry Pi!"
        fi
    fi
    
    local arch
    arch=$(detect_architecture)
    print_success "Detected architecture: ${arch}"
    
    echo ""
    
    # Install dependencies unless skipped
    if [ "$SKIP_DEPENDENCIES" = false ]; then
        print_info "Installing dependencies..."
        install_python "${os}" "$(detect_linux_distro)"
    fi
    
    # Install Tor unless skipped
    if [ "$SKIP_TOR" = false ]; then
        install_tor "${os}" "$(detect_linux_distro)"
    fi
    
    # Install i2pd unless skipped
    if [ "$SKIP_I2PD" = false ]; then
        install_i2pd "${os}" "$(detect_linux_distro)"
    fi
    
    echo ""
    
    # Setup project
    print_info "Setting up project..."
    create_directories
    create_project_files
    
    echo ""
    
    # Verify installation
    verify_installation
    
    echo ""
    
    # Print instructions
    print_instructions
}

# ============================================================================
# EXECUTION
# ============================================================================

# Run main installation if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF

print_success "install.sh created"
}

# ============================================================================
# MAIN INSTALLATION SCRIPT BEGINS HERE
# ============================================================================

main() {
    # Print banner
    echo ""
    print_color "${COLOR_GREEN}" "╔════════════════════════════════════════════════════════════╗"
    print_color "${COLOR_GREEN}" "║  ${PROJECT_NAME}        ║"
    print_color "${COLOR_GREEN}" "║  Automated Installer                                       ║"
    print_color "${COLOR_GREEN}" "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Print disclaimer
    print_warning "LEGAL DISCLAIMER"
    echo "This tool is for AUTHORIZED SECURITY TESTING ONLY"
    echo "Only scan services you own or have explicit authorization to test"
    echo "Unauthorized scanning may violate computer fraud laws"
    echo ""
    
    # Detect system
    print_info "Detecting system information..."
    local os
    os=$(detect_os)
    
    if [ "${os}" = "unknown" ]; then
        print_error "Unsupported operating system"
    fi
    
    print_success "Detected OS: ${os}"
    
    # Get Linux distro if applicable
    local distro="unknown"
    if [ "${os}" = "linux" ]; then
        distro=$(detect_linux_distro)
        print_success "Detected distribution: ${distro}"
    fi
    
    # Check for Raspberry Pi
    if is_raspberry_pi; then
        IS_RASPBERRY_PI=true
        print_success "Detected Raspberry Pi - using optimized settings"
    fi
    
    # Get architecture
    local arch
    arch=$(detect_architecture)
    print_success "Detected architecture: ${arch}"
    
    echo ""
    
    # Install Python 3
    install_python "${os}" "${distro}"
    echo ""
    
    # Ask about optional dependencies
    print_info "Tor and i2pd are optional. They enable .onion and .i2p scanning"
    
    if [ "$SKIP_TOR" = false ]; then
        install_tor "${os}" "${distro}"
    fi
    
    echo ""
    
    if [ "$SKIP_I2PD" = false ]; then
        install_i2pd "${os}" "${distro}"
    fi
    
    echo ""
    
    # Create project structure
    print_info "Creating project directory: ${PROJECT_DIR}"
    create_directories
    
    echo ""
    
    # Create all project files
    print_info "Creating project files..."
    create_project_files
    
    echo ""
    
    # Verify installation
    verify_installation
    
    echo ""
    
    # Print post-installation instructions
    print_instructions
    
    # Print success
    echo ""
    print_success "Installation complete! Your portable scanner is ready!"
    echo -e "${COLOR_YELLOW}Copy the '${PROJECT_FOLDER}' folder anywhere and it will work!${COLOR_NC}"
}

# Run main if script is executed directly
main "$@"