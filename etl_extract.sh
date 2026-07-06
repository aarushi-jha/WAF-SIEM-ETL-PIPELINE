#!/bin/bash
# Description: Bypasses WAF paywall by extracting raw threat telemetry from PostgreSQL backend.
# Outputs to flat JSON file for Splunk ingestion.

echo "[+] Starting threat telemetry extraction..."

sudo docker exec -i safeline-pg psql -U safeline-ce -d safeline-ce -t -c "
SELECT row_to_json(t) FROM (
  SELECT b.timestamp, b.src_ip, b.url_path, b.rule_id, d.method, d.payload
  FROM mgt_detect_log_basic b
  JOIN mgt_detect_log_detail d ON b.event_id = d.event_id
) t;" > /tmp/safeline.log

echo "[+] Extraction complete. Logs piped to /tmp/safeline.log"
