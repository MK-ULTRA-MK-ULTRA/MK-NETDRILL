#!/usr/bin/env bash
# ============================================================
#  mk-netdrill.sh  —  MK-NETDRILL | Networking & Protocol Trainer
#  DIY OverTheWire style | cheatsheet + drills + live labs
#  by MK-ULTRA
# ============================================================

# ── PALETTE: black / white, red for outlines only ───────────
RED=$'\033[1;31m'      # outlines only: banner frame, borders, dividers, brackets
WHITE=$'\033[1;37m'    # main text, commands, prompts
INV=$'\033[30;47m'     # black on white: badges and highlights
GRAY=$'\033[90m'       # notes
LGRAY=$'\033[38;5;250m'  # light gray: cheatsheet right-hand descriptions
BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'

VERSION="1.0.0"

# ── STATE / FILES ────────────────────────────────────────────
DATA_DIR="$HOME/.mk-netdrill"
SESSION_LOG="$DATA_DIR/session.log"
STATS_FILE="$DATA_DIR/stats"
mkdir -p "$DATA_DIR"

SCORE=0; TOTAL=0; STREAK=0          # this session
XP=0; ALL_TOTAL=0; ALL_CORRECT=0    # saved between sessions
BEST_STREAK=0; DAY_STREAK=0; BEST_BLITZ=0; LABS_SOLVED=0
LAST_DAY=""; LAST_DAILY=""
GAIN=0; RANKUP=""

load_stats() {
  [[ -f "$STATS_FILE" ]] || return 0
  local k v
  while IFS='=' read -r k v; do
    case "$k" in
      XP|ALL_TOTAL|ALL_CORRECT|BEST_STREAK|DAY_STREAK|BEST_BLITZ|LABS_SOLVED)
        [[ "$v" =~ ^[0-9]+$ ]] && printf -v "$k" '%s' "$v" ;;
      LAST_DAY|LAST_DAILY)
        [[ "$v" =~ ^[0-9-]*$ ]] && printf -v "$k" '%s' "$v" ;;
    esac
  done < "$STATS_FILE"
}

save_stats() {
  cat > "$STATS_FILE" <<EOF
XP=$XP
ALL_TOTAL=$ALL_TOTAL
ALL_CORRECT=$ALL_CORRECT
BEST_STREAK=$BEST_STREAK
DAY_STREAK=$DAY_STREAK
BEST_BLITZ=$BEST_BLITZ
LABS_SOLVED=$LABS_SOLVED
LAST_DAY=$LAST_DAY
LAST_DAILY=$LAST_DAILY
EOF
}

# ── RANKS ────────────────────────────────────────────────────
RANK_XP=(0 150 400 800 1400 2200)
RANK_NAME=("PACKET KID" "PORT SCANNER" "SUBNET SNIPER" "SYSADMIN" "PACKET WIZARD" "NETWORK NINJA")

rank_index() {
  local i idx=0
  for i in "${!RANK_XP[@]}"; do (( XP >= RANK_XP[i] )) && idx=$i; done
  echo "$idx"
}

