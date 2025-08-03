#!/bin/bash

# Initialize firewall for ComputerAdaptiveTesting.jl development environment
# Based on Claude Code reference implementation

set -euo pipefail

# Check if running with required privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "🔒 Initializing firewall for Julia development environment..."

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Preserve Docker DNS resolution
iptables -I INPUT -i docker0 -j ACCEPT
iptables -I OUTPUT -o docker0 -j ACCEPT

# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Create ipset for allowed IPs
ipset create allowed_ips hash:net 2>/dev/null || ipset flush allowed_ips

# Add common development networks
ipset add allowed_ips 8.8.8.8/32      # Google DNS
ipset add allowed_ips 8.8.4.4/32      # Google DNS alternate
ipset add allowed_ips 1.1.1.1/32      # Cloudflare DNS
ipset add allowed_ips 1.0.0.1/32      # Cloudflare DNS alternate

# Add Julia package registry and common Julia infrastructure
echo "📦 Adding Julia package infrastructure IPs..."

# GitHub (for package source code)
GITHUB_IPS=$(curl -s https://api.github.com/meta | jq -r '.git[] | select(. | contains(":") | not)')
for ip in $GITHUB_IPS; do
    ipset add allowed_ips "$ip" 2>/dev/null || true
done

# Add specific Julia-related, Claude, and package repository domains
ALLOWED_DOMAINS=(
    "julialang.org"
    "pkg.julialang.org"
    "juliahub.com"
    "githubusercontent.com"
    "github.com"
    "storage.googleapis.com"  # For Julia binaries
    "claude.ai"
    "api.anthropic.com"
    "cdn.anthropic.com"
    "deb.debian.org"          # Debian package repository
    "debian.map.fastlydns.net" # Debian CDN
    "security.debian.org"     # Debian security updates
    "registry.npmjs.org"      # npm registry
    "nodejs.org"              # Node.js downloads
    "deb.nodesource.com"      # Node.js repository
)

for domain in "${ALLOWED_DOMAINS[@]}"; do
    echo "🔍 Resolving $domain..."
    IPS=$(dig +short "$domain" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
    for ip in $IPS; do
        echo "  Adding $ip for $domain"
        ipset add allowed_ips "$ip" 2>/dev/null || true
    done
done

# Allow SSH (in case it's needed)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Allow DNS queries
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow HTTP/HTTPS to allowed IPs
iptables -A OUTPUT -p tcp -m set --match-set allowed_ips dst --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp -m set --match-set allowed_ips dst --dport 443 -j ACCEPT

# Allow development ports (forward declared in devcontainer.json)
iptables -A INPUT -p tcp --dport 8000 -j ACCEPT
iptables -A INPUT -p tcp --dport 8888 -j ACCEPT

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

echo "✅ Firewall initialized successfully!"

# Verify basic connectivity
echo "🧪 Testing connectivity..."

# Test DNS resolution
if nslookup julialang.org >/dev/null 2>&1; then
    echo "  ✅ DNS resolution working"
else
    echo "  ❌ DNS resolution failed"
    exit 1
fi

# Test HTTPS connectivity to Julia registry
if curl -s --connect-timeout 10 https://pkg.julialang.org >/dev/null 2>&1; then
    echo "  ✅ Julia package registry accessible"
else
    echo "  ⚠️  Julia package registry test failed (may be expected)"
fi

# Test Claude API connectivity
if curl -s --connect-timeout 10 https://claude.ai >/dev/null 2>&1; then
    echo "  ✅ Claude API accessible"
else
    echo "  ⚠️  Claude API test failed (may be expected)"
fi

echo "🎉 Firewall setup complete! Julia development environment with Claude Code is secure."
