#!/usr/bin/env bash
# run_requests.sh
# 1) Asegura tcpdump y curl en ubuntu-a y ubuntu-b
# 2) Inicia tcpdump en A y B
# 3) Ejecuta 10 requests A->B y 10 B->A
# 4) Detiene tcpdump y copia los PCAPs al host

set -euo pipefail

# ---- Config ----
A_CONTAINER="ubuntu-a"
B_CONTAINER="ubuntu-b"
A_ADDR="172.100.0.10:8080"
B_ADDR="172.200.0.10:8080"
ITERATIONS=10
SLEEP_BETWEEN=0.2

TS="$(date +%Y%m%d-%H%M%S)"
HOST_OUT_DIR="./captures"
LOGDIR="./logs/requests"
mkdir -p "${HOST_OUT_DIR}" "${LOGDIR}"

# Capturas dentro de contenedor
A_PCAP_IN="/tmp/ovpn_lab_A_${TS}.pcap"
B_PCAP_IN="/tmp/ovpn_lab_B_${TS}.pcap"
A_PID_IN="/var/run/tcpdump_A.pid"
B_PID_IN="/var/run/tcpdump_B.pid"

# Destino en host
A_PCAP_OUT="${HOST_OUT_DIR}/ovpn_lab_A_${TS}.pcap"
B_PCAP_OUT="${HOST_OUT_DIR}/ovpn_lab_B_${TS}.pcap"
A_TO_B_LOG="${LOGDIR}/a_to_b_${TS}.log"
B_TO_A_LOG="${LOGDIR}/b_to_a_${TS}.log"

# ---- Helpers ----
ensure_tools() {
  local c="$1"
  docker exec "$c" bash -lc '
    set -e
    export DEBIAN_FRONTEND=noninteractive
    need_update=0
    ensure_cmd() {
      local bin="$1" pkg="$2"
      if ! command -v "$bin" >/dev/null 2>&1; then
        if [ "$need_update" -eq 0 ]; then
          apt-get update -y >/dev/null 2>&1 || true
          need_update=1
        fi
        apt-get install -y '"'"'$pkg'"'"' >/dev/null 2>&1 || true
      fi
    }
    ensure_cmd tcpdump tcpdump
    ensure_cmd curl curl
  '
}

start_tcpdump() {
  local c="$1" pcap="$2" pidfile="$3"
  docker exec -d "$c" bash -lc "mkdir -p \$(dirname '${pidfile}'); nohup tcpdump -ni any '(udp port 1194) or (tcp port 8080) or icmp' -w '${pcap}' >/dev/null 2>&1 & echo \$! > '${pidfile}'"
}

stop_tcpdump() {
  local c="$1" pidfile="$2"
  docker exec "$c" bash -lc "if [ -f '${pidfile}' ]; then kill -INT \$(cat '${pidfile}') 2>/dev/null || true; fi"
}

copy_pcap() {
  local c="$1" in="$2" out="$3"
  if docker exec "$c" bash -lc "[ -s '${in}' ]"; then
    docker cp "${c}:${in}" "${out}"
    echo "Saved: ${out}"
  else
    echo "WARN: ${c} pcap not found or empty at ${in}"
  fi
}

do_requests() {
  local from="$1" url="$2" outfile="$3"
  echo "# Run started: $(date --iso-8601=seconds) from ${from} -> ${url}" >> "${outfile}"
  for i in $(seq 1 "${ITERATIONS}"); do
    local TIMESTAMP; TIMESTAMP="$(date --iso-8601=seconds)"
    # curl imprime cuerpo y al final '|||META|||<status>|<tiempo>'
    local RESP_RAW
    RESP_RAW="$(docker exec "${from}" bash -lc "curl -sS -m 10 -o - -w '|||META|||%{http_code}|%{time_total}' http://${url}" 2>&1 || true)"
    if [[ "${RESP_RAW}" != *"|||META|||"* ]]; then
      printf '%s | #%02d | ERROR | msg="%s"\n' "${TIMESTAMP}" "${i}" "${RESP_RAW}" >> "${outfile}"
    else
      local BODY META STATUS TIME
      BODY="${RESP_RAW%%|||META|||*}"
      META="${RESP_RAW#*|||META|||}"
      STATUS="${META%%|*}"
      TIME="${META##*|}"
      BODY="$(printf '%s' "${BODY}" | awk '{gsub(/\r/,""); printf "%s\\n", $0}' ORS="")"
      printf '%s | #%02d | status=%s | time=%ss | body="%s"\n' "${TIMESTAMP}" "${i}" "${STATUS}" "${TIME}" "${BODY}" >> "${outfile}"
    fi
    sleep "${SLEEP_BETWEEN}"
  done
  echo "# Run finished: $(date --iso-8601=seconds)" >> "${outfile}"
  echo "" >> "${outfile}"
}

# Asegura herramientas
ensure_tools "${A_CONTAINER}"
ensure_tools "${B_CONTAINER}"

# Inicia tcpdump (primero que todo)
start_tcpdump "${A_CONTAINER}" "${A_PCAP_IN}" "${A_PID_IN}"
start_tcpdump "${B_CONTAINER}" "${B_PCAP_IN}" "${B_PID_IN}"
echo "tcpdump started in ${A_CONTAINER} -> ${A_PCAP_IN}"
echo "tcpdump started in ${B_CONTAINER} -> ${B_PCAP_IN}"

# Trap para detener/copy incluso con Ctrl+C
cleanup() {
  echo "Stopping tcpdump and copying pcaps..."
  stop_tcpdump "${A_CONTAINER}" "${A_PID_IN}"
  stop_tcpdump "${B_CONTAINER}" "${B_PID_IN}"
  sleep 1
  copy_pcap "${A_CONTAINER}" "${A_PCAP_IN}" "${A_PCAP_OUT}"
  copy_pcap "${B_CONTAINER}" "${B_PCAP_IN}" "${B_PCAP_OUT}"
  echo "Logs:"
  echo "  A->B: ${A_TO_B_LOG}"
  echo "  B->A: ${B_TO_A_LOG}"
  echo "PCAPs:"
  echo "  A capture: ${A_PCAP_OUT}"
  echo "  B capture: ${B_PCAP_OUT}"
}
trap 'cleanup; exit 0' INT TERM

# Requests A->B y B->A
echo "Running ${ITERATIONS} requests A->B and B->A..."
do_requests "${A_CONTAINER}" "${B_ADDR}" "${A_TO_B_LOG}"
do_requests "${B_CONTAINER}" "${A_ADDR}" "${B_TO_A_LOG}"

# Finaliza, copia pcaps
cleanup
echo "Done."