rank_bar() {
  local idx cur next pct filled i bar=""
  idx=$(rank_index)
  if (( idx >= ${#RANK_XP[@]} - 1 )); then printf 'MAX RANK  %d XP' "$XP"; return; fi
  cur=${RANK_XP[idx]}; next=${RANK_XP[idx+1]}
  pct=$(( (XP - cur) * 100 / (next - cur) )); filled=$(( pct / 5 ))
  for ((i = 0; i < 20; i++)); do (( i < filled )) && bar+="█" || bar+="░"; done
  printf '%s  %d/%d XP' "$bar" "$XP" "$next"
}

add_xp() {   # add_xp <amount> — tracks rank-ups
  local before after
  before=$(rank_index); XP=$(( XP + $1 )); after=$(rank_index)
  (( after > before )) && RANKUP="${RANK_NAME[after]}"
}

flush_rankup() {
  if [[ -n "$RANKUP" ]]; then
    echo -e "\n  ${INV} ▲▲▲ RANK UP ▲▲▲ ${RESET}  ${WHITE}You are now: ${WHITE}$RANKUP${RESET}"
    RANKUP=""
  fi
}

record_result() {   # record_result 1 (correct) | 0 (wrong)
  local today yday bonus
  today=$(date +%F)
  if [[ "$LAST_DAY" != "$today" ]]; then
    yday=$(date -d yesterday +%F 2>/dev/null)
    if [[ "$LAST_DAY" == "$yday" ]]; then ((DAY_STREAK++)); else DAY_STREAK=1; fi
    LAST_DAY="$today"
  fi
  ((TOTAL++)); ((ALL_TOTAL++)); GAIN=0
  if [[ "$1" == "1" ]]; then
    ((SCORE++)); ((ALL_CORRECT++)); ((STREAK++))
    (( STREAK > BEST_STREAK )) && BEST_STREAK=$STREAK
    bonus=$(( (STREAK - 1) * 2 )); (( bonus > 10 )) && bonus=10
    GAIN=$(( 10 + bonus ))
    add_xp "$GAIN"
  else
    STREAK=0
  fi
  save_stats
}

normalize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

# ── UI PIECES ────────────────────────────────────────────────
show_banner() {
  local l
  echo -e "${WHITE}════════════════════════════════════════════════════════${RESET}\n"
  while IFS= read -r l; do
    l=${l//█/${WHITE}█${LGRAY}}
    printf '%s\n' "${LGRAY}${l}${RESET}"
  done <<'BANNER'
         ███╗   ███╗██╗  ██╗      ███╗   ██╗███████╗████████╗
         ████╗ ████║██║ ██╔╝      ████╗  ██║██╔════╝╚══██╔══╝
         ██╔████╔██║█████╔╝ █████╗██╔██╗ ██║█████╗     ██║
         ██║╚██╔╝██║██╔═██╗ ╚════╝██║╚██╗██║██╔══╝     ██║
         ██║ ╚═╝ ██║██║  ██╗      ██║ ╚████║███████╗   ██║
         ╚═╝     ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═══╝╚══════╝   ╚═╝
BANNER
  echo ""
  echo -e "              ${WHITE}${BOLD}Networking & Protocol Trainer${RESET} ${RED}·${RESET} ${WHITE}v${VERSION}${RESET}"
  echo -e "              ${LGRAY}Drills · Live Labs · Daily Challenge · Ranks${RESET}"
  echo -e "${LGRAY}════════════════════════════════════════════════════════${RESET}"
}

section_header() {
  echo -e "\n  ${RED}── ${WHITE}${BOLD}$1 ${RED}──────────────────────────────────────────────${RESET}"
}

status_bar() {
  local idx; idx=$(rank_index)
  echo -e "  ${RED}▌${RESET} ${WHITE}RANK${RESET} ${INV} ${RANK_NAME[idx]} ${RESET}  ${RED}│${RESET}  ${WHITE}$(rank_bar)${RESET}"
  echo -e "  ${RED}▌${RESET} ${WHITE}DAY STREAK${RESET} ${WHITE}${DAY_STREAK}${RESET}  ${RED}│${RESET}  ${WHITE}BEST STREAK${RESET} ${WHITE}${BEST_STREAK}${RESET}  ${RED}│${RESET}  ${WHITE}SESSION${RESET} ${WHITE}${SCORE}/${TOTAL}${RESET}"
}

pause_enter() { echo -ne "\n  ${DIM}Press Enter to return to menu...${RESET}"; read -r; }

summary() {
  echo -e "\n  ${WHITE}Session score:${RESET} ${WHITE}${BOLD}$SCORE${RESET}/${WHITE}$TOTAL${RESET}   ${RED}│${RESET}   ${WHITE}XP:${RESET} ${WHITE}$XP${RESET}"
  flush_rankup
  pause_enter
}

# ── CHEATSHEET ────────────────────────────────────────────────
show_cheatsheet() {
  clear
  show_banner
  echo -e "  ${WHITE}${BOLD}  NETWORKING & PROTOCOLS  —  CHEATSHEET${RESET}"
  echo ""
  echo -e "  ${RED}── ${WHITE}OSI MODEL ${RED}─────────────────────────────────────────────────────────${RESET}"
  printf "  ${WHITE}%-22s${RESET}  ${LGRAY}%s${RESET}\n" "L7 Application"  "HTTP, DNS, SSH, FTP, SMTP, DHCP, SNMP, NTP"
  printf "  ${WHITE}%-22s${RESET}  ${LGRAY}%s${RESET}\n" "L6 Presentation"  "Encryption, compression (TLS, SSL, JPEG/MPEG)"
  printf "  ${WHITE}%-22s${RESET}  ${LGRAY}%s${RESET}\n" "L5 Session"       "Session setup/teardown (RPC, NetBIOS)"
  printf "  ${WHITE}%-22s${RESET}  ${LGRAY}%s${RESET}\n" "L4 Transport"     "TCP, UDP, SCTP, ports"
  printf "  ${WHITE}%-22s${RESET}  ${LGRAY}%s${RESET}\n" "L3 Network"       "IP, ICMP, IGMP, IPsec, routing"
  printf "  ${WHITE}%-22s${RESET}  ${LGRAY}%s${RESET}\n" "L2 Data Link"     "MAC, ARP, PPP, VLAN (802.1Q), switches"
  printf "  ${WHITE}%-22s${RESET}  ${LGRAY}%s${RESET}\n" "L1 Physical"      "Cables, NICs, Wi-Fi (802.11), fiber, signals"
  echo ""
  echo -e "  ${RED}── ${WHITE}COMMON PORTS ${RED}──────────────────────────────────────────────────────${RESET}"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "20/21" "FTP data / control"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "22"    "SSH"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "23"    "Telnet (plaintext — avoid)"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "25"    "SMTP"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "53"    "DNS"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "67/68" "DHCP"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "80"    "HTTP"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "110"   "POP3"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "143"   "IMAP"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "161/162" "SNMP (agent / trap)"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "389"   "LDAP"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "443"   "HTTPS"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "445"   "SMB"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "465/587" "SMTPS / SMTP submission"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "636"   "LDAPS"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "993"   "IMAPS"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "995"   "POP3S"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "3306"  "MySQL"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "3389"  "RDP"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "5060/5061" "SIP (VoIP, plain / TLS)"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "5432"  "PostgreSQL"
  printf "  ${WHITE}%-8s${RESET}  ${LGRAY}%s${RESET}\n" "8080/8443" "Alt HTTP / HTTPS (proxies, dev servers)"
  echo ""
  echo -e "  ${RED}── ${WHITE}FIREWALLS: UFW / IPTABLES ${RED}────────────────────────────────────────${RESET}"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "ufw enable/disable"      "Toggle the firewall on/off"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "ufw status numbered"     "List rules with reference numbers"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "ufw allow/deny <port>"   "Add a simple allow/deny rule"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "iptables -L -n -v"       "List rules, numeric, verbose"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "INPUT/OUTPUT/FORWARD"    "The three default filter chains"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "ACCEPT/DROP/REJECT"      "Common rule targets"
  echo ""
  echo -e "  ${RED}── ${WHITE}TRAFFIC ANALYSIS: TCPDUMP / SSH / VPN ${RED}────────────────────────────${RESET}"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "tcpdump -i <iface>"      "Live capture on an interface"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "tcpdump -w/-r file.pcap" "Write/read a capture file"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "ssh -p / -L / -D"        "Custom port / local forward / SOCKS proxy"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "OpenVPN / WireGuard"     "UDP/1194  ·  UDP/51820"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "IPsec / IKEv2"           "UDP/500 (IKE)  ·  UDP/4500 (NAT-T)"
  echo ""
  echo -e "  ${RED}── ${WHITE}OPSEC BASICS ${RED}──────────────────────────────────────────────────────${RESET}"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "exiftool -all= file"     "Strip metadata (GPS, device, timestamps)"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "shred -u -z file"        "Securely overwrite + delete a file"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "macchanger -r <iface>"   "Randomize a MAC address"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "Need-to-know"            "Limit access to only what's required"
  printf "  ${WHITE}%-26s${RESET}  ${LGRAY}%s${RESET}\n" "Compartmentalization"    "Isolate identities so one leak ≠ total exposure"
  echo ""
  echo -e "  ${RED}── ${WHITE}PROXIES, VPN & DNS/LOCATION OPSEC ${RED}────────────────────────────────${RESET}"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "ssh -D 1080 user@host"        "SOCKS5 proxy through an SSH tunnel — no VPN software needed"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "curl --socks5 127.0.0.1:1080" "Route one command's traffic through a local SOCKS5 proxy"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "proxychains4 <cmd>"           "Force any command's traffic through configured proxy chain"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "torsocks <cmd>"               "Route one command's traffic through the Tor network"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "sudo systemctl start tor"     "Start local Tor daemon — SOCKS5 on 127.0.0.1:9050"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "wg-quick up wg0"              "Bring up a WireGuard VPN tunnel from a config file"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "sudo openvpn --config f.ovpn" "Connect using an OpenVPN profile"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "sshuttle -r user@host 0/0"    "Transparent VPN-like tunnel over plain SSH, no server app"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "resolvectl status"            "Show which DNS resolvers are active per interface"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "dig @1.1.1.1 example.com"     "Query a specific DNS resolver directly, bypass the default"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "kdig +tls @1.1.1.1 example.com" "DNS-over-TLS lookup — encrypts the DNS query itself"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "iodine / dnscat2"             "DNS tunneling — smuggle traffic inside DNS queries"
  printf "  ${WHITE}%-30s${RESET}  ${LGRAY}%s${RESET}\n" "curl ifconfig.me"             "Confirm the public IP you're presenting right now"
  printf "  ${DIM}Note: DNS tunneling and proxy/VPN chaining are legitimate for bypassing${RESET}\n"
  printf "  ${DIM}restrictive/censored networks and general privacy — only use them on${RESET}\n"
  printf "  ${DIM}networks and systems you own or are explicitly authorized to test.${RESET}\n"
  echo ""
  echo -e "  ${RED}── ${WHITE}OPTIONS ${RED}──────────────────────────────────────────────────────────${RESET}"
  status_bar
  echo ""
  echo -e "  ${RED}[${WHITE}1${RED}]${RESET}  ${WHITE}Flash-card drill${RESET}       ${GRAY}(Port/protocol → answer)${RESET}"
  echo -e "  ${RED}[${WHITE}2${RED}]${RESET}  ${WHITE}Reverse drill${RESET}          ${GRAY}(What is protocol/term X?)${RESET}"
  echo -e "  ${RED}[${WHITE}3${RED}]${RESET}  ${WHITE}Command challenge${RESET}      ${GRAY}(Write the command for this task)${RESET}"
  echo -e "  ${RED}[${WHITE}4${RED}]${RESET}  ${WHITE}Subnetting drill${RESET}       ${GRAY}(CIDR / mask math)${RESET}"
  echo -e "  ${RED}[${WHITE}5${RED}]${RESET}  ${WHITE}Firewall drill${RESET}         ${GRAY}(ufw + iptables)${RESET}"
  echo -e "  ${RED}[${WHITE}6${RED}]${RESET}  ${WHITE}Traffic analysis drill${RESET} ${GRAY}(tcpdump / ssh / vpn)${RESET}"
  echo -e "  ${RED}[${WHITE}7${RED}]${RESET}  ${WHITE}OPSEC drill${RESET}            ${GRAY}(metadata / anonymity / hygiene)${RESET}"
  echo -e "  ${RED}[${WHITE}8${RED}]${RESET}  ${WHITE}Proxy/VPN/DNS drill${RESET}    ${GRAY}(proxies / tunnels / location & DNS opsec)${RESET}"
  echo -e "  ${RED}[${WHITE}9${RED}]${RESET}  ${WHITE}Live explore mode${RESET}      ${GRAY}(Run real commands, guided)${RESET}"
  echo -e "  ${RED}[${WHITE}10${RED}]${RESET} ${INV}LIVE LAB${RESET}${WHITE}               ${GRAY}(Hunt a real flag on your own machine)${RESET}"
  echo -e "  ${RED}[${WHITE}11${RED}]${RESET} ${INV}WHO OWNS THIS IP?${RESET}${WHITE}      ${GRAY}(verify IPs: whois / rDNS / ss)${RESET}"
  echo -e "  ${RED}[${WHITE}12${RED}]${RESET} ${INV}TIMED BLITZ${RESET}${WHITE}            ${GRAY}(60 seconds, mixed questions, no mercy)${RESET}"
  echo -e "  ${RED}[${WHITE}13${RED}]${RESET} ${INV}DAILY CHALLENGE${RESET}${WHITE}        ${GRAY}(5 questions, same for everyone today)${RESET}"
  echo -e "  ${RED}[${WHITE}14${RED}]${RESET} ${WHITE}Rank, stats & session log${RESET}"
  echo -e "  ${RED}[${WHITE}15${RED}]${RESET} ${WHITE}Cheatsheet (this page)${RESET}"
  echo -e "  ${RED}[${WHITE}q${RED}]${RESET}  ${WHITE}Quit${RESET}"
  echo ""
}

# ── DATA ──────────────────────────────────────────────────────
# Format: "question|answer|explanation"
FLASH_QS=(
  "What port does SSH use?|22|SSH runs on TCP/22 by default for encrypted remote shell access"
  "What port does HTTP use?|80|Unencrypted web traffic — HTTPS (443) is the encrypted equivalent"
  "What port does HTTPS use?|443|TLS-wrapped HTTP — negotiates a cert before data flows"
  "What port does DNS use?|53|DNS uses UDP/53 for lookups, TCP/53 for zone transfers/large responses"
  "What port does SMB use?|445|SMB is Windows file/printer sharing — a frequent lateral-movement target"
  "What port does RDP use?|3389|Remote Desktop Protocol — often exposed and brute-forced on the internet"
  "What port does Telnet use?|23|Legacy remote shell — plaintext, deprecated in favor of SSH"
  "What port does FTP control channel use?|21|FTP control (commands) on 21; data channel is separate (20 or passive)"
  "What port does SMTP use?|25|Mail transfer between servers — 587 is used for authenticated client submission"
  "What protocol maps IP addresses to MAC addresses?|ARP|Address Resolution Protocol operates at Layer 2"
  "What protocol is used for ping?|ICMP|Internet Control Message Protocol — echo request/reply, also used for traceroute"
  "What layer do TCP and UDP operate at?|4|Transport layer — handles ports, segmentation, and (for TCP) reliability"
  "What layer does a switch operate at?|2|Switches forward frames based on MAC address tables"
  "What layer does a router operate at?|3|Routers forward packets based on IP addresses and routing tables"
  "What port does NTP use?|123|Network Time Protocol synchronizes clocks over UDP/123"
  "What port does LDAP use?|389|Lightweight Directory Access Protocol — 636 is LDAPS, the encrypted variant"
  "What port does OpenVPN use by default?|1194|Runs over UDP by default for lower latency, though TCP is supported"
  "What port does WireGuard use by default?|51820|A single UDP port — no separate control/data channel like IPsec"
  "What ports does IPsec/IKEv2 use?|500 and 4500|500 for the initial IKE negotiation, 4500 for NAT-traversal"
  "What iptables target silently drops a packet without a reply?|drop|REJECT sends back an error response instead; DROP just discards silently"
  "What does OPSEC stand for?|operations security|A process for identifying and controlling what an adversary could observe or infer about you"
  "What OPSEC principle limits access to only those who require it?|need to know|Also called least privilege — shrinks the blast radius if one account is compromised"
  "What term describes isolating identities/projects so one compromise doesn't expose the rest?|compartmentalization|Keeps separate personas, accounts, or activities from being linked together"
  "What anonymity network routes traffic through multiple encrypted volunteer relays?|tor|The Onion Router — wraps traffic in layers of encryption across at least three hops"
  "What do you call hidden data (GPS, device, timestamps) embedded in files like photos?|metadata|Often stripped with tools like exiftool before sharing files publicly"
  "What port does POP3 use?|110|Downloads and typically removes mail from the server — 995 is the encrypted version"
  "What port does IMAP use?|143|Syncs mail state across devices instead of downloading and deleting — 993 is the encrypted version"
  "What port does SNMP use for polling devices?|161|162 is used for unsolicited traps sent from devices to a monitoring server"
  "What port does LDAP use unencrypted?|389|636 is LDAPS, the TLS-wrapped equivalent"
  "What port is used for SMTP authenticated submission?|587|The modern standard for clients sending mail; 465 is the older implicit-TLS variant"
  "What ports does SIP use for VoIP signaling?|5060 and 5061|5060 is plaintext, 5061 is TLS-encrypted SIP signaling"
)

REVERSE_QS=(
  "TCP|Connection-oriented, reliable transport protocol|Three-way handshake (SYN/SYN-ACK/ACK), guarantees delivery and ordering"
  "UDP|Connectionless, best-effort transport protocol|No handshake, no delivery guarantee — used where speed matters more than reliability (DNS, streaming, VoIP)"
  "ARP|Resolves IP addresses to MAC addresses on a local segment|Broadcast request, unicast reply — cached in the ARP table"
  "DHCP|Dynamically assigns IP configuration to hosts|DORA process: Discover, Offer, Request, Acknowledge"
  "NAT|Translates private IPs to a public IP for internet access|Lets many internal hosts share one external address"
  "VLAN|Logically segments a physical network into separate broadcast domains|Tagged with 802.1Q — isolates traffic without separate physical switches"
  "Subnet mask|Defines which portion of an IP address is network vs host|e.g. /24 = 255.255.255.0 = first 24 bits are network"
  "Default gateway|The router a host sends traffic to when the destination isn't local|Usually the first or last usable IP in a subnet"
  "TTL|Limits how many hops a packet can traverse before being discarded|Prevents routing loops; decremented by each router hop"
  "Three-way handshake|TCP's connection setup sequence|SYN → SYN-ACK → ACK establishes a reliable connection before data flows"
  "UFW|Simplified front-end for managing iptables/nftables rules|Ubuntu's 'Uncomplicated Firewall' — friendlier syntax than raw iptables"
  "iptables|Linux kernel firewall utility that filters packets via chains and rules|Rules live in chains (INPUT/OUTPUT/FORWARD); being succeeded by nftables on newer distros"
  "iptables chains (INPUT/OUTPUT/FORWARD)|The three built-in points where packets can be filtered|INPUT=incoming to this host, OUTPUT=outgoing from this host, FORWARD=routed through this host"
  "VPN|Encrypted tunnel that extends a private network across a public one|Common implementations: OpenVPN, WireGuard, IPsec/IKEv2"
  "tcpdump|Command-line packet sniffer for capturing and filtering live traffic|Uses BPF filter syntax; captures can be saved to .pcap and opened in Wireshark"
)

CMD_QS=(
  "Show all listening TCP/UDP ports with process names|ss -tunap|-t=TCP -u=UDP -n=numeric -a=all -p=process"
  "Ping a host 4 times|ping -c 4 8.8.8.8|-c limits the count instead of running forever"
  "Show the routing table|ip route show|Modern replacement for the deprecated 'route -n'"
  "Resolve a domain's DNS records|dig example.com|Verbose DNS lookup tool; nslookup is the older alternative"
  "Trace the network path to a host|traceroute 8.8.8.8|Sends packets with increasing TTL to map each hop"
  "Show the ARP cache|arp -a|Lists known IP-to-MAC mappings on the local segment"
  "Scan a host for open TCP ports|nmap -sT 192.168.1.1|-sT does a full TCP connect scan"
  "Do a SYN stealth scan of the top 1000 ports|nmap -sS 192.168.1.1|-sS is faster/quieter than -sT, needs root for raw sockets"
  "Capture packets on interface eth0|tcpdump -i eth0|-i selects the interface to sniff on"
  "Show current network interfaces and IPs|ip a|Modern replacement for 'ifconfig'"
  "Test if a specific TCP port is open|nc -zv 192.168.1.1 22|-z scans without sending data, -v is verbose"
)

FIREWALL_QS=(
  "Enable the UFW firewall|ufw enable|Turns the firewall on and applies it at boot"
  "Check UFW status with rule numbers|ufw status numbered|Numbered output makes rules easy to reference for deletion"
  "Allow SSH through UFW|ufw allow 22/tcp|Or 'ufw allow ssh' — UFW recognizes common service names from /etc/services"
  "Allow both HTTP and HTTPS through UFW in one rule|ufw allow 80,443/tcp|Comma syntax opens multiple ports in a single rule"
  "Set UFW to deny all incoming traffic by default|ufw default deny incoming|Standard baseline — explicitly allow only what's needed, deny everything else"
  "Delete UFW rule number 3|ufw delete 3|Run 'ufw status numbered' first to find the rule number to delete"
  "Allow traffic from one specific IP only with UFW|ufw allow from 192.168.1.10|Restricts access to a single trusted source address"
  "List all iptables rules, numeric, with line numbers|iptables -L -n --line-numbers|-n skips slow reverse-DNS lookups on every rule"
  "Block a single IP address with iptables|iptables -A INPUT -s 203.0.113.5 -j DROP|Appends a rule to INPUT dropping all traffic from that source"
  "Allow established/related connections back in with iptables|iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT|Lets return traffic through without re-matching every rule"
  "Save iptables rules so they persist after reboot (Debian/Ubuntu)|iptables-save > /etc/iptables/rules.v4|iptables rules live in memory only until saved to a file loaded at boot"
  "Flush (clear) all iptables rules|iptables -F|Removes every rule in the current table — risky on a remote box, can lock you out"
)

TRAFFIC_QS=(
  "Capture only port 80 traffic on eth0 with tcpdump|tcpdump -i eth0 port 80|Filters the capture to one port using BPF syntax"
  "Capture traffic to/from one host with tcpdump|tcpdump -i eth0 host 192.168.1.5|Matches packets where that IP is source or destination"
  "Save a tcpdump capture to a file for later analysis|tcpdump -i eth0 -w capture.pcap|.pcap files can be reopened later in Wireshark"
  "Read back a saved tcpdump capture file|tcpdump -r capture.pcap|-r reads from a file instead of sniffing live"
  "Show tcpdump packet contents in readable ASCII|tcpdump -A|Handy for spotting plaintext creds or HTTP headers in the payload"
  "Connect via SSH to a non-default port|ssh -p 2222 user@host|-p sets the port when SSH isn't listening on the default 22"
  "Copy a file to a remote server over SSH|scp file.txt user@host:/remote/path|Uses the SSH protocol underneath for an encrypted transfer"
  "Generate a new SSH key pair|ssh-keygen -t ed25519|ed25519 keys are shorter and faster than RSA at equivalent security"
  "Create a local port forward through an SSH tunnel|ssh -L 8080:localhost:80 user@host|Forwards local port 8080 to port 80 on the remote side"
  "Turn an SSH connection into a SOCKS proxy|ssh -D 1080 user@host|-D opens a dynamic SOCKS5 proxy for routing other traffic through the tunnel"
)

OPSEC_QS=(
  "Strip all metadata (EXIF/GPS/device info) from an image|exiftool -all= image.jpg|Removes GPS tags, camera model, and timestamps before you share a file publicly"
  "Securely wipe a file so it can't be recovered|shred -u -z file.txt|-u deletes it after overwriting, -z does a final zero pass to hide that shredding happened"
  "Randomize the MAC address on interface wlan0|macchanger -r wlan0|-r assigns a random MAC so the device isn't tracked by its hardware address"
  "Clear your bash history for the current session|history -c && history -w|-c clears it in memory, -w writes the now-empty history out to disk"
  "Check what public IP address you present to the internet|curl ifconfig.me|Confirms a VPN/proxy is actually masking your real IP before you trust it"
  "Check for DNS leaks while connected to a VPN|dig +short myip.opendns.com @resolver1.opendns.com|If the result doesn't match your VPN's exit IP, DNS queries are leaking outside the tunnel"
  "Symmetrically encrypt a file with a passphrase using GPG|gpg -c file.txt|Prompts for a passphrase and produces file.txt.gpg; no key pair needed"
  "Generate a new GPG key pair|gpg --full-generate-key|Creates a public/private key pair for asymmetric encryption and signing"
  "List processes listening on the network|ss -tunlp|Surfaces unexpected services that could be leaking data or accepting unwanted connections"
  "Verify a downloaded file's integrity with a hash|sha256sum file.iso|Compare the output against a publisher's published hash to confirm it wasn't tampered with"
)

PROXY_QS=(
  "Turn an SSH session into a local SOCKS5 proxy|ssh -D 1080 user@host|-D opens a dynamic SOCKS proxy on localhost:1080 — point apps/browsers at it"
  "Route one curl request through a local SOCKS5 proxy|curl --socks5 127.0.0.1:1080 https://example.com|Sends just that request through the proxy, not the whole system"
  "Force any command's traffic through a configured proxy chain|proxychains4 curl ifconfig.me|Reads proxy list from /etc/proxychains4.conf, chains through them in order"
  "Route a single command's traffic through the Tor network|torsocks curl ifconfig.me|Wraps one command so its traffic goes through Tor without a system-wide change"
  "Start the local Tor daemon|sudo systemctl start tor|Tor's SOCKS5 proxy listens on 127.0.0.1:9050 once running"
  "Bring up a WireGuard VPN tunnel from a config file|wg-quick up wg0|Reads /etc/wireguard/wg0.conf and brings the interface up"
  "Take a WireGuard VPN tunnel back down|wg-quick down wg0|Cleanly removes the interface and routes it added"
  "Connect to a VPN using an OpenVPN profile|sudo openvpn --config profile.ovpn|Runs in the foreground by default; add --daemon to background it"
  "Create a transparent VPN-like tunnel over plain SSH (no server-side VPN app)|sshuttle -r user@host 0/0|Routes all traffic (0/0) through the SSH host — no OpenVPN/WireGuard install needed on the far end"
  "Show which DNS resolvers are active on each interface|resolvectl status|Useful for confirming a VPN actually took over DNS, not just routing"
  "Query a specific DNS resolver directly instead of the system default|dig @1.1.1.1 example.com|Bypasses whatever resolver is configured in /etc/resolv.conf"
  "Do an encrypted DNS-over-TLS lookup|kdig +tls @1.1.1.1 example.com|Prevents anyone on-path from reading your DNS queries in plaintext"
  "Check your system's currently configured DNS servers|cat /etc/resolv.conf|On systemd-resolved systems this may just point to 127.0.0.53 — use resolvectl for the real upstream"
  "Verify your public-facing IP after connecting to a VPN/proxy|curl ifconfig.me|Do this before AND after connecting to confirm the tunnel actually changed your exit IP"
  "Check if a VPN is leaking DNS queries outside the tunnel|dig +short myip.opendns.com @resolver1.opendns.com|If the returned IP isn't your VPN's exit IP, DNS isn't going through the tunnel"
)



SUBNET_QS=(
  "How many usable hosts does a /24 provide?|254|2^8 - 2 (network + broadcast reserved) = 254"
  "How many usable hosts does a /30 provide?|2|2^2 - 2 = 2 — the classic point-to-point link subnet"
  "What is the subnet mask for a /26?|255.255.255.192|/26 leaves 6 host bits: 2^6=64 addresses per block, mask = 256-64=192"
  "What is the network address for 192.168.1.130/25?|192.168.1.128|/25 blocks are 128 addresses wide: 0-127, 128-255 — .130 falls in the second block"
  "What is the broadcast address for 192.168.1.0/24?|192.168.1.255|Last address in the block is always reserved for broadcast"
  "How many /24 subnets fit inside a /22?|4|/22 to /24 is a difference of 2 bits: 2^2 = 4"
  "What CIDR notation matches subnet mask 255.255.255.0?|/24|Each octet of 255 = 8 network bits; three full octets = 24"
)

# Format: "ip|accepted owner keywords (comma separated)|owner shown|explanation"  (ownership can change — always verify with whois)
IP_QS=(
  "8.8.8.8|google|Google|Google Public DNS. whois shows Google LLC; dig -x gives dns.google"
  "8.8.4.4|google|Google|The secondary Google Public DNS resolver"
  "1.1.1.1|cloudflare|Cloudflare|Cloudflare's public resolver. dig -x gives one.one.one.one"
  "1.0.0.1|cloudflare|Cloudflare|The secondary Cloudflare resolver"
  "9.9.9.9|quad9|Quad9|Privacy/security-focused public DNS. dig -x gives dns9.quad9.net"
  "208.67.222.222|opendns,cisco|OpenDNS (Cisco)|OpenDNS resolver, owned by Cisco. dig -x gives resolver1.opendns.com"
  "140.82.112.3|github|GitHub|GitHub's own range. A 'datacenter' IP that is totally normal for devs"
  "23.64.114.4|akamai|Akamai|Akamai CDN. Websites, updates and apps are served from here. High 'fraud score' sites flag it only because it's a hosting range"
  "34.107.243.93|google|Google Cloud|rDNS: 93.243.107.34.bc.googleusercontent.com. Firefox talks to this range for tracking-protection / safe-browsing style checks"
  "151.101.1.69|fastly|Fastly|Fastly CDN, which fronts a huge number of big websites"
  "13.107.42.14|microsoft|Microsoft|Microsoft's range, used for Office/Teams/Bing-type services"
)

# Pool for blitz + daily challenge (everything except self-graded reverse drill)
ALL_QS=(
  "${FLASH_QS[@]}" "${CMD_QS[@]}" "${SUBNET_QS[@]}"
  "${FIREWALL_QS[@]}" "${TRAFFIC_QS[@]}" "${OPSEC_QS[@]}" "${PROXY_QS[@]}"
)

# ── HELPERS ───────────────────────────────────────────────────
log_line() { echo "$(date '+%F %T') | $*" >> "$SESSION_LOG"; }

# returns 0 = answered, 2 = user typed q
ask_question() {
  local question="$1" correct="$2" explanation="$3" answer given expected
  echo -e "\n  ${WHITE}${BOLD}❓  ${WHITE}$question${RESET}"
  echo -ne "  ${WHITE}Your answer: ${RESET}"
  read -r answer || return 2
  [[ "${answer,,}" == "q" ]] && return 2
  given=$(normalize "$answer"); expected=$(normalize "$correct")
  if [[ "$given" == "$expected" ]]; then
    record_result 1
    local fire=""; (( STREAK > 1 )) && fire="  ${WHITE}🔥 x${STREAK}${RESET}"
    echo -e "  ${INV} ✔ Correct! ${RESET}  ${WHITE}+${GAIN} XP${RESET}${fire}"
    echo -e "  ${DIM}$explanation${RESET}"
    log_line "CORRECT | Q: $question | A: $correct"
  else
    record_result 0
    echo -e "  ${WHITE}${BOLD}✘  Wrong.${RESET}  Correct answer: ${WHITE}${BOLD}$correct${RESET}"
    echo -e "  ${DIM}$explanation${RESET}"
    log_line "WRONG   | Q: $question | Expected: $correct | Got: $given"
  fi
  flush_rankup
  return 0
}

# ── MODES ─────────────────────────────────────────────────────
# Generic drill: drill_loop "TITLE" "instructions" ARRAY_NAME
drill_loop() {
  local title="$1" sub="$2" arr_name="$3" entry q a exp nxt rc
  local -n arr="$arr_name"
  local -a shuffled
  clear
  section_header "$title"
  echo -e "  ${WHITE}$sub${RESET} Type ${WHITE}q${RESET} to return to the menu.\n"
  mapfile -t shuffled < <(printf '%s\n' "${arr[@]}" | shuf)
  for entry in "${shuffled[@]}"; do
    IFS='|' read -r q a exp <<< "$entry"
    echo -ne "  ${DIM}[Score: $SCORE/$TOTAL · streak $STREAK · XP $XP]${RESET}"
    ask_question "$q" "$a" "$exp"; rc=$?
    (( rc == 2 )) && break
    echo -ne "  ${DIM}Press Enter for next, or q to quit: ${RESET}"
    read -r nxt; [[ "$nxt" == "q" ]] && break
  done
  summary
}

mode_flash()    { drill_loop "FLASH-CARD DRILL"                        "Type the answer."                FLASH_QS; }
mode_commands() { drill_loop "COMMAND CHALLENGE"                       "Write the command for each task." CMD_QS; }
mode_subnet()   { drill_loop "SUBNETTING DRILL"                        "CIDR / subnet mask math."        SUBNET_QS; }
mode_firewall() { drill_loop "FIREWALL DRILL: UFW + IPTABLES"          "Write the command for each task." FIREWALL_QS; }
mode_traffic()  { drill_loop "TRAFFIC ANALYSIS DRILL: TCPDUMP / SSH / VPN" "Write the command for each task." TRAFFIC_QS; }
mode_opsec()    { drill_loop "OPSEC DRILL: METADATA / ANONYMITY / HYGIENE" "Write the command for each task." OPSEC_QS; }
mode_proxy()    { drill_loop "PROXY / VPN / DNS DRILL: TUNNELS & LOCATION OPSEC" "Write the command for each task." PROXY_QS; }

# Reverse drill is self-graded — be honest with yourself, it feeds your XP
mode_reverse() {
  local entry term purpose explanation answer ok
  local -a shuffled
  clear
  section_header "REVERSE DRILL: What is X?"
  echo -e "  ${WHITE}Describe the term in your own words, then grade yourself honestly.${RESET} Type ${WHITE}q${RESET} to return.\n"
  mapfile -t shuffled < <(printf '%s\n' "${REVERSE_QS[@]}" | shuf)
  for entry in "${shuffled[@]}"; do
    IFS='|' read -r term purpose explanation <<< "$entry"
    echo -e "\n  ${WHITE}${BOLD}❓  ${WHITE}What is ${WHITE}$term${WHITE}?${RESET}"
    echo -ne "  ${WHITE}Your answer: ${RESET}"
    read -r answer || break
    [[ "${answer,,}" == "q" ]] && break
    echo -e "  ${WHITE}${BOLD}Answer:${RESET} $purpose"
    echo -e "  ${DIM}$explanation${RESET}"
    echo -ne "  ${WHITE}Did you get it? [y/N]: ${RESET}"
    read -r ok
    if [[ "${ok,,}" == "y" ]]; then
      record_result 1; echo -e "  ${WHITE}✔  +${GAIN} XP${RESET}"
    else
      record_result 0; echo -e "  ${WHITE}✘  Review it and it'll come back.${RESET}"
    fi
    flush_rankup
  done
  summary
}

mode_explore() {
  local prompt input
  clear
  section_header "LIVE EXPLORE MODE"
  echo -e "  ${WHITE}Practice real commands on your actual system. Guided prompts below.${RESET}"
  echo -e "  Type ${WHITE}done${RESET} to return to menu.\n"

  local -a EXPLORE_PROMPTS=(
    "Run: ip a   — Identify your local IP and interface name"
    "Run: ip route show   — What's your default gateway?"
    "Run: ss -tunap   — What's listening on your machine right now?"
    "Run: arp -a   — What devices are in your ARP cache?"
    "Run: dig example.com   — What A record comes back?"
    "Run: traceroute 8.8.8.8   — How many hops to Google's DNS?"
    "Run: ping -c 4 1.1.1.1   — What's your average round-trip time?"
    "Run: nmap -sT localhost   — What ports are open on your own machine?"
    "Run: cat /etc/resolv.conf   — What DNS servers are you using?"
    "Run: nc -zv 127.0.0.1 22   — Is SSH open locally?"
    "Run: sudo ufw status verbose   — What rules are currently active?"
    "Run: sudo iptables -L -n -v   — What's your INPUT chain's default policy?"
    "Run: sudo tcpdump -i any -c 5   — Capture 5 packets, what protocols show up?"
    "Run: curl ifconfig.me   — What public IP are you presenting right now?"
    "Run: exiftool -a -u -g1 <somefile>   — What metadata is embedded in a file you have?"
    "Run: resolvectl status   — Which DNS resolver is actually active on your main interface?"
    "Run: dig @1.1.1.1 example.com   — Compare this to your default resolver's answer, same result?"
    "Run: ssh -D 1080 -N user@somehost (if you have a box to test with)   — then curl --socks5 127.0.0.1:1080 ifconfig.me — did the IP change?"
  )

  for prompt in "${EXPLORE_PROMPTS[@]}"; do
    echo -e "\n  ${BOLD}${WHITE}▸  ${WHITE}$prompt${RESET}"
    echo -ne "  ${WHITE}(run it, then press Enter to continue, or type 'done'): ${RESET}"
    read -r input
    [[ "$input" == "done" ]] && break
  done
  echo -e "\n  ${WHITE}${BOLD}Great exploration session!${RESET}"
  pause_enter
}

# ── WHO OWNS THIS IP? ─────────────────────────────────────────
valid_ipv4() {
  local ip="$1" o
  [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  for o in ${ip//./ }; do (( 10#$o <= 255 )) || return 1; done
  return 0
}

ip_lookup() {
  local ip="$1" who rdns conns low
  if ! valid_ipv4 "$ip"; then echo -e "  ${WHITE}Not a valid IPv4 address.${RESET}"; return; fi
  if ! command -v whois >/dev/null; then echo -e "  ${WHITE}whois not installed (sudo apt install whois).${RESET}"; return; fi

  echo -e "\n  ${WHITE}${BOLD}1) whois${RESET}   ${GRAY}whois $ip | grep -iE 'orgname|netname|descr'${RESET}"
  who=$(whois "$ip" 2>/dev/null | grep -iE '^(orgname|org-name|organization|netname|descr|owner|country):' | head -6)
  [[ -n "$who" ]] && echo "$who" | sed 's/^/     /' || echo -e "     ${DIM}(no answer)${RESET}"

  echo -e "\n  ${WHITE}${BOLD}2) reverse DNS${RESET}   ${GRAY}dig -x $ip +short${RESET}"
  if command -v dig >/dev/null; then
    rdns=$(dig -x "$ip" +short +time=3 +tries=1 2>/dev/null)
    [[ -n "$rdns" ]] && echo "$rdns" | sed 's/^/     /' || echo -e "     ${DIM}(no PTR record)${RESET}"
  else
    echo -e "     ${DIM}dig not installed (sudo apt install dnsutils)${RESET}"
  fi

  echo -e "\n  ${WHITE}${BOLD}3) is it connected to YOU?${RESET}   ${GRAY}ss -tnp | grep $ip${RESET}"
  conns=$(ss -tnp 2>/dev/null | grep -F "$ip")
  [[ -n "$conns" ]] && echo "$conns" | sed 's/^/     /' || echo -e "     ${DIM}(no live connection right now)${RESET}"

  low=$(printf '%s %s' "$who" "$rdns" | tr '[:upper:]' '[:lower:]')
  echo ""
  if [[ "$low" =~ (akamai|cloudflare|google|amazon|cloudfront|microsoft|azure|fastly|github) ]]; then
    echo -e "  ${WHITE}${BOLD}VERDICT:${RESET} ${WHITE}Big CDN/cloud owner. Usually benign background traffic.${RESET}"
    echo -e "  ${DIM}Fraud-score sites flag these ranges just for being datacenter IPs. Check direction + which process.${RESET}"
  elif [[ "$low" =~ (digitalocean|ovh|hetzner|linode|vultr|choopa|contabo|leaseweb) ]]; then
    echo -e "  ${WHITE}${BOLD}VERDICT:${RESET} ${WHITE}Cheap VPS/hosting. Scanners and botnets love these too.${RESET}"
    echo -e "  ${DIM}Not proof of anything. Check direction, how often it hits you, and what port.${RESET}"
  else
    echo -e "  ${WHITE}${BOLD}VERDICT:${RESET} ${WHITE}Unknown owner. Check direction, frequency and port in your logs.${RESET}"
  fi
}

mode_whois() {
  local choice ip entry q kws shown exp answer given k hit nxt rc
  local -a shuffled
  while true; do
    clear
    section_header "WHO OWNS THIS IP?"
    echo -e "  ${WHITE}Don't trust fraud scores. Verify in 3 commands:${RESET}"
    echo -e "    ${WHITE}whois <ip> | grep -iE 'orgname|netname'${RESET}   ${GRAY}# who owns the range${RESET}"
    echo -e "    ${WHITE}dig -x <ip> +short${RESET}                        ${GRAY}# reverse DNS name${RESET}"
    echo -e "    ${WHITE}ss -tnp | grep <ip>${RESET}                       ${GRAY}# is a process on YOUR box talking to it?${RESET}\n"
    echo -e "  ${RED}[${WHITE}1${RED}]${RESET} ${WHITE}Quiz${RESET}    ${GRAY}(identify the owner of an IP using real commands)${RESET}"
    echo -e "  ${RED}[${WHITE}2${RED}]${RESET} ${WHITE}Lookup${RESET}  ${GRAY}(check an IP from your own logs, runs all 3 for you)${RESET}"
    echo -e "  ${RED}[${WHITE}b${RED}]${RESET} ${WHITE}Back${RESET}\n"
    echo -ne "  ${BOLD}Select: ${RESET}"; read -r choice
    case "$choice" in
      1)
        clear; section_header "IP OWNER QUIZ"
        echo -e "  ${WHITE}Open a second terminal, run whois / dig -x, then type the owner.${RESET} ${WHITE}q${RESET} = back.\n"
        mapfile -t shuffled < <(printf '%s\n' "${IP_QS[@]}" | shuf)
        for entry in "${shuffled[@]}"; do
          IFS='|' read -r ip kws shown exp <<< "$entry"
          echo -e "\n  ${WHITE}${BOLD}🔍  ${WHITE}Who owns ${WHITE}$ip${WHITE}?${RESET}"
          echo -ne "  ${WHITE}Owner: ${RESET}"
          read -r answer || break
          [[ "${answer,,}" == "q" ]] && break
          given=$(normalize "$answer"); hit=0
          IFS=',' read -ra kwarr <<< "$kws"
          for k in "${kwarr[@]}"; do [[ -n "$given" && "$given" == *"$k"* ]] && hit=1; done
          if (( hit )); then
            record_result 1
            echo -e "  ${INV} ✔ Correct! ${RESET}  ${WHITE}+${GAIN} XP${RESET}  ${WHITE}$shown${RESET}"
            log_line "CORRECT | IP: $ip | $shown"
          else
            record_result 0
            echo -e "  ${WHITE}${BOLD}✘  Wrong.${RESET}  Owner: ${WHITE}${BOLD}$shown${RESET}"
            log_line "WRONG   | IP: $ip | Expected: $shown | Got: $given"
          fi
          echo -e "  ${DIM}$exp${RESET}"
          flush_rankup
          echo -ne "  ${DIM}Press Enter for next, or q to quit: ${RESET}"
          read -r nxt; [[ "$nxt" == "q" ]] && break
        done
        pause_enter ;;
      2)
        echo -ne "\n  ${WHITE}IPv4 to check: ${RESET}"; read -r ip
        ip_lookup "$ip"
        pause_enter ;;
      b|B|q|Q) return ;;
      *) ;;
    esac
  done
}

# ── TIMED BLITZ ───────────────────────────────────────────────
mode_blitz() {
  local entry q a exp answer rem end right=0 seen=0 nxt
  local -a pool
  clear
  section_header "TIMED BLITZ — 60 SECONDS"
  echo -e "  ${WHITE}Mixed questions from every category. Answer fast. Type ${WHITE}q${WHITE} to bail.${RESET}"
  echo -e "  ${DIM}Wrong answers show the right one and cost you time. No explanations.${RESET}"
  echo -ne "\n  ${WHITE}Press Enter to start...${RESET}"; read -r
  mapfile -t pool < <(printf '%s\n' "${ALL_QS[@]}" | shuf)
  end=$(( SECONDS + 60 ))
  for entry in "${pool[@]}"; do
    rem=$(( end - SECONDS )); (( rem <= 0 )) && break
    IFS='|' read -r q a exp <<< "$entry"
    echo -e "\n  ${WHITE}${BOLD}⏱  ${rem}s${RESET}  ${DIM}[${right}/${seen}]${RESET}  ${WHITE}$q${RESET}"
    echo -ne "  ${WHITE}> ${RESET}"
    if ! read -r -t "$rem" answer; then echo -e "\n  ${WHITE}${BOLD}TIME!${RESET}"; break; fi
    [[ "${answer,,}" == "q" ]] && break
    ((seen++))
    if [[ "$(normalize "$answer")" == "$(normalize "$a")" ]]; then
      ((right++)); record_result 1
      echo -e "  ${WHITE}✔  +${GAIN}${RESET}"
      log_line "BLITZ+  | Q: $q"
    else
      record_result 0
      echo -e "  ${WHITE}✘${RESET}  ${WHITE}$a${RESET}"
      log_line "BLITZ-  | Q: $q | Expected: $a"
    fi
  done
  echo -e "\n  ${RED}━━ ${WHITE}BLITZ RESULT ${RED}━━${RESET}"
  echo -e "  ${WHITE}Correct:${RESET} ${WHITE}${BOLD}$right${RESET}/${WHITE}$seen${RESET}"
  if (( right > BEST_BLITZ )); then
    BEST_BLITZ=$right; save_stats
    echo -e "  ${INV} ★ NEW PERSONAL BEST ★ ${RESET}"
  else
    echo -e "  ${GRAY}Personal best: $BEST_BLITZ${RESET}"
  fi
  summary
}

# ── DAILY CHALLENGE ───────────────────────────────────────────
mode_daily() {
  local today entry q a exp rc before_score answered=0 correct nxt
  local -a picks
  today=$(date +%F)
  clear
  section_header "DAILY CHALLENGE — $today"
  echo -e "  ${WHITE}5 questions. Same set for everyone today. Finish all 5 for bonus XP once per day.${RESET}"
  if [[ "$LAST_DAILY" == "$today" ]]; then
    echo -e "  ${GRAY}You already cleared today's bonus. You can replay for practice.${RESET}"
  fi
  mapfile -t picks < <(printf '%s\n' "${ALL_QS[@]}" | shuf -n 5 --random-source=<(yes "$today"))
  before_score=$SCORE
  for entry in "${picks[@]}"; do
    IFS='|' read -r q a exp <<< "$entry"
    ask_question "$q" "$a" "$exp"; rc=$?
    (( rc == 2 )) && break
    ((answered++))
    echo -ne "  ${DIM}Press Enter to continue...${RESET}"; read -r nxt
  done
  correct=$(( SCORE - before_score ))
  echo -e "\n  ${RED}━━ ${WHITE}DAILY RESULT ${RED}━━${RESET}  ${WHITE}${BOLD}$correct${RESET}${WHITE}/5 correct${RESET}"
  if (( answered == 5 )) && [[ "$LAST_DAILY" != "$today" ]]; then
    add_xp 30; LAST_DAILY="$today"; save_stats
    echo -e "  ${WHITE}${BOLD}+30 XP daily bonus${RESET}"
    (( correct == 5 )) && echo -e "  ${INV} ★ PERFECT RUN ★ ${RESET}"
  fi
  summary
}

# ── LIVE LAB ──────────────────────────────────────────────────
# Everything binds to 127.0.0.1 only. Servers are python3 one-liners, killed on exit.
PY_TCP='
import socket, sys
p = int(sys.argv[1]); f = sys.argv[2]
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", p)); s.listen(5)
while True:
    c, _ = s.accept()
    try: c.sendall(("== MK-NETDRILL ROGUE SERVICE ==\n" + f + "\n").encode())
    except Exception: pass
    c.close()
'
PY_UDP='
import socket, sys, time
p = int(sys.argv[1]); f = sys.argv[2]
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
while True:
    try: s.sendto(("beacon:" + f).encode(), ("127.0.0.1", p))
    except Exception: pass
    time.sleep(1)
'
PY_HTTP='
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
p = int(sys.argv[1]); f = sys.argv[2]
class H(BaseHTTPRequestHandler):
    def _send(self):
        self.send_response(200); self.send_header("X-Flag", f)
        self.send_header("Content-Type", "text/plain"); self.end_headers()
    def do_GET(self):
        self._send(); self.wfile.write(b"nothing to see here\n")
    def do_HEAD(self):
        self._send()
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", p), H).serve_forever()
'
LAB_PIDS=()
cleanup_labs() { local p; for p in "${LAB_PIDS[@]}"; do kill "$p" 2>/dev/null; done; LAB_PIDS=(); }

port_free() { ! ss -tuln 2>/dev/null | grep -qE "[:.]$1([^0-9]|$)"; }
rand_port() {
  local lo=$1 hi=$2 p
  while :; do p=$(( lo + RANDOM % (hi - lo + 1) )); port_free "$p" && { echo "$p"; return; }; done
}

lab_start() {   # lab_start <tcp|udp|http> <port> <flag>
  case "$1" in
    tcp)  python3 -c "$PY_TCP"  "$2" "$3" >/dev/null 2>&1 & ;;
    udp)  python3 -c "$PY_UDP"  "$2" "$3" >/dev/null 2>&1 & ;;
    http) python3 -c "$PY_HTTP" "$2" "$3" >/dev/null 2>&1 & ;;
  esac
  local pid=$!
  LAB_PIDS+=("$pid"); disown "$pid" 2>/dev/null
  sleep 0.5
  kill -0 "$pid" 2>/dev/null
}

