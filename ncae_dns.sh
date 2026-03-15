#!/usr/bin/env bash
# =============================================================================
#  NCAE DNS SETUP — Team 19 — Rocky Linux 9
#  Scored: DNS INT FWD, DNS INT REV, DNS EXT FWD, DNS EXT REV (500pts each)
#  Run as root: sudo bash ncae_dns.sh
# =============================================================================

set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m';    BRED='\033[1;31m'
GREEN='\033[0;32m';  BGREEN='\033[1;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
WHITE='\033[1;37m';  DIM='\033[2m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
ok()   { echo -e "${BGREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }
die()  { err "$1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $*"; }
section() {
    echo -e "\n${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $*${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}\n"
}

[[ $EUID -ne 0 ]] && die "Must be run as root.  sudo bash $0"

# =============================================================================
#  CONFIG — change TEAM if needed
# =============================================================================
TEAM=19

INT_NET="192.168.${TEAM}"
EXT_WEB="172.18.13.${TEAM}"
EXT_SHELL="172.18.14.${TEAM}"

INT_DOMAIN="team${TEAM}.net"
EXT_DOMAIN="team${TEAM}.ncaecybergames.org"

ZONE_DIR="/var/named"
NAMED_CONF="/etc/named.conf"

# =============================================================================
#  BANNER
# =============================================================================
clear
echo -e "${CYAN}"
echo "  ██████╗ ███╗   ██╗███████╗"
echo "  ██╔══██╗████╗  ██║██╔════╝"
echo "  ██║  ██║██╔██╗ ██║███████╗"
echo "  ██║  ██║██║╚██╗██║╚════██║"
echo "  ██████╔╝██║ ╚████║███████║"
echo "  ╚═════╝ ╚═╝  ╚═══╝╚══════╝"
echo -e "${NC}"
echo -e "  ${WHITE}NCAE DNS Setup — Team ${TEAM} — Rocky Linux 9${NC}"
echo -e "  ${DIM}INT: ${INT_NET}.12  |  EXT: ${EXT_WEB} / ${EXT_SHELL}${NC}"
echo -e "  ${DIM}Scores: DNS INT FWD + REV + DNS EXT FWD + REV (2000pts total)${NC}"
echo

# =============================================================================
#  STEP 1 — Install BIND
# =============================================================================
section "STEP 1 — Installing BIND"

log "Installing bind and bind-utils..."
dnf install -y bind bind-utils || die "Failed to install BIND"
ok "BIND installed"

# =============================================================================
#  STEP 2 — Write named.conf
# =============================================================================
section "STEP 2 — Writing /etc/named.conf"

cp "$NAMED_CONF" "${NAMED_CONF}.bak_$(date +%Y%m%d%H%M%S)" 2>/dev/null && \
    info "Backed up existing named.conf"

cat > "$NAMED_CONF" << EOF
options {
    listen-on port 53 { any; };
    listen-on-v6 { none; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    allow-query { any; };
    recursion yes;
    forwarders { 8.8.8.8; 8.8.4.4; };
    dnssec-validation no;
};

logging {
    channel default_log {
        file "/var/named/data/named.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
    };
    category default { default_log; };
};

// Internal forward zone
zone "${INT_DOMAIN}" IN {
    type master;
    file "${ZONE_DIR}/${INT_DOMAIN}.zone";
    allow-update { none; };
};

// External forward zone
zone "${EXT_DOMAIN}" IN {
    type master;
    file "${ZONE_DIR}/${EXT_DOMAIN}.zone";
    allow-update { none; };
};

// Internal reverse zone (192.168.19.x)
zone "${TEAM}.168.192.in-addr.arpa" IN {
    type master;
    file "${ZONE_DIR}/192.168.${TEAM}.rev";
    allow-update { none; };
};

// External reverse zone (172.18.13.x and 172.18.14.x)
zone "13.18.172.in-addr.arpa" IN {
    type master;
    file "${ZONE_DIR}/172.18.13.rev";
    allow-update { none; };
};

zone "14.18.172.in-addr.arpa" IN {
    type master;
    file "${ZONE_DIR}/172.18.14.rev";
    allow-update { none; };
};
EOF

ok "named.conf written"

# =============================================================================
#  STEP 3 — Internal forward zone (team19.net)
# =============================================================================
section "STEP 3 — Internal Forward Zone (${INT_DOMAIN})"

mkdir -p "${ZONE_DIR}/data"

cat > "${ZONE_DIR}/${INT_DOMAIN}.zone" << EOF
\$TTL 86400
@   IN  SOA  ns1.${INT_DOMAIN}. admin.${INT_DOMAIN}. (
            $(date +%Y%m%d)01 ; serial
            3600              ; refresh
            900               ; retry
            604800            ; expire
            86400 )           ; minimum TTL

; Name servers
@       IN  NS   ns1.${INT_DOMAIN}.

; A records
ns1     IN  A    ${INT_NET}.12
www     IN  A    ${INT_NET}.5
db      IN  A    ${INT_NET}.7
EOF

ok "Internal forward zone written → ${INT_NET}.5 / .7 / .12"

# =============================================================================
#  STEP 4 — External forward zone (team19.ncaecybergames.org)
# =============================================================================
section "STEP 4 — External Forward Zone (${EXT_DOMAIN})"

cat > "${ZONE_DIR}/${EXT_DOMAIN}.zone" << EOF
\$TTL 86400
@   IN  SOA  ns1.${EXT_DOMAIN}. admin.${EXT_DOMAIN}. (
            $(date +%Y%m%d)01 ; serial
            3600              ; refresh
            900               ; retry
            604800            ; expire
            86400 )           ; minimum TTL

; Name servers
@       IN  NS   ns1.${EXT_DOMAIN}.

; A records
ns1     IN  A    ${EXT_WEB}
www     IN  A    ${EXT_WEB}
shell   IN  A    ${EXT_SHELL}
files   IN  A    ${EXT_SHELL}
EOF

ok "External forward zone written → ${EXT_WEB} / ${EXT_SHELL}"

# =============================================================================
#  STEP 5 — Internal reverse zone (192.168.19.x)
# =============================================================================
section "STEP 5 — Internal Reverse Zone (${INT_NET}.x)"

cat > "${ZONE_DIR}/192.168.${TEAM}.rev" << EOF
\$TTL 86400
@   IN  SOA  ns1.${INT_DOMAIN}. admin.${INT_DOMAIN}. (
            $(date +%Y%m%d)01 ; serial
            3600              ; refresh
            900               ; retry
            604800            ; expire
            86400 )           ; minimum TTL

@   IN  NS   ns1.${INT_DOMAIN}.

; PTR records (last octet only)
12  IN  PTR  ns1.${INT_DOMAIN}.
5   IN  PTR  www.${INT_DOMAIN}.
7   IN  PTR  db.${INT_DOMAIN}.
EOF

ok "Internal reverse zone written"

# =============================================================================
#  STEP 6 — External reverse zones (172.18.13.x and 172.18.14.x)
# =============================================================================
section "STEP 6 — External Reverse Zones"

cat > "${ZONE_DIR}/172.18.13.rev" << EOF
\$TTL 86400
@   IN  SOA  ns1.${EXT_DOMAIN}. admin.${EXT_DOMAIN}. (
            $(date +%Y%m%d)01 ; serial
            3600              ; refresh
            900               ; retry
            604800            ; expire
            86400 )           ; minimum TTL

@   IN  NS   ns1.${EXT_DOMAIN}.

; PTR records (last octet only)
${TEAM}  IN  PTR  ns1.${EXT_DOMAIN}.
${TEAM}  IN  PTR  www.${EXT_DOMAIN}.
EOF

cat > "${ZONE_DIR}/172.18.14.rev" << EOF
\$TTL 86400
@   IN  SOA  ns1.${EXT_DOMAIN}. admin.${EXT_DOMAIN}. (
            $(date +%Y%m%d)01 ; serial
            3600              ; refresh
            900               ; retry
            604800            ; expire
            86400 )           ; minimum TTL

@   IN  NS   ns1.${EXT_DOMAIN}.

; PTR records (last octet only)
${TEAM}  IN  PTR  shell.${EXT_DOMAIN}.
${TEAM}  IN  PTR  files.${EXT_DOMAIN}.
EOF

ok "External reverse zones written"

# =============================================================================
#  STEP 7 — Fix ownership + permissions
# =============================================================================
section "STEP 7 — Fixing Permissions"

chown root:named \
    "${ZONE_DIR}/${INT_DOMAIN}.zone" \
    "${ZONE_DIR}/${EXT_DOMAIN}.zone" \
    "${ZONE_DIR}/192.168.${TEAM}.rev" \
    "${ZONE_DIR}/172.18.13.rev" \
    "${ZONE_DIR}/172.18.14.rev"

chmod 640 \
    "${ZONE_DIR}/${INT_DOMAIN}.zone" \
    "${ZONE_DIR}/${EXT_DOMAIN}.zone" \
    "${ZONE_DIR}/192.168.${TEAM}.rev" \
    "${ZONE_DIR}/172.18.13.rev" \
    "${ZONE_DIR}/172.18.14.rev"

chown named:named "${ZONE_DIR}/data" 2>/dev/null || true

ok "Permissions set"

# =============================================================================
#  STEP 8 — Validate configs
# =============================================================================
section "STEP 8 — Validating Zone Files"

ERRORS=0

named-checkconf && ok "named.conf is valid" || { err "named.conf has errors!"; ERRORS=$((ERRORS+1)); }

named-checkzone "$INT_DOMAIN" "${ZONE_DIR}/${INT_DOMAIN}.zone" && \
    ok "INT forward zone OK" || { err "INT forward zone FAILED"; ERRORS=$((ERRORS+1)); }

named-checkzone "$EXT_DOMAIN" "${ZONE_DIR}/${EXT_DOMAIN}.zone" && \
    ok "EXT forward zone OK" || { err "EXT forward zone FAILED"; ERRORS=$((ERRORS+1)); }

named-checkzone "${TEAM}.168.192.in-addr.arpa" "${ZONE_DIR}/192.168.${TEAM}.rev" && \
    ok "INT reverse zone OK" || { err "INT reverse zone FAILED"; ERRORS=$((ERRORS+1)); }

named-checkzone "13.18.172.in-addr.arpa" "${ZONE_DIR}/172.18.13.rev" && \
    ok "EXT reverse zone 13 OK" || { err "EXT reverse zone 13 FAILED"; ERRORS=$((ERRORS+1)); }

named-checkzone "14.18.172.in-addr.arpa" "${ZONE_DIR}/172.18.14.rev" && \
    ok "EXT reverse zone 14 OK" || { err "EXT reverse zone 14 FAILED"; ERRORS=$((ERRORS+1)); }

if [[ $ERRORS -gt 0 ]]; then
    die "$ERRORS zone file(s) failed validation — fix before continuing"
fi

# =============================================================================
#  STEP 9 — SELinux
# =============================================================================
section "STEP 9 — SELinux"

if getenforce 2>/dev/null | grep -q "Enforcing"; then
    setsebool -P named_write_master_zones 1 2>/dev/null || true
    restorecon -Rv "$ZONE_DIR" 2>/dev/null || true
    ok "SELinux contexts applied"
else
    info "SELinux not enforcing — skipping"
fi

# =============================================================================
#  STEP 10 — Enable + start named
# =============================================================================
section "STEP 10 — Starting BIND"

systemctl enable --now named
systemctl restart named
sleep 2

systemctl is-active --quiet named && ok "named is running" || die "named failed to start — run: journalctl -u named -n 30"

# =============================================================================
#  STEP 11 — Firewall
# =============================================================================
section "STEP 11 — Firewall"

if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=dns
    firewall-cmd --reload
    ok "firewalld: DNS (port 53 TCP+UDP) opened"
else
    iptables -C INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || \
        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || \
        iptables -A INPUT -p udp --dport 53 -j ACCEPT
    ok "iptables: DNS port 53 opened"
fi

# =============================================================================
#  STEP 12 — Self-test
# =============================================================================
section "STEP 12 — Self-Test"

run_dig() {
    local label="$1" server="$2" query="$3" qtype="${4:-A}"
    local result
    result=$(dig @"$server" "$query" "$qtype" +short 2>/dev/null)
    if [[ -n "$result" ]]; then
        ok "  ${label}: ${result}"
    else
        warn "  ${label}: NO ANSWER"
    fi
}

echo -e "  ${WHITE}── Internal Forward ─────────────────────────────────${NC}"
run_dig "www.${INT_DOMAIN}"   "${INT_NET}.12" "www.${INT_DOMAIN}"
run_dig "db.${INT_DOMAIN}"    "${INT_NET}.12" "db.${INT_DOMAIN}"
run_dig "ns1.${INT_DOMAIN}"   "${INT_NET}.12" "ns1.${INT_DOMAIN}"

echo -e "\n  ${WHITE}── Internal Reverse ─────────────────────────────────${NC}"
run_dig "PTR ${INT_NET}.5"    "${INT_NET}.12" "${INT_NET}.5"  PTR
run_dig "PTR ${INT_NET}.7"    "${INT_NET}.12" "${INT_NET}.7"  PTR
run_dig "PTR ${INT_NET}.12"   "${INT_NET}.12" "${INT_NET}.12" PTR

echo -e "\n  ${WHITE}── External Forward ─────────────────────────────────${NC}"
run_dig "ns1.${EXT_DOMAIN}"   "${INT_NET}.12" "ns1.${EXT_DOMAIN}"
run_dig "www.${EXT_DOMAIN}"   "${INT_NET}.12" "www.${EXT_DOMAIN}"
run_dig "shell.${EXT_DOMAIN}" "${INT_NET}.12" "shell.${EXT_DOMAIN}"
run_dig "files.${EXT_DOMAIN}" "${INT_NET}.12" "files.${EXT_DOMAIN}"

echo -e "\n  ${WHITE}── External Reverse ─────────────────────────────────${NC}"
run_dig "PTR ${EXT_WEB}"      "${INT_NET}.12" "${EXT_WEB}"   PTR
run_dig "PTR ${EXT_SHELL}"    "${INT_NET}.12" "${EXT_SHELL}" PTR

# =============================================================================
#  DONE
# =============================================================================
echo
echo -e "${BGREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${BGREEN}  DNS SETUP COMPLETE — Team ${TEAM}${NC}"
echo -e "${BGREEN}══════════════════════════════════════════════════════${NC}"
echo
info "Internal DNS : ${INT_NET}.12"
info "External DNS : ${EXT_WEB}"
echo
warn "If any self-tests showed NO ANSWER, check: journalctl -u named -n 50 --no-pager"
warn "For external scoring, ensure your router forwards UDP/TCP 53 → ${INT_NET}.12"
echo
