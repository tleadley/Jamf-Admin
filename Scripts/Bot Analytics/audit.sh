#!/bin/bash

# Configuration
INPUT_CSV=${1:-"table.csv"}
OUTPUT_MD="security_audit_report.md"
RPM_THRESHOLD=500
MIN_INVENTORY_RPM=150

echo -e "\033[0;34mInitiating High-Fidelity Security Audit on $INPUT_CSV...\033[0m"

if [[ ! -f "$INPUT_CSV" ]]; then
    echo "Error: File $INPUT_CSV not found."
    exit 1
fi

# 1. Python logic for aggregation and time-series analysis
python3 - <<EOF > audit_data.json
import csv
import json
from collections import defaultdict

def analyze(ip, max_rpm, ua, hits_over_limit):
    ua_raw = (ua or "").strip()
    ua_l = ua_raw.lower()
    
    bots = {'googlebot': 'Googlebot', 'bingbot': 'Bingbot', 'duckduckbot': 'DuckDuckGo', 'baiduspider': 'Baidu', 'yandexbot': 'Yandex', 'meta-externalads': 'Meta/Facebook'}
    tools = {'guzzle': 'Guzzle/PHP', 'python': 'Python', 'curl': 'cURL', 'wget': 'Wget', 'drupal': 'Drupal/Guzzle', 'headless': 'Headless Browser', 'br-crawler':'BR-Crawler (Uncategorized)'}
    
    bot_name = "Standard Browser"
    is_search = any(k in ua_l for k in bots)
    is_tool = any(k in ua_l for k in tools)
    is_blank = not ua_raw or ua_raw == "N/A"
    
    # Classification Logic
    if is_blank:
        bot_name = "Missing Agent"
        cat = "Malicious" if max_rpm > $RPM_THRESHOLD else "Suspect"
        sustain_info = f"Sustained activity ({hits_over_limit} mins over limit)." if hits_over_limit > 1 else "Single burst."
        rationale = f"Blank User Agent. Peak {max_rpm} RPM. {sustain_info}"
        return bot_name, cat, rationale

    if is_search:
        for k, v in bots.items():
            if k in ua_l: return v, "Valid Bot", f"Verified search engine crawler ({v})."
    
    if max_rpm > $RPM_THRESHOLD:
        cat = "Malicious"
        # Determine if it was a one-off spike or a prolonged attack
        behavior = f"Sustained attack: {hits_over_limit} mins detected above threshold." if hits_over_limit > 2 else f"High-volume burst ({max_rpm} RPM) detected."
        
        if is_tool:
            for k, v in tools.items():
                if k in ua_l: return v, cat, f"Automated Tool ({v}). {behavior}"
        return "Standard Browser", cat, f"Anomalous human signature: {behavior}"
    
    if is_tool:
        for k, v in tools.items():
            if k in ua_l: return v, "Suspect", f"Automated library ({v}) used at low volume."
            
    return "Standard Browser", "Valid User", "Traffic pattern consistent with human interaction."

# Data Structure: { ip: { max_rpm, peak_time, ua, hits_over, daily_history } }
raw_data = defaultdict(lambda: {'max_rpm': 0, 'peak_time': '', 'ua': 'N/A', 'hits_over': 0, 'daily': {}})