lab_info() {
  case "$1" in
    1) LAB_TITLE="GHOST LISTENER"; LAB_KIND=tcp; LAB_LO=40000; LAB_HI=40099
       LAB_MISSION="A rogue service is listening on 127.0.0.1 somewhere in this port range. Find it, connect to it, read the flag."
       LAB_H1="Find listeners:  ss -tlnp   (look for python3)   or   nmap -p 40000-40099 127.0.0.1"
       LAB_H2="Connect to the port:  nc 127.0.0.1 <port>"
       LAB_H3="No nc? Pure bash:  exec 3<>/dev/tcp/127.0.0.1/<port>; cat <&3" ;;
    2) LAB_TITLE="PACKET CATCHER"; LAB_KIND=udp; LAB_LO=41000; LAB_HI=41099
       LAB_MISSION="Something on this box beacons a UDP packet to loopback every second. Capture the traffic and read the payload."
       LAB_H1="It's loopback traffic, so sniff the 'lo' interface, not eth0/wlan0."
       LAB_H2="sudo tcpdump -i lo -nn udp portrange 41000-41099"
       LAB_H3="Add -A to print the payload as ASCII:  sudo tcpdump -i lo -nn -A udp portrange 41000-41099" ;;
    3) LAB_TITLE="BANNER GRAB"; LAB_KIND=http; LAB_LO=42000; LAB_HI=42099
       LAB_MISSION="A hidden web service is running in this port range. The flag isn't in the page body, it's in a response header."
       LAB_H1="Find it first:  ss -tlnp   or   nmap -sV -p 42000-42099 127.0.0.1"
       LAB_H2="Show headers:  curl -i http://127.0.0.1:<port>"
       LAB_H3="Headers only:  curl -I http://127.0.0.1:<port>   (look for X-Flag)" ;;
  esac
}

