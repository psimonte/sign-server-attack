#!/bin/bash
PORT=3000
CLIENT=192.168.0.102
DATA=received_data.bin
SIG=received_data.sig
LOGFILE=/home/pi/sign-server.log

log(){
    local msg=$1
    echo ["$(date "+%Y.%m.%d %H:%M:%S")"] "$msg" | tee -a $LOGFILE
}

log "Signatur Server gestartet"

while true; do
    # Empfange Daten
    nc -l -p "$PORT" > "$DATA"
    log "Daten empfangen. Berechne Signatur ..."

    [ -s sign-server.pem ] || { log "Private Key nicht gefunden. Server wird beendet" ; exit 1 ; }

    # Berechne Signatur von Hash
    openssl dgst -sha256 -sign sign-server.pem -out "$SIG" "$DATA" 

    # Sende Signatur
    cat $SIG  | nc -N $CLIENT $((PORT + 1))
    log "Signatur versendet."
done