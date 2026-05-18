#!/usr/bin/env bash

set -u
set -o pipefail

LOG_DIR="/app/runtime"
SERVER_LOG="${LOG_DIR}/server.log"
CRASH_FILE="${LOG_DIR}/server_crash.json"
STOP_REQUESTED="N"

mkdir -p "${LOG_DIR}"

write_crash_file()
{
    local exit_code="$1"
    local timestamp
    local snippet

    timestamp="$(date -Is)"
    snippet="$(tail -n 80 "${SERVER_LOG}" 2>/dev/null || true)"

    node - "${CRASH_FILE}" "${timestamp}" "${exit_code}" "${snippet}" <<'NODE'
const fs = require('fs');

const [, , crashFile, timestamp, exitCode, snippet] = process.argv;
const payload = {
    timestamp,
    exit_code: Number(exitCode),
    snippet
};

fs.writeFileSync(crashFile, JSON.stringify(payload, null, 2));
NODE
}

handle_stop()
{
    STOP_REQUESTED="Y"
}

trap handle_stop TERM INT

while true; do
    echo "Starting SLIM Node server at $(date -Is)" | tee -a "${SERVER_LOG}"

    node server.js 2>&1 | tee -a "${SERVER_LOG}"
    exit_code="${PIPESTATUS[0]}"

    if [ "${STOP_REQUESTED}" = "Y" ]; then
        echo "SLIM Node server stopped by container signal at $(date -Is)" | tee -a "${SERVER_LOG}"
        exit 0
    fi

    if [ "${exit_code}" -eq 0 ]; then
        echo "SLIM Node server exited cleanly at $(date -Is)" | tee -a "${SERVER_LOG}"
        exit 0
    fi

    echo "SLIM Node server crashed with exit code ${exit_code} at $(date -Is)" | tee -a "${SERVER_LOG}"
    write_crash_file "${exit_code}"
    echo "Restarting SLIM Node server in 3 seconds." | tee -a "${SERVER_LOG}"
    sleep 3
done