lab_play() {
  local port flag core ans a hints=0 xp
  lab_info "$1"
  port=$(rand_port "$LAB_LO" "$LAB_HI")
  flag="FLAG{$(printf '%04x%04x' "$RANDOM" "$RANDOM")}"
  core=${flag#FLAG\{}; core=${core%\}}
  if ! lab_start "$LAB_KIND" "$port" "$flag"; then
    echo -e "  ${WHITE}Could not start the lab service (is python3 working?).${RESET}"; pause_enter; return
  fi
  clear
  section_header "LIVE LAB — $LAB_TITLE"
  echo -e "  ${GRAY}Runs on 127.0.0.1 only. Open a second terminal and hunt. The service dies when you leave.${RESET}\n"
  echo -e "  ${WHITE}${BOLD}MISSION${RESET}  ${WHITE}$LAB_MISSION${RESET}"
  echo -e "  ${WHITE}${BOLD}RANGE  ${RESET}  ${WHITE}$LAB_LO - $LAB_HI${RESET}"
  echo -e "  ${WHITE}${BOLD}GOAL   ${RESET}  ${WHITE}Paste the flag (looks like FLAG{xxxxxxxx}).${RESET}"
  echo -e "\n  ${GRAY}Commands:${RESET} ${WHITE}hint${RESET} ${GRAY}(costs XP)${RESET} · ${WHITE}skip${RESET} ${GRAY}(reveals the port)${RESET} · ${WHITE}q${RESET} ${GRAY}(back)${RESET}"
  while true; do
    echo -ne "\n  ${WHITE}Flag> ${RESET}"; read -r ans || break
    a=$(normalize "$ans")
    case "$a" in
      hint)
        ((hints++))
        case $hints in
          1) echo -e "  ${WHITE}Hint 1:${RESET} $LAB_H1" ;;
          2) echo -e "  ${WHITE}Hint 2:${RESET} $LAB_H2" ;;
          *) echo -e "  ${WHITE}Hint 3:${RESET} $LAB_H3" ;;
        esac ;;
      skip) echo -e "  ${WHITE}Port was ${BOLD}$port${RESET}${WHITE}. Flag: ${WHITE}$flag${RESET}"; break ;;
      q) break ;;
      "") ;;
      *)
        if [[ "$a" == "${flag,,}" || "$a" == "${core,,}" ]]; then
          xp=$(( hints == 0 ? 40 : 25 )); add_xp "$xp"; ((LABS_SOLVED++)); save_stats
          log_line "LAB     | $LAB_TITLE solved | hints: $hints"
          echo -e "  ${INV} ✔ FLAG CAPTURED! ${RESET}  ${WHITE}+${xp} XP${RESET}"
          flush_rankup
          break
        else
          echo -e "  ${WHITE}✘  Not it. Keep hunting.${RESET}"
        fi ;;
    esac
  done
  cleanup_labs
  pause_enter
}

