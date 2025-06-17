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

Zum weiteren Aufbau der Umgebung werden einige zusätzliche Debian Pakete mit folgendem Komanndo installiert (Internet Verbindung notwendig)

```shell
sudo apt-get install openssl
```

Ein denkbares Beispiel wäre ein offener SSH-Port mit Standard-Anmeldeinformationen oder ein falsch gesetzter PermitRootLogin-Parameter. In der Folge gelingt es dem Angreifer, sich Zugang zum System zu verschaffen und den privaten Schlüssel des Sign-Servers zu entwenden – ein gravierender Vorfall, der in einem echten Produktionsumfeld weitreichende Folgen hätte, etwa das Kompromittieren der gesamten Lieferkette.
Zunächst wird bewusst die Konfguration des SSH Dienstes welche sich unter */etc/ssh/sshd_config* befindet modifiziert. 

```shell

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

Include /etc/ssh/sshd_config.d/*.conf

#Port 22
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
PermitRootLogin no
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

# Expect .ssh/authorized_keys2 to be disregarded by default in future.
#AuthorizedKeysFile	.ssh/authorized_keys .ssh/authorized_keys2

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
#PasswordAuthentication yes
#PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
KbdInteractiveAuthentication no

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the KbdInteractiveAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via KbdInteractiveAuthentication may bypass
# the setting of "PermitRootLogin prohibit-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and KbdInteractiveAuthentication to 'no'.
UsePAM yes

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
PrintMotd no
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem	sftp	/usr/lib/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#	X11Forwarding no
#	AllowTcpForwarding no
#	PermitTTY no
#	ForceCommand cvs server

```

## 4. Anwendung

Die eigentliche Anwendung zum sigieren der Daten wird mit einem einfachen Shell-Skript realisiert. Zur Signatur Erstellung wird auf den RSA Algorithmus zurückgegriffen. Dazu wird zunächst im Homevezeichnis des Raspberry Pi ein RSA schlüsselpaar mittels OpenSSL generiert. Die Schlüssellänge soll hierbei 4096 Bits betragen:

```shell
# Private Key generieren 
$ openssl genrsa -out sign-server.pem 4096
# Public Key aus Private Key extrahieren
$ openssl pkey -in sign-server.pem -pubout -out sign-server.pub
# Schlüsselpaar liegt nun im Homeverzeichnis
$ ls -lisa sign-server*
71827523 4 -rw------- 1 pesi pesi 3272 Jun 12 10:52 sign-server.pem
71827526 4 -rw-rw-r-- 1 pesi pesi  800 Jun 12 10:57 sign-server.pub
```

Das Shell-Skript server.sh lauscht in einer Endlosschleife auf Port 3000 und empfängt darüber eingehende Daten. Für die empfangenen Inhalte wird ein Hashwert berechnet und anschließend mit einem privaten Schlüssel digital signiert. Die erzeugte Signatur wird daraufhin über Port 3001 an den Client zurückgesendet.

```shell
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
```

Zum Testen kann auf demselben System das Skript client.sh verwendet werden. Dieses erwartet als Parameter eine Datei, die zum Server übertragen und dort signiert wird. Die vom Server empfangene Signatur wird anschließend mithilfe des öffentlichen Schlüssels auf dem Client geprüft, um die Authentizität und Integrität der Datei zu verifizieren.

```shell
#!/bin/bash
FILE=$1
SERVER="localhost"
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

## 5. Angriff

## 6. Analyse

