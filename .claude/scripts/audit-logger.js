#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

class AuditLogger {
  constructor(logDir = path.join(__dirname, "..", "data", "logs")) {
    this.logDir = logDir;
    this.logFile = path.join(this.logDir, "mcp_calls.jsonl");
    if (!fs.existsSync(this.logDir)) fs.mkdirSync(this.logDir, { recursive: true });
  }

  logMCPCall(server, tool, status, durationMs, error = null) {
    const entry = {
      timestamp: new Date().toISOString(),
      server,
      tool,
      status,
      duration_ms: durationMs,
      error: error ? String(error) : undefined
    };
    this.append(entry);
  }

  logSecurityEvent(eventType, details = {}) {
    const entry = {
      timestamp: new Date().toISOString(),
      event_type: eventType,
      severity: details.severity || "info",
      details
    };
    this.append(entry);
  }

  logCredentialRotation(service, ttlSeconds) {
    const entry = {
      timestamp: new Date().toISOString(),
      action: "credential_rotation",
      service,
      ttl_seconds: ttlSeconds
    };
    this.append(entry);
  }

  generateReport(startDate, endDate) {
    const logs = this.readAll();
    const windowed = logs.filter((l) => {
      const ts = new Date(l.timestamp || 0);
      return ts >= startDate && ts <= endDate;
    });

    return {
      total_calls: windowed.length,
      successes: windowed.filter((l) => l.status === "success").length,
      failures: windowed.filter((l) => l.status === "failure").length,
      by_server: this.groupByServer(windowed),
      security_events: windowed.filter((l) => l.event_type),
      avg_duration_ms: this.avgDuration(windowed)
    };
  }

  readAll() {
    if (!fs.existsSync(this.logFile)) return [];
    return fs
      .readFileSync(this.logFile, "utf8")
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        try {
          return JSON.parse(line);
        } catch {
          return null;
        }
      })
      .filter(Boolean);
  }

  append(entry) {
    fs.appendFileSync(this.logFile, JSON.stringify(entry) + "\n");
  }

  avgDuration(logs) {
    const durations = logs.filter((l) => l.duration_ms).map((l) => l.duration_ms);
    if (!durations.length) return 0;
    const total = durations.reduce((a, b) => a + b, 0);
    return Math.round(total / durations.length);
  }

  groupByServer(logs) {
    return logs.reduce((acc, log) => {
      if (!log.server) return acc;
      acc[log.server] = (acc[log.server] || 0) + 1;
      return acc;
    }, {});
  }
}

module.exports = AuditLogger;

if (require.main === module) {
  const logger = new AuditLogger();
  const action = process.argv[2];
  if (action === "report") {
    const report = logger.generateReport(new Date(Date.now() - 24 * 60 * 60 * 1000), new Date());
    console.log(JSON.stringify(report, null, 2));
  } else {
    console.log("Audit logger ready. Use 'report' to summarize last 24h.");
  }
}