mode_lab() {
  local choice
  if ! command -v python3 >/dev/null; then
    clear; section_header "LIVE LAB"
    echo -e "  ${WHITE}Live Lab needs python3 (sudo apt install python3).${RESET}"; pause_enter; return
  fi
  while true; do
    clear
    section_header "LIVE LAB — HUNT A REAL FLAG ON YOUR OWN MACHINE"
    echo -e "  ${WHITE}The script starts a small service on ${WHITE}127.0.0.1${WHITE} on a random port.${RESET}"
    echo -e "  ${WHITE}You find it with real tools and bring back the flag. Fresh flag every run.${RESET}\n"
    echo -e "  ${RED}[${WHITE}1${RED}]${RESET} ${WHITE}Ghost Listener${RESET}  ${GRAY}(find the open port, connect, read the flag)${RESET}"
    echo -e "  ${RED}[${WHITE}2${RED}]${RESET} ${WHITE}Packet Catcher${RESET}  ${GRAY}(sniff the UDP beacon on loopback)${RESET}"
    echo -e "  ${RED}[${WHITE}3${RED}]${RESET} ${WHITE}Banner Grab${RESET}     ${GRAY}(flag hides in an HTTP response header)${RESET}"
    echo -e "  ${RED}[${WHITE}b${RED}]${RESET} ${WHITE}Back${RESET}\n"
    echo -e "  ${GRAY}Labs solved so far: $LABS_SOLVED${RESET}"
    echo -ne "\n  ${BOLD}Select lab: ${RESET}"; read -r choice
    case "$choice" in
      1|2|3) lab_play "$choice" ;;
      b|B|q|Q) return ;;
    esac
  done
}

