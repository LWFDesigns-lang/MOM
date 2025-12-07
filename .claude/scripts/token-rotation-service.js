#!/usr/bin/env node
const AuditLogger = require("./audit-logger");

class TokenRotationService {
  constructor() {
    this.logger = new AuditLogger();
  }

  async start() {
    console.log("Token rotation disabled for local/home setup. Use .env and restart services if creds change.");
    this.logger.logSecurityEvent("rotation_disabled", { severity: "info", mode: "local_env" });
  }
}

if (require.main === module) {
  const service = new TokenRotationService();
  service.start();
}

module.exports = TokenRotationService;