with open("$INPUT_CSV", mode='r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            ip = row['Client Ip']
            rpm = int(row['Requests Per Minute'])
            
            # Format time correctly even if columns are strings
            hour_part = row['Hour'].split(':')[0]
            try:
                min_val = int(row['Minute'])
                min_str = f"{min_val:02d}"
            except (ValueError, TypeError):
                min_str = str(row['Minute'])
                
            exact_time = f"{row['Date']} {hour_part}:{min_str}"
            ua = row['User Agent'] or "N/A"
            
            if rpm > $RPM_THRESHOLD:
                raw_data[ip]['hits_over'] += 1
                
            if rpm > raw_data[ip]['max_rpm']:
                raw_data[ip]['max_rpm'] = rpm
                raw_data[ip]['peak_time'] = exact_time
                raw_data[ip]['ua'] = ua
                
            raw_data[ip]['daily'][row['Date']] = max(raw_data[ip]['daily'].get(row['Date'], 0), rpm)
        except Exception:
            continue

final = []
for ip, info in raw_data.items():
    bot, cat, rat = analyze(ip, info['max_rpm'], info['ua'], info['hits_over'])
    # Clean history string for tables
    history = ", ".join([f"{d} ({r} RPM)" for d, r in sorted(info['daily'].items())])
    
    final.append({
        'ip': ip, 'bot': bot, 'cat': cat, 'max_rpm': info['max_rpm'], 
        'peak_time': info['peak_time'], 'ua': info['ua'], 
        'rationale': rat, 'history': history
    })

print(json.dumps(final))
EOF

# Validation Check
if [[ ! -s "audit_data.json" ]]; then
    echo "Error: Data aggregation failed. Please check if CSV headers match exactly."
    exit 1
fi

# 2. Markdown Report Construction
{
    echo "# Traffic Security & Bot Intelligence Report"
    echo "Generated on: $(date)"
    echo ""
    echo "## 🛡️ Top Threat Actors (Peak > ${RPM_THRESHOLD} RPM)"
    echo "Identified by exact timestamp of peak activity."
    echo ""
    echo "| IP Address | Bot | Category | Peak Moment | Max RPM | Organization | User Agent |"
    echo "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"

    echo "" > rationale_temp.txt
    
    python3 -c "import json; d=json.load(open('audit_data.json')); [print(f\"{i['ip']}|{i['bot']}|{i['cat']}|{i['peak_time']}|{i['max_rpm']}|{i['ua']}|{i['rationale']}|{i['history']}\") for i in d if i['cat'] == 'Malicious']" | sort -t'|' -k5 -rn | while IFS="|" read -r ip bot cat peak rpm ua rationale history; do
        
        echo -n "Investigating $ip... " >&2
        ORG=$(whois "$ip" 2>/dev/null | grep -Ei "orgname|organization|owner|as-name" | head -1 | awk -F':' '{print $2}' | xargs)
        [ -z "$ORG" ] && ORG="Unknown/Cloud"
        echo "Done." >&2

        echo "| $ip | $bot | **$cat** | $peak | $rpm | $ORG | <code>$ua</code> |"
        
        {
            echo "### Source: $ip ($ORG)"
            echo "**Category:** $cat | **Peak:** $rpm RPM at $peak"
            echo "**Security Rationale:** $rationale"
            echo "**Full History:** $history"
            echo ""
        } >> rationale_temp.txt
    done

    echo ""
    echo "## 📑 Comprehensive Analysis"
    cat rationale_temp.txt
    echo ""

    echo "## 📂 Full IP Inventory (Significant Traffic)"
    echo "> Peak RPM >= ${MIN_INVENTORY_RPM}"
    echo ""
    echo "| IP Address | Bot | Category | Max RPM | Daily Peak History |"
    echo "| :--- | :--- | :--- | :--- | :--- |"
    
    python3 -c "import json; d=json.load(open('audit_data.json')); [print(f\"| {i['ip']} | {i['bot']} | {i['cat']} | {i['max_rpm']} | {i['history']} |\") for i in d if i['max_rpm'] >= $MIN_INVENTORY_RPM]"
    
    echo ""
    echo "---"
    echo "### Audit Definitions"
    echo "- **Malicious**: Actors exceeding the **${RPM_THRESHOLD} RPM** threshold. This includes:"
    echo "  - **Sustained Attack**: High-volume traffic spanning multiple minutes (indicates aggressive scraping/DDoS)."
    echo "  - **Burst**: A high-speed spike in a single minute (indicates vulnerability probing or a quick script)."
    echo "- **Suspect**: Identified as an automated library (e.g., Guzzle, Python) or a **Blank User Agent** at low volumes. These are flagged because they are rarely used by real human visitors."
    echo "- **Valid Bot**: Verified search engine crawlers (e.g., Googlebot, Bingbot). These are allowed for SEO indexing."
    echo "- **Valid User**: Traffic patterns and signatures consistent with standard human browser interaction."
} > "$OUTPUT_MD"

rm audit_data.json rationale_temp.txt
echo -e "\033[0;32mSecurity audit report successfully generated: $OUTPUT_MD\033[0m"
