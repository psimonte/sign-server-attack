#!/bin/bash
FILE=$1
SERVER=192.168.0.103
PORT=3000

# Datei senden
cat "$FILE" | nc -N "$SERVER" "$PORT"
echo "Daten gesendet"

# Signatur empfangen
SIG=$(mktemp)
nc -l $((PORT + 1)) > $SIG

# Signatur prüfen
openssl dgst -sha256 -verify sign-server.pub -signature "$SIG" "$FILE"
