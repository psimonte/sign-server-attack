#!/bin/bash
PORT=3000
CLIENT=localhost
DATA=received_data.bin
SIG=received_data.sig

while true; do
    # Empfange Daten
    nc -l -p "$PORT" > "$DATA"
    echo "Daten empfangen"

    # Berechne Signatur von Hash
    openssl dgst -sha256 -sign sign-server.pem -out "$SIG" "$DATA" 

    # Sende Signatur
    cat $SIG  | nc -N $CLIENT $((PORT + 1))
done