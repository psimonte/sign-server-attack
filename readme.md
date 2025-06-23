# Simulation eines IT-Sicherheitsvorfalls auf einem Sign-Server im Produktionseinsatz

## 1. Einleitung

Im Folgenden wird ein auf einem Raspberry Pi basiertes System eingerichtet, das als Signaturserver in einem Produktionsumfeld eingesetzt wird. Dieses System kann beispielsweise dazu verwendet werden, kryptografische Schlüssel zu signieren, die anschließend in der Elektronikfertigung in Endgeräte programmiert werden.
Im weiteren Verlauf wird eine Fehlkonfiguration des SSH-Dienstes simuliert, die es einem Angreifer ermöglicht, den privaten Schlüssel des Signaturservers zu entwenden. Abschließend wird ein Abbild des Systems erstellt, das als Grundlage für eine forensische Analyse dient.

## 2. Aufsetzten 

Das System basiert auf dem Raspberry Pi Modell 5. Der Hersteller bietet hierfür verschiedene Betriebssystemvarianten an. Für diesen Anwendungsfall wurde die schlanke Variante „Raspberry Pi OS Lite“ in der aktuellsten Version vom 13. Mai 2025 ausgewählt. Der reduzierte Funktionsumfang dieser Version ist für die geplante Simulation vollkommen ausreichend.

