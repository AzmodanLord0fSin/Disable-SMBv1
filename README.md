# Disable-SMBv1

Deaktiviert das veraltete **SMBv1**-Protokoll auf Windows-Maschinen (ab Windows 8 /
Server 2012) — auf Server-, Registry- und Client-Treiber-Ebene, optional inklusive
Deinstallation des Windows-Features.

## Use Case

Entstanden in meiner Zeit als **OT-Security-Service-Admin**. SMBv1 ist der Vektor von
**EternalBlue / WannaCry / NotPetya** — und genau diese Wurmangriffe haben 2017 gezeigt,
wie verheerend sie in OT-Netzen wirken: WannaCry legte Produktionslinien, Kliniken und
Logistik lahm, weil dort massenhaft ältere, selten gepatchte Windows-Systeme mit aktivem
SMBv1 stehen (HMIs, Leitstände, Maschinen-PCs, die der Anlagenhersteller nie aktualisiert).

In der OT ist genau das der Normalfall: Systeme, die man nicht einfach neu aufsetzt, aber
härten muss. Dieses Skript schaltet SMBv1 in einem Durchlauf und auf allen drei Ebenen ab
— idempotent, sodass man es problemlos über eine ganze Flotte laufen lassen kann, ohne
schon deaktivierte Hosts zu stören.

> **Legacy-Vorbehalt:** In seltenen Fällen sprechen uralte Geräte (bestimmte
> Altdrucker, sehr alte Industriesteuerungen) *nur* SMBv1. Vor dem Flottenrollout prüfen,
> ob eine solche Abhängigkeit besteht — sonst reißt man eine Freigabe ab.

## Verwendung

Als Administrator ausführen (das Skript erzwingt das über `#Requires -RunAsAdministrator`):

```powershell
# Interaktiv: deaktiviert SMBv1, fragt am Ende nach Feature-Deinstallation
.\Disable-SMBv1.ps1

# Ohne Rückfrage, inkl. Feature-Deinstallation — für GPO / Remoting / Massenrollout
.\Disable-SMBv1.ps1 -RemoveFeature

# Vorschau ohne Änderungen
.\Disable-SMBv1.ps1 -WhatIf
```

Was deaktiviert wird:

1. **SMB-Server** — `Set-SmbServerConfiguration -EnableSMB1Protocol $false`
2. **Registry** — `LanmanServer\Parameters\SMB1 = 0`
3. **Client-Treiber** — Dienst `mrxsmb10` auf `disabled`, Abhängigkeiten bereinigt
4. **Optional** — Deinstallation des Windows-Features `SMB1Protocol`

Nach der Änderung wird ein **Neustart** empfohlen, damit die Treiberänderung greift.

## Was 2026 korrigiert wurde

- **Logikfehler behoben:** Die Registry-Prüfung lautete
  `($_smbreg | Select-Object SMB1) -ne 0` — das vergleicht ein *Objekt* mit `0` und ist
  damit **immer wahr**. Jetzt wird der tatsächliche DWORD-Wert gelesen und verglichen.
- **`Invoke-Expression` entfernt:** `sc.exe` wird direkt aufgerufen statt über einen
  zusammengebauten String; Rückgabecodes werden ausgewertet.
- **Parametrisiert:** `-RemoveFeature` für den unbeaufsichtigten Lauf, `-WhatIf`-Vorschau
  über `SupportsShouldProcess`.
- **`.ps1`-Endung** und Requires-Version ergänzt; PSScriptAnalyzer läuft sauber.

## Prüfen, ob es gewirkt hat

```powershell
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol   # -> False
Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol    # -> Disabled
```

## Lizenz

Siehe [LICENSE](LICENSE).
