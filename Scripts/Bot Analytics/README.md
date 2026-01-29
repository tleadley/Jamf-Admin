# 🛡️ Traffic Security & Bot Intelligence Audit Process

## 1. Executive Summary

This document defines the automated security audit process used to identify, categorize, and report on high-frequency traffic patterns. By combining **New Relic Telemetry** with **Behavioral Python Logic**, we distinguish between verified search engine crawlers, automated scraping tools, and potential DDoS/Malicious actors.

---

## 2. Data Acquisition (New Relic)

The audit begins with raw log data. Execute the following NRQL query in the **New Relic Query Builder** to capture minute-by-minute request volumes.

### NRQL Query

`SQL`

`FROM Log SELECT count(*) as 'Requests Per Minute' WHERE fastly_datacenter IS NOT NULL FACET client_ip AS 'Client IP', request_user_agent AS 'User Agent', dateOf(timestamp) AS 'Date', hourOf(timestamp) AS 'Hour', minuteOf(timestamp) AS 'Minute' SINCE 1 week ago LIMIT MAX`

**Export Steps:**

1. Run the query.
    
2. Select **Export as CSV**.
    
3. Save the file in the same directory as the audit script.
    

---

## 3. Analysis Logic & Classification

The script evaluates traffic based on a **Volume vs. Identity** matrix.

### Classification Definitions

|   |   |   |
|---|---|---|
|**Category**|**Definition**|**Thresholds**|
|**🔴 Malicious**|High-volume traffic likely intended to scrape data or overwhelm services.|$> 500$ RPM|
|**🟡 Suspect**|Automated libraries (Python/Guzzle) or missing User Agents at lower volumes.|$150 - 500$ RPM|
|**🟢 Valid Bot**|Verified SEO/Search crawlers (Google, Bing, Yandex).|Any volume|
|**⚪ Valid User**|Standard browser signatures with human-like traffic patterns.|$< 500$ RPM|

---

## 4. The Audit Script

The script is a Bash/Python hybrid. It performs data aggregation, time-series analysis (to find "Peak Moments"), and live **WHOIS** lookups to identify the owner of the attacking IP.

### Execution

`Bash`

`# Usage: ./audit.sh [input_file.csv] ./audit.sh table.csv`

### Key Performance Indicators (KPIs) calculated:

- **Peak Moment:** The exact minute the IP hit its highest volume.
    
- **Sustained vs. Burst:** Differentiates between a 1-minute spike and a multi-minute attack.
    
- **Organization Attribution:** Identifies if the IP belongs to a known cloud provider (AWS, DigitalOcean) or a private ISP.
    

---

## 5. Publication Workflow (Crucial for Confluence)

Confluence does not always parse raw `.md` files correctly if pasted as code. To maintain the tables and formatting, follow this **"Obsidian Bridge"** method:

### Steps to Upload:

1. **Generate the Report:** Run the script to produce `security_audit_report.md`.
    
2. **Open in Markdown Editor:** Open the file in **Obsidian**, **VS Code**, or **Typora**.
    
3. **Enter Preview Mode:** Ensure you are looking at the rendered version (where the tables look like tables, not code).
    
4. **Copy-Paste:** Highlight the rendered content, copy it, and paste it directly into a blank Confluence page.
    
5. **Final Polish:** Confluence will automatically convert the Markdown formatting into its native "Macro" components.
    

---

## 6. Maintenance & Updates

To update the audit parameters (e.g., lowering the threshold to 300 RPM), modify the variables in the script header:

- `RPM_THRESHOLD`: The "Malicious" trigger point.
    
- `MIN_INVENTORY_RPM`: The cutoff for the "Significant Traffic" list.