# ── RANK / STATS / LOG ────────────────────────────────────────
mode_score() {
  local idx pct line
  idx=$(rank_index)
  clear
  section_header "RANK, STATS & SESSION LOG"
  echo -e "\n  ${WHITE}Rank        :${RESET} ${INV} ${RANK_NAME[idx]} ${RESET}"
  echo -e "  ${WHITE}Progress    :${RESET} ${WHITE}$(rank_bar)${RESET}"
  echo -e "  ${WHITE}Day streak  :${RESET} ${WHITE}${BOLD}$DAY_STREAK${RESET}    ${WHITE}Best answer streak:${RESET} ${WHITE}${BOLD}$BEST_STREAK${RESET}"
  echo -e "  ${WHITE}Labs solved :${RESET} ${WHITE}${BOLD}$LABS_SOLVED${RESET}    ${WHITE}Best blitz:${RESET} ${WHITE}${BOLD}$BEST_BLITZ${RESET}"
  echo ""
  echo -e "  ${WHITE}This session:${RESET} ${WHITE}${BOLD}$SCORE${RESET}/${WHITE}$TOTAL${RESET}"
  if (( ALL_TOTAL > 0 )); then
    pct=$(( ALL_CORRECT * 100 / ALL_TOTAL ))
    echo -e "  ${WHITE}All time     :${RESET} ${WHITE}${BOLD}$ALL_CORRECT${RESET}/${WHITE}$ALL_TOTAL${RESET}  ${GRAY}(${pct}% accuracy)${RESET}"
  fi
  echo ""
  if [[ -f "$SESSION_LOG" ]]; then
    echo -e "  ${RED}── ${WHITE}Recent log entries (last 10) ${RED}─────────────────────────────────${RESET}"
    tail -10 "$SESSION_LOG" | while IFS= read -r line; do echo -e "  ${DIM}$line${RESET}"; done
  fi
  echo -ne "\n  ${DIM}Press Enter to return, or type ${WHITE}reset${DIM} to wipe your stats: ${RESET}"
  read -r line
  if [[ "$line" == "reset" ]]; then
    echo -ne "  ${WHITE}This deletes XP, rank and streaks. Type YES to confirm: ${RESET}"
    read -r line
    if [[ "$line" == "YES" ]]; then
      XP=0; ALL_TOTAL=0; ALL_CORRECT=0; BEST_STREAK=0; DAY_STREAK=0
      BEST_BLITZ=0; LABS_SOLVED=0; LAST_DAY=""; LAST_DAILY=""
      save_stats; echo -e "  ${WHITE}Stats reset.${RESET}"; sleep 1
    fi
  fi
}

