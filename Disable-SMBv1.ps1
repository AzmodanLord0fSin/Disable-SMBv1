#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Deaktiviert das SMBv1-Protokoll auf Windows-Maschinen (ab Windows 8 / Server 2012).

.DESCRIPTION
    SMBv1 ist der Angriffsvektor von EternalBlue / WannaCry / NotPetya und gehoert auf
    jedem modernen System abgeschaltet. Das Skript deaktiviert SMBv1 auf drei Ebenen:

      1. SMB-Server-Konfiguration (Set-SmbServerConfiguration)
      2. Registry (LanmanServer\Parameters\SMB1)
      3. Client-Treiberdienst mrxsmb10 und dessen Abhaengigkeiten

    Optional wird auf Nachfrage das Windows-Feature "SMB1Protocol" ganz deinstalliert.

.PARAMETER RemoveFeature
    Entfernt zusaetzlich das optionale Windows-Feature SMB1Protocol, ohne Rueckfrage.
    Ohne diesen Schalter fragt das Skript interaktiv nach.

.EXAMPLE
    .\Disable-SMBv1.ps1
    Deaktiviert SMBv1 und fragt am Ende, ob das Feature deinstalliert werden soll.

.EXAMPLE
    .\Disable-SMBv1.ps1 -RemoveFeature
    Deaktiviert SMBv1 und deinstalliert das Feature ohne Rueckfrage (fuer GPO/Remoting).

.NOTES
    Ein Neustart wird empfohlen, damit die Treiberaenderung vollstaendig greift.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RemoveFeature
)

Set-StrictMode -Version Latest

function Disable-Smb1ClientDriver {
    # Fruehere Fassung rief sc.exe ueber Invoke-Expression auf. Direktaufruf ist
    # sicherer (kein String-Parsing) und liefert Fehler ueber $LASTEXITCODE zurueck.
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('mrxsmb10', 'Client-Treiberdienst deaktivieren')) {
        & sc.exe config mrxsmb10 start= disabled | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "sc.exe config mrxsmb10 lieferte Code $LASTEXITCODE." }

        & sc.exe config lanmanworkstation depend= bowser/mrxsmb20/nsi | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "sc.exe config lanmanworkstation lieferte Code $LASTEXITCODE." }
    }
}

function Disable-Smb1 {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Bewusste farbige Abschlussmeldung fuer den interaktiven Bediener.')]
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$RemoveFeature)

    # 1) SMB-Server-Konfiguration
    if ((Get-SmbServerConfiguration).EnableSMB1Protocol) {
        Write-Warning 'SMBv1 (Server) ist aktiv - wird deaktiviert.'
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
        Write-Verbose 'SMBv1 (Server) deaktiviert.'
    }
    else {
        Write-Verbose 'SMBv1 (Server) ist bereits deaktiviert.'
    }

    # 2) Registry. Frueher stand hier '($_smbreg | Select-Object SMB1) -ne 0' -
    # das vergleicht ein Objekt mit 0 und ist damit IMMER wahr. Jetzt wird der
    # tatsaechliche Wert gelesen.
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
    $smb1    = (Get-ItemProperty -Path $regPath -Name 'SMB1' -ErrorAction SilentlyContinue).SMB1
    if ($smb1 -ne 0) {
        Write-Warning 'SMB1 in Registry (LanmanServer) aktiv - wird auf 0 gesetzt.'
        Set-ItemProperty -Path $regPath -Name 'SMB1' -Type DWord -Value 0 -Force
        Write-Verbose 'Registry-Wert SMB1 = 0 gesetzt.'
    }
    else {
        Write-Verbose 'Registry-Wert SMB1 ist bereits 0.'
    }

    # 3) Client-Treiber
    Disable-Smb1ClientDriver

    # 4) Optionales Feature
    $doRemove = $RemoveFeature
    if (-not $doRemove) {
        $answer  = Read-Host 'Windows-Feature SMB1Protocol jetzt deinstallieren? (j/n)'
        $doRemove = $answer -in @('j', 'y')
    }
    if ($doRemove) {
        if ($PSCmdlet.ShouldProcess('SMB1Protocol', 'Windows-Feature deinstallieren')) {
            Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
        }
    }

    Write-Host 'Fertig. Ein Neustart wird empfohlen, damit alle Aenderungen greifen.' -ForegroundColor Green
}

Disable-Smb1 -RemoveFeature:$RemoveFeature