Das benötigte Image wird über das offizielle Archiv des Herstellers bereitgestellt (https://downloads.raspberrypi.com/) und enthält einen begleitenden Hash-Wert zur Überprüfung der Integrität.

Im ersten Schritt soll das Image heruntergeladen und anschließend die Integrität mittels des bereitgestellten Hash-Werts überprüft werden.

```shell
# Image per wget Herunterladen
$ wget https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2025-05-13/2025-05-13-raspios-bookworm-armhf-lite.img.xz
# SHA256 Hash-Datei per wget Herunterladen
$ wget https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2025-05-13/2025-05-13-raspios-bookworm-armhf-lite.img.xz.sha256
# Hash Überprüfen
$ cat 2025-05-13-raspios-bookworm-armhf-lite.img.xz.sha256
a73d68b618c3ca40190c1aa04005a4dafcf32bc861c36c0d1fc6ddc48a370b6e  2025-05-13-raspios-bookworm-armhf-lite.img.xz
$ sha256sum 2025-05-13-raspios-bookworm-armhf-lite.img.xz
a73d68b618c3ca40190c1aa04005a4dafcf32bc861c36c0d1fc6ddc48a370b6e  2025-05-13-raspios-bookworm-armhf-lite.img.xz
# Hashes stimmen überein -> Integrität sichergestellt
```

Anschließend wird das heruntergeladene Image entpackt und auf eine microSD-Karte geschrieben, die als Boot-Medium für den Raspberry Pi dient.

```shell
# XZ Archiv Entpacken
$ unxz 2025-05-13-raspios-bookworm-armhf-lite.img.xz
# Auf SD Karte schreiben
$ sudo dd if=2025-05-13-raspios-bookworm-armhf-lite.img of=/dev/mmcblk0 bs=1M status=progress
```

Sobald die microSD-Karte vorbereitet ist, kann der Raspberry Pi in Betrieb genommen werden. Dazu wird die Karte in den entsprechenden Slot eingesteckt und das Gerät mit Strom versorgt. Das System startet daraufhin automatisch vom eingelegten Boot-Medium.

## 3. Konfiguaration

Bei der erstmaligen Inbetriebnahme des Raspberry Pi muss eine grundlegende Konfiguration vorgenommen werden. Der Benutzer wählt in diesem Schritt das gewünschte Tastaturlayout und richtet ein Benutzerkonto mit Passwort ein. In früheren Versionen des Betriebssystem-Images war standardmäßig der Benutzername **pi** mit dem Passwort **raspberry** voreingestellt. Um diesen Zustand nachzustellen, werden im Rahmen der Konfiguration identische Zugangsdaten verwendet.

Im Anschluss erfolgt der Login in die Shell. Um den SSH-Dienst zu aktivieren, wird die Datei /boot/firmware/ssh erstellt. In der Standardkonfiguration des SSH-Servers ist ein Login mit diesen bekannten Standard-Zugangsdaten möglich. Dies ermöglicht es einem Angreifer, sich unbefugt Zugriff auf das System zu verschaffen und im weiteren Verlauf den privaten Schlüssel des Sign-Servers zu entwenden – ein schwerwiegender Sicherheitsvorfall, der in einem realen Produktionsumfeld erhebliche Konsequenzen nach sich ziehen könnte, etwa die vollständige Kompromittierung der Software-Lieferkette.

```shell
$ sudo touch /boot/firmware/ssh
```
Für ein derart sicherheitskritisches Einsatzszenario wäre es zwingend erforderlich gewesen, den Passwort-Login über SSH zu deaktivieren und ausschließlich Authentifizierungen über zuvor hinterlegte Public Keys zuzulassen.

Um eine fundierte forensische Analyse zu ermöglichen, ist es notwendig, die Standardkonfiguration des System-Loggings anzupassen. In der Voreinstellung werden SSH-Login-Versuche lediglich flüchtig im Arbeitsspeicher protokolliert. Das bedeutet, dass sämtliche Einträge nach einem Neustart verloren gehen.

Damit die Logeinträge dauerhaft gespeichert werden, muss die Konfigurationsdatei
`/etc/systemd/journald.conf` angepasst werden. Hierzu wird der Parameter:
```ini
Storage=persistent
```
gesetzt. Dadurch speichert das System alle Logdaten dauerhaft im Verzeichnis `/var/log/journal`, sodass sie auch nach einem Neustart erhalten bleiben und für eine spätere Analyse zur Verfügung stehen.

## 4. Anwendung

Die eigentliche Anwendung zum sigieren der Daten wird mit einem einfachen Shell-Skript realisiert. Zur Signatur Erstellung wird auf den RSA Algorithmus zurückgegriffen. Dazu wird zunächst im Homevezeichnis des Raspberry Pi ein RSA schlüsselpaar mittels OpenSSL generiert. Die Schlüssellänge soll hierbei 4096 Bits betragen:

```shell
# Private Key generieren 
$ openssl genrsa -out sign-server.pem 4096
# Public Key aus Private Key extrahieren
$ openssl pkey -in sign-server.pem -pubout -out sign-server.pub
# Schlüsselpaar liegt nun im Homeverzeichnis
$ ls -lisa sign-server*
27548 4 -rw------- 1 pi   pi   3272 Jun 17 14:02 sign-server.pem
27598 4 -rw-r--r-- 1 pi   pi    800 Jun 17 14:02 sign-server.pub
```

Das Shell-Skript *server.sh* lauscht in einer Endlosschleife auf Port 3000 und empfängt darüber eingehende Daten. Für die empfangenen Inhalte wird ein Hashwert berechnet und anschließend mit einem privaten Schlüssel digital signiert. Die erzeugte Signatur wird daraufhin über Port 3001 an den Client zurückgesendet.

```shell
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
```

Zum Testen kann das Skript client.sh verwendet werden. Dieses erwartet als Parameter eine Datei, die zum Server übertragen und dort signiert wird. Die vom Server empfangene Signatur wird anschließend mithilfe des öffentlichen Schlüssels auf dem Client geprüft, um die Authentizität und Integrität der Datei zu verifizieren.

```shell
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
```

Um das Skript *server.sh* automatisch nach dem Booten zu starten wird eine Systemd Service Datei verwendet. Bei einem Fehlerhaften beenden (exit 1) wird der Server neugestartet.

```systemd
[Unit]
Description=Production Sign Server
After=network.target

[Service]
WorkingDirectory=/home/pi
ExecStart=/home/pi/server.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target

```

Das Skript und die autostart Datei werden anschließend auf den Raspberry Pi per SSH kopiert und aktiviert.

```shell
# Über Netzwerk Kopiern. Achtung: IP-Adresse anpassen
$ scp server.sh sign-server-autostart.service pi@192.168.0.103:
$ ssh pi@192.168.0.103
$ sudo cp sign-server-autostart.service /etc/systemd/system
# Autostart Service aktiviern 
$ sudo systemctl enable sign-server-autostart.service
```

## 5. Angriff

Das vorliegende Angreifermodell geht von einem Insider aus, der über tiefgreifende Kenntnisse des eingesetzten Systems verfügt. Es wird angenommen, dass der Raspberry Pi im Headless-Betrieb läuft, d. h. ohne angeschlossene Tastatur, Maus oder Display, wie es typischerweise in Produktionsumgebungen der Fall ist.

Das Ziel des Angreifers besteht darin, den Private Key des Systems zu entwenden, um damit manipulierte Daten oder Software eigenständig signieren zu können. Ein solcher Schlüsselmissbrauch könnte beispielsweise dazu verwendet werden, veränderte Firmware auf einem Elektronikgerät zu starten, ohne dass dies vom System erkannt wird.

Der Angriff verläuft in mehreren Schritten:

**1. Physischer Zugriff:** Der Angreifer schafft es unbemerkt, einen USB-Stick in den Raspberry Pi einzustecken.
**2. Exfiltration des Schlüssels:** Der USB-Stick dient als Mittel zur Datenexfiltration – insbesondere des Private Keys.
**3. Remote-Zugriff via SSH:** Aufgrund des Headless-Betriebs erfolgt die Interaktion mit dem System über eine SSH-Verbindung. Der Angreifer nutzt hierfür Standard-Zugangsdaten, um sich Zugriff zum System zu verschaffen.
**4. Dateizugriff und Manipulation:** 
    -   Der eingesteckte USB-Stick wird gemountet.
    -   Der Private Key wird ausgelesen, auf den Stick kopiert und auf dem System überschrieben.
**5. Spurenbeseitigung:** Anschließend entfernt der Angreifer den USB-Stick wieder und verschiebt den entwendeten Schlüssel auf seinen eigenen Computer zur weiteren Nutzung.

```shell
# SSH Login
$ ssh pi@192.168.0.103
# USB Stick mounten (Automount ist deaktiviert)
$ sudo mount /dev/sda1 /mnt
# Exfiltration
$ cp /home/pi/sign-server.pem /mnt
# Key Überschreiben
$ >/home/pi/sign-server.pem
# USB Stick unmounten
$ sudo umount /mnt
# SSH Logout
$ exit
# 
# Private Key vom USB Stick verschieben
$ mv /media/lutz/LUTZ/sign-server.pem /home/lutz/
# USB Stick anschließend "leer"
$ ls -lisa /media/lutz/LUTZ
insgesamt 8
       1 4 drwxr-xr-x  2 lutz lutz 4096 Jan  1  1970 .
79429634 4 drwxr-x---+ 3 root root 4096 Jun 23 10:50 ..
```

## 6. Analyse