# ── MAIN LOOP ─────────────────────────────────────────────────
trap cleanup_labs EXIT
trap 'cleanup_labs; echo; exit 130' INT TERM

main() {
  local choice idx
  load_stats
  while true; do
    show_cheatsheet
    echo -ne "  ${BOLD}Select option: ${RESET}"
    read -r choice || exit 0
    case "$choice" in
      1)  mode_flash ;;
      2)  mode_reverse ;;
      3)  mode_commands ;;
      4)  mode_subnet ;;
      5)  mode_firewall ;;
      6)  mode_traffic ;;
      7)  mode_opsec ;;
      8)  mode_proxy ;;
      9)  mode_explore ;;
      10) mode_lab ;;
      11) mode_whois ;;
      12) mode_blitz ;;
      13) mode_daily ;;
      14) mode_score ;;
      15) continue ;;
      q|Q)
        idx=$(rank_index)
        echo -e "\n  ${WHITE}Final score:${RESET} ${WHITE}${BOLD}$SCORE${RESET}/${WHITE}$TOTAL${RESET}   ${RED}│${RESET}   ${WHITE}Rank:${RESET} ${INV} ${RANK_NAME[idx]} ${RESET}"
        echo -e "  ${WHITE}Keep drilling!${RESET} 📡\n"
        exit 0 ;;
      *)  echo -e "  ${WHITE}Invalid option.${RESET}"; sleep 1 ;;
    esac
  done
}

main
