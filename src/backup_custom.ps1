# AD Services Backup Script
# Author: loclp
# Version: 3.0

# Requires -RunAsAdministrator
# Requires -Modules ActiveDirectory, GroupPolicy, DhcpServer, DnsServer

# Set UTF8 encoding without BOM
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function Show-FolderDialog {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Chon thu muc de luu backup"
    $folderDialog.ShowDialog() | Out-Null
    return $folderDialog.SelectedPath
}

function Backup-ADServices {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupPath,
        
        [Parameter(Mandatory=$false)]
        [string]$DomainName = $env:USERDNSDOMAIN
    )

    try {
        # Tạo thư mục backup với timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFolder = Join-Path $BackupPath "ADBackup_${DomainName}_${timestamp}"
        New-Item -ItemType Directory -Path $backupFolder | Out-Null

        Write-Host "Bat dau qua trinh backup cho domain: $DomainName" -ForegroundColor Green
        Write-Host "Thu muc backup: $backupFolder" -ForegroundColor Yellow

        # 1. Backup DHCP Database
        Write-Host "`nBacking up DHCP..." -ForegroundColor Cyan
        $dhcpFolder = Join-Path $backupFolder "DHCP"
        New-Item -ItemType Directory -Path $dhcpFolder | Out-Null
        
        try {
            # Kiểm tra DHCP Service
            $dhcpService = Get-Service -Name "DHCPServer" -ErrorAction SilentlyContinue
            if ($dhcpService -and $dhcpService.Status -eq "Running") {
                Export-DhcpServer -ComputerName $env:COMPUTERNAME -File "$dhcpFolder\dhcp_backup.xml" -Force
                Get-DhcpServerv4Scope | Export-Clixml "$dhcpFolder\dhcp_scopes.xml"
                Write-Host "DHCP backup completed successfully" -ForegroundColor Green
            } else {
                Write-Warning "DHCP Server service is not running or not installed"
            }
        }
        catch {
            Write-Warning "DHCP backup failed: $_"
        }

        # 2. Backup DNS Zones
        Write-Host "`nBacking up DNS..." -ForegroundColor Cyan
        $dnsFolder = Join-Path $backupFolder "DNS"
        New-Item -ItemType Directory -Path $dnsFolder | Out-Null
        
        try {
            # Kiểm tra DNS Service
            $dnsService = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
            if ($dnsService -and $dnsService.Status -eq "Running") {
                $zones = Get-DnsServerZone
                foreach ($zone in $zones) {
                    try {
                        $zonePath = Join-Path $dnsFolder "$($zone.ZoneName).txt"
                        $zoneData = Get-DnsServerResourceRecord -ZoneName $zone.ZoneName -ErrorAction Stop
                        $zoneData | Format-Table -AutoSize | Out-File -FilePath $zonePath -Encoding UTF8
                        Write-Host "Successfully backed up zone: $($zone.ZoneName)" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "Failed to backup zone $($zone.ZoneName): $_"
                    }
                }
            } else {
                Write-Warning "DNS Server service is not running or not installed"
            }
        }
        catch {
            Write-Warning "DNS backup failed: $_"
        }

        # 3. Backup GPOs
        Write-Host "`nBacking up Group Policies..." -ForegroundColor Cyan
        $gpoFolder = Join-Path $backupFolder "GPO"
        New-Item -ItemType Directory -Path $gpoFolder | Out-Null
        
        try {
            $gpos = Backup-GPO -All -Path $gpoFolder
            # Create GPO summary report
            $gpoReport = foreach ($gpo in $gpos) {
                [PSCustomObject]@{
                    Name = $gpo.DisplayName
                    ID = $gpo.GpoId
                    CreationTime = $gpo.CreationTime
                    BackupStatus = "Success"
                }
            }
            $gpoReport | Export-Csv -Path (Join-Path $gpoFolder "gpo_summary.csv") -NoTypeInformation -Encoding UTF8
            Write-Host "GPO backup completed successfully" -ForegroundColor Green
        }
        catch {
            Write-Warning "GPO backup failed: $_"
        }

        # 4. Backup AD Objects
        Write-Host "`nBacking up AD Objects..." -ForegroundColor Cyan
        $adFolder = Join-Path $backupFolder "AD"
        New-Item -ItemType Directory -Path $adFolder | Out-Null
        
        try {
            # Backup with progress indication
            Write-Host "Backing up Users..." -NoNewline
            Get-ADUser -Filter * -Properties * | Export-Clixml "$adFolder\ad_users.xml"
            Write-Host "Done" -ForegroundColor Green
            
            Write-Host "Backing up Groups..." -NoNewline
            Get-ADGroup -Filter * -Properties * | Export-Clixml "$adFolder\ad_groups.xml"
            Write-Host "Done" -ForegroundColor Green
            
            Write-Host "Backing up OUs..." -NoNewline
            Get-ADOrganizationalUnit -Filter * -Properties * | Export-Clixml "$adFolder\ad_ous.xml"
            Write-Host "Done" -ForegroundColor Green
            
            Write-Host "Backing up Computers..." -NoNewline
            Get-ADComputer -Filter * -Properties * | Export-Clixml "$adFolder\ad_computers.xml"
            Write-Host "Done" -ForegroundColor Green
            
            # Create summary of AD objects
            $adSummary = @{
                Users = (Get-ADUser -Filter *).Count
                Groups = (Get-ADGroup -Filter *).Count
                OUs = (Get-ADOrganizationalUnit -Filter *).Count
                Computers = (Get-ADComputer -Filter *).Count
            }
            $adSummary | ConvertTo-Json | Out-File "$adFolder\ad_summary.json" -Encoding UTF8
        }
        catch {
            Write-Warning "AD Objects backup failed: $_"
        }

        # Create detailed backup report
        $reportContent = @"
Backup Report
-------------
Date: $(Get-Date)
Domain: $DomainName
Backup Location: $backupFolder

Components Backed Up:
1. DHCP
 - Database backup: $(Test-Path "$dhcpFolder\dhcp_backup.xml")
 - Scopes backup: $(Test-Path "$dhcpFolder\dhcp_scopes.xml")

2. DNS
 - Total zones backed up: $((Get-ChildItem $dnsFolder -Filter "*.txt").Count)

3. Group Policy Objects
 - Total GPOs backed up: $($gpos.Count)

4. AD Objects
 - Users: $($adSummary.Users)
 - Groups: $($adSummary.Groups)
 - OUs: $($adSummary.OUs)
 - Computers: $($adSummary.Computers)

Backup completed at: $(Get-Date)
"@

        $reportContent | Out-File -FilePath (Join-Path $backupFolder "backup_report.txt") -Encoding UTF8
        Write-Host "`nBackup completed! Check the backup report for details." -ForegroundColor Green
        
        # Open the backup folder
        explorer.exe $backupFolder
    }
    catch {
        Write-Error "Backup process failed: $_"
    }
}

# Main execution
try {
    # Get backup location from user
    $backupPath = Show-FolderDialog
    if ([string]::IsNullOrEmpty($backupPath)) {
        Write-Error "Khong co thu muc nao duoc chon. Thoat script."
        exit
    }

    # Get domain name (optional)
    $domainName = Read-Host "Nhap ten domain (Enter de su dung domain hien tai)"
    if ([string]::IsNullOrEmpty($domainName)) {
        $domainName = $env:USERDNSDOMAIN
    }

    # Execute backup
    Backup-ADServices -BackupPath $backupPath -DomainName $domainName
}
catch {
    Write-Error "Script execution failed: $_"
}