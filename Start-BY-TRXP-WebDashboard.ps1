# BY TRXP Local Web Dashboard v2.5 - Windows PowerShell 5.1+
# Binds only to 127.0.0.1. All privileged actions use a small allow-list API.
$ErrorActionPreference = 'Stop'

function Get-EntryPath {
    try {
        if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf) -and ([IO.Path]::GetExtension($PSCommandPath) -ieq '.ps1')) {
            return [IO.Path]::GetFullPath($PSCommandPath)
        }
    } catch { }
    try { return [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch { }
    return [Environment]::GetCommandLineArgs()[0]
}
$EntryPath = Get-EntryPath
$AppRoot = Split-Path -Parent $EntryPath
if ([string]::IsNullOrWhiteSpace($AppRoot)) { $AppRoot = [Environment]::CurrentDirectory }

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Elevate once because driver REG and several system actions need Administrator.
if (-not (Test-IsAdministrator)) {
    try {
        $psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if ([IO.Path]::GetExtension($EntryPath) -ieq '.ps1') {
            $argLine = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $EntryPath + '"'
            Start-Process -FilePath $psExe -Verb RunAs -WindowStyle Hidden -ArgumentList $argLine | Out-Null
        } else {
            Start-Process -FilePath $EntryPath -Verb RunAs -WindowStyle Hidden | Out-Null
        }
    } catch {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("ต้องอนุญาต Administrator เพื่อใช้ฟังก์ชัน Registry และ Power Plan`n$($_.Exception.Message)", 'BY TRXP Dashboard', 'OK', 'Warning') | Out-Null
    }
    exit
}

$script:DashboardRoot = $AppRoot
$script:DriverBackupFile = Join-Path $AppRoot 'BY_TRXP_Web_Driver_Backup.json'
$script:UserBackupFile = Join-Path $AppRoot 'BY_TRXP_Web_MouseKeyboard_Backup.json'
$script:PowerBackupFile = Join-Path $AppRoot 'BY_TRXP_Web_PowerPlan_Backup.json'
$script:NetworkBackupFile = Join-Path $AppRoot 'BY_TRXP_Web_Network_Backup.json'
$script:TrxpSettingBackupFile = Join-Path $AppRoot 'BY_TRXP_Web_SettingTRXP_Backup.json'
$script:TrxpTcpBackupFile = Join-Path $AppRoot 'BY_TRXP_Web_SettingTRXP_Tcpip.reg'
$script:TrxpTcp6BackupFile = Join-Path $AppRoot 'BY_TRXP_Web_SettingTRXP_Tcpip6.reg'
$script:FiveMIniBackupFile = Join-Path $AppRoot 'BY_TRXP_Web_CitizenFX_Backup.json'
$script:NetworkKeywords = @('*ReceiveBuffers', '*TransmitBuffers', '*RxIntModeration', '*TxIntModeration', '*InterruptModeration', '*FlowControl', '*WakeOnMagicPacket', '*WakeOnPattern')
$script:LogFile = Join-Path $AppRoot 'BY_TRXP_WebDashboard.log'
$script:MouseRegFile = Join-Path $AppRoot 'MouseDataQ.reg'
$script:KeyboardRegFile = Join-Path $AppRoot 'KeyboardDataQ.reg'
$script:RamMapOfficialUrl = 'https://learn.microsoft.com/sysinternals/downloads/rammap'
$script:DriverSettings = @(
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters'; Name='MouseDataQueueSize'; Kind='DWord' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters'; Name='WppRecorder_TraceGuid'; Kind='String' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name='ConnectMultiplePorts'; Kind='DWord' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name='KeyboardDataQueueSize'; Kind='DWord' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name='KeyboardDeviceBaseName'; Kind='String' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name='MaximumPortsServiced'; Kind='DWord' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name='SendOutputToAllPorts'; Kind='DWord' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name='WppRecorder_TraceGuid'; Kind='String' },
    @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name='ThreadPriority'; Kind='DWord' }
)
$script:UserSettings = @(
    @{ Path='HKCU:\Control Panel\Mouse'; Name='MouseSpeed'; Value='0'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Mouse'; Name='MouseThreshold1'; Value='0'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Mouse'; Name='MouseThreshold2'; Value='0'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Mouse'; Name='MouseSensitivity'; Value='10'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Mouse'; Name='DoubleClickSpeed'; Value='200'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Keyboard'; Name='KeyboardDelay'; Value='0'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Keyboard'; Name='KeyboardSpeed'; Value='31'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Desktop'; Name='MenuShowDelay'; Value='0'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Desktop'; Name='HungAppTimeout'; Value='2000'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Desktop'; Name='WaitToKillAppTimeout'; Value='2000'; Kind='String' },
    @{ Path='HKCU:\Control Panel\Desktop'; Name='LowLevelHooksTimeout'; Value='1000'; Kind='String' }
)

function Write-Log([string]$Message) {
    try { Add-Content -LiteralPath $script:LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8 } catch { }
}

function Save-RegistryValueBackup([string]$BackupPath, [array]$Entries) {
    if (Test-Path -LiteralPath $BackupPath -PathType Leaf) { return }
    $records = @()
    foreach ($entry in $Entries) {
        $regPath = [string]$entry.Path
        $name = [string]$entry.Name
        $keyExisted = Test-Path -LiteralPath $regPath
        $exists = $false; $value = $null; $kind = [string]$entry.Kind
        if ($keyExisted) {
            $key = Get-Item -LiteralPath $regPath -ErrorAction Stop
            if ($key.GetValueNames() -contains $name) {
                $exists = $true
                $value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $kind = $key.GetValueKind($name).ToString()
            }
        }
        $records += [pscustomobject]@{ Path=$regPath; Name=$name; Exists=[bool]$exists; Value=$value; Kind=$kind; KeyExisted=[bool]$keyExisted }
    }
    $records | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $BackupPath -Encoding UTF8
}

function Restore-RegistryValueBackup([string]$BackupPath, [string]$Label) {
    if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) { throw "ไม่พบข้อมูลสำรอง $Label กรุณาใช้ปุ่ม Apply อย่างน้อยหนึ่งครั้งก่อน" }
    $parsed = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = @($parsed)
    foreach ($item in $items) {
        $regPath = [string]$item.Path; $name = [string]$item.Name
        if ([string]::IsNullOrWhiteSpace($regPath) -or [string]::IsNullOrWhiteSpace($name)) { throw "ไฟล์สำรอง $Label มีข้อมูลไม่ครบ จึงหยุดโดยไม่ลบไฟล์สำรอง" }
        if (-not (Test-Path -LiteralPath $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        if ([bool]$item.Exists) {
            $kind = [string]$item.Kind
            if ($kind -notin @('String','ExpandString','Binary','DWord','MultiString','QWord')) { throw "ชนิด Registry ที่ไม่รองรับในไฟล์สำรอง: $kind" }
            New-ItemProperty -LiteralPath $regPath -Name $name -Value $item.Value -PropertyType $kind -Force | Out-Null
        } else {
            Remove-ItemProperty -LiteralPath $regPath -Name $name -ErrorAction SilentlyContinue
        }
    }
    foreach ($regPath in @($items | Where-Object { $_.KeyExisted -eq $false } | ForEach-Object { [string]$_.Path } | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $regPath) {
            $key = Get-Item -LiteralPath $regPath
            if (@($key.GetValueNames()).Count -eq 0 -and @($key.GetSubKeyNames()).Count -eq 0) {
                Remove-Item -LiteralPath $regPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Remove-Item -LiteralPath $BackupPath -Force
    return "$Label คืนค่าตามข้อมูลสำรองเดิมสำเร็จ"
}

function Get-RegExePath {
    $regPath = Join-Path $env:WINDIR 'System32\reg.exe'
    if (-not [Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) {
        $native = Join-Path $env:WINDIR 'Sysnative\reg.exe'
        if (Test-Path -LiteralPath $native) { $regPath = $native }
    }
    if (-not (Test-Path -LiteralPath $regPath -PathType Leaf)) { throw "ไม่พบ reg.exe: $regPath" }
    return $regPath
}

function Invoke-NativeCommand([string]$FilePath, [string[]]$Arguments) {
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "ไม่พบไฟล์: $FilePath" }
    $quoted = foreach ($arg in $Arguments) {
        $s = [string]$arg
        if ($s -match '[\s"]') { '"' + $s.Replace('"','\"') + '"' } else { $s }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($quoted -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    try {
        if (-not $process.Start()) { throw "เริ่มโปรแกรมไม่สำเร็จ: $FilePath" }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            $combined = (($stdout.Trim(), $stderr.Trim()) | Where-Object { $_ }) -join "`n"
            throw "$([IO.Path]::GetFileName($FilePath)) ทำงานไม่สำเร็จ (ExitCode $($process.ExitCode)) $combined"
        }
        return [pscustomobject]@{ Output=$stdout; Error=$stderr; ExitCode=$process.ExitCode }
    } finally { $process.Dispose() }
}

function Invoke-PowerCfg([string[]]$Arguments) {
    $powercfg = Join-Path $env:WINDIR 'System32\powercfg.exe'
    $result = Invoke-NativeCommand -FilePath $powercfg -Arguments $Arguments
    return [string]$result.Output + [string]$result.Error
}

function Get-ActivePowerPlan {
    $out = Invoke-PowerCfg -Arguments @('/getactivescheme')
    $m = [regex]::Match($out, '(?i)([0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12})')
    if (-not $m.Success) { throw "อ่าน Power Plan ปัจจุบันไม่สำเร็จ: $out" }
    $guid = $m.Groups[1].Value
    $list = Invoke-PowerCfg -Arguments @('/list')
    $name = $guid
    foreach ($line in ($list -split "`r?`n")) {
        if ($line -match [regex]::Escape($guid)) {
            $nm = [regex]::Match($line, '\(([^()]*)\)\s*\*?\s*$')
            if ($nm.Success) { $name = $nm.Groups[1].Value.Trim() }
            break
        }
    }
    return [pscustomobject]@{ Guid=$guid; Name=$name }
}

function Get-TRXPPowerPlanGuid {
    $list = Invoke-PowerCfg -Arguments @('/list')
    foreach ($line in ($list -split "`r?`n")) {
        if ($line -match '(?i)\(\s*TRXP\s*\)') {
            $m = [regex]::Match($line, '(?i)([0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12})')
            if ($m.Success) { return $m.Groups[1].Value }
        }
    }
    return $null
}

function Enable-TRXPPowerPlan {
    $current = Get-ActivePowerPlan
    if (-not (Test-Path -LiteralPath $script:PowerBackupFile)) {
        [pscustomobject]@{ PreviousPowerPlanGuid=$current.Guid; PreviousPowerPlanName=$current.Name; SavedAt=(Get-Date).ToString('o') } |
            ConvertTo-Json | Set-Content -LiteralPath $script:PowerBackupFile -Encoding UTF8
    }
    $planGuid = Get-TRXPPowerPlanGuid
    if (-not $planGuid) {
        $dup = Invoke-PowerCfg -Arguments @('/duplicatescheme','381b4222-f694-41f0-9685-ff5bb260df2e')
        $match = [regex]::Match($dup, '(?i)([0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12})')
        if (-not $match.Success) { throw "สร้าง Power Plan TRXP ไม่สำเร็จ: $dup" }
        $planGuid = $match.Groups[1].Value
        $null = Invoke-PowerCfg -Arguments @('/changename',$planGuid,'TRXP','BY TRXP Gaming Performance')
    }
    $mainSettings = @(
        @{Sub='SUB_PROCESSOR'; Setting='PROCTHROTTLEMIN'; Value='5'; Name='CPU Minimum 5%'},
        @{Sub='SUB_PROCESSOR'; Setting='PROCTHROTTLEMAX'; Value='100'; Name='CPU Maximum 100%'},
        @{Sub='SUB_PROCESSOR'; Setting='SYSCOOLPOL'; Value='1'; Name='Active Cooling'}
    )
    $applied = New-Object System.Collections.Generic.List[string]
    foreach ($setting in $mainSettings) {
        $null = Invoke-PowerCfg -Arguments @('/setacvalueindex',$planGuid,$setting.Sub,$setting.Setting,$setting.Value)
        $applied.Add($setting.Name)
    }
    $optional = @(
        @{Sub='SUB_PROCESSOR'; Setting='PERFEPP'; Value='0'; Name='Energy Preference 0'},
        @{Sub='SUB_PROCESSOR'; Setting='PERFBOOSTMODE'; Value='2'; Name='Boost Aggressive'}
    )
    $skipped = New-Object System.Collections.Generic.List[string]
    foreach ($setting in $optional) {
        try { $null = Invoke-PowerCfg -Arguments @('/setacvalueindex',$planGuid,$setting.Sub,$setting.Setting,$setting.Value); $applied.Add($setting.Name) }
        catch { $skipped.Add($setting.Name) }
    }
    $null = Invoke-PowerCfg -Arguments @('/setactive',$planGuid)
    $message = "เปิด Power Plan TRXP แล้ว (AC/เสียบไฟ): " + ($applied -join ', ') + '. แผนเดิมเก็บไว้ในไฟล์สำรอง'
    if ($skipped.Count -gt 0) { $message += ' ค่าเสริมที่ Windows/CPU ไม่รองรับและข้ามให้: ' + ($skipped -join ', ') }
    $message += ' ค่านี้ไม่รับประกัน FPS/Ping และอาจเพิ่มการใช้ไฟ/ความร้อน'
    return $message
}

function Restore-TRXPPowerPlan {
    if (-not (Test-Path -LiteralPath $script:PowerBackupFile -PathType Leaf)) { throw 'ยังไม่มีข้อมูลสำรอง Power Plan — เปิดใช้ TRXP อย่างน้อยหนึ่งครั้งก่อน' }
    $backup = Get-Content -LiteralPath $script:PowerBackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $guid = [string]$backup.PreviousPowerPlanGuid
    if ($guid -notmatch '(?i)^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$') { throw 'GUID ในข้อมูลสำรอง Power Plan ไม่ถูกต้อง ไฟล์สำรองยังคงอยู่' }
    $null = Invoke-PowerCfg -Arguments @('/setactive',$guid)
    Remove-Item -LiteralPath $script:PowerBackupFile -Force
    return "คืนค่า Power Plan เดิม ($($backup.PreviousPowerPlanName)) แล้ว โดยยังเก็บแผน TRXP ไว้ใน Windows"
}

function Apply-DriverReg {
    foreach ($file in @($script:MouseRegFile,$script:KeyboardRegFile)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "ไม่พบไฟล์ REG: $file`nให้เก็บ MouseDataQ.reg และ KeyboardDataQ.reg ข้างโปรแกรม" }
    }
    Save-RegistryValueBackup -BackupPath $script:DriverBackupFile -Entries $script:DriverSettings
    $reg = Get-RegExePath
    $null = Invoke-NativeCommand -FilePath $reg -Arguments @('import',$script:MouseRegFile)
    try { $null = Invoke-NativeCommand -FilePath $reg -Arguments @('import',$script:KeyboardRegFile) }
    catch { throw "นำเข้า KeyboardDataQ.reg ไม่สำเร็จหลังจากนำเข้า MouseDataQ.reg ไปแล้ว ข้อมูลสำรองยังเก็บไว้: $($_.Exception.Message)" }
    return 'นำเข้า MouseDataQ.reg และ KeyboardDataQ.reg สำเร็จ สำรองค่าเดิมไว้แล้ว แนะนำให้รีสตาร์ต Windows; ThreadPriority=31 สูงมากและอาจกระทบเสถียรภาพ'
}

function Apply-UserMouseKeyboard {
    Save-RegistryValueBackup -BackupPath $script:UserBackupFile -Entries $script:UserSettings
    foreach ($setting in $script:UserSettings) {
        if (-not (Test-Path -LiteralPath $setting.Path)) { New-Item -Path $setting.Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType $setting.Kind -Force | Out-Null
    }
    return 'ใช้ Mouse FAST และ Keyboard settings: ปิด mouse acceleration, DoubleClick 200 ms, Keyboard Delay 0/Speed 31; คืนค่าเดิมได้จาก Restore'
}

function Get-ActiveNetworkAdapters {
    try {
        return @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' })
    } catch {
        throw "อ่าน Network Adapter ไม่สำเร็จ: $($_.Exception.Message)"
    }
}

function Get-NetworkOptimizerSettings {
    return @(
        @{ Keyword='*ReceiveBuffers'; Desired='1024'; Mode='Buffer'; Label='Receive Buffers' },
        @{ Keyword='*TransmitBuffers'; Desired='1024'; Mode='Buffer'; Label='Transmit Buffers' },
        @{ Keyword='*RxIntModeration'; Desired='0'; Mode='Zero'; Label='RX Interrupt Moderation' },
        @{ Keyword='*TxIntModeration'; Desired='0'; Mode='Zero'; Label='TX Interrupt Moderation' },
        @{ Keyword='*InterruptModeration'; Desired='0'; Mode='Zero'; Label='Interrupt Moderation' },
        @{ Keyword='*FlowControl'; Desired='0'; Mode='Zero'; Label='Flow Control' },
        @{ Keyword='*WakeOnMagicPacket'; Desired='0'; Mode='Zero'; Label='Wake on Magic Packet' },
        @{ Keyword='*WakeOnPattern'; Desired='0'; Mode='Zero'; Label='Wake on Pattern' }
    )
}

function Apply-NetworkAdapterOptimizer {
    $adapters = @(Get-ActiveNetworkAdapters)
    if ($adapters.Count -eq 0) { throw 'ไม่พบ Network Adapter ที่กำลังเชื่อมต่ออยู่' }
    if (Test-Path -LiteralPath $script:NetworkBackupFile -PathType Leaf) {
        throw 'พบไฟล์สำรอง Network เดิมแล้ว กรุณากด Restore Network ก่อนปรับซ้ำ เพื่อไม่ให้ข้อมูลสำรองชุดแรกถูกเขียนทับ'
    }

    # Detect driver-supported properties and calculate a valid target value for each one.
    # The original registry value is recorded before any setting is changed.
    $planned = New-Object System.Collections.Generic.List[object]
    $skipped = New-Object System.Collections.Generic.List[string]
    foreach ($adapter in $adapters) {
        foreach ($setting in (Get-NetworkOptimizerSettings)) {
            $keyword = [string]$setting.Keyword
            $prop = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $keyword -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $prop) {
                $skipped.Add("$($adapter.Name): $keyword (not supported)")
                continue
            }

            $originalValues = @($prop.RegistryValue | ForEach-Object { [string]$_ })
            if ($originalValues.Count -eq 0) {
                $skipped.Add("$($adapter.Name): $keyword (no original value)")
                continue
            }
            $originalValue = if ($originalValues.Count -eq 1) { $originalValues[0] } else { $originalValues }

            $validStrings = @()
            try { $validStrings = @($prop.ValidRegistryValues | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) } catch { $validStrings = @() }
            $target = $null
            if ($setting.Mode -eq 'Buffer') {
                $numericValid = @($validStrings | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
                if ($numericValid.Count -gt 0) {
                    if ($numericValid -contains [int]$setting.Desired) { $target = [string]$setting.Desired }
                    else { $target = [string](($numericValid | Measure-Object -Maximum).Maximum) }
                } else {
                    # If the driver does not publish an enumeration, attempt the common buffer setting;
                    # Set-NetAdapterAdvancedProperty below will still reject unsupported values safely.
                    $target = [string]$setting.Desired
                }
            } else {
                if ($validStrings.Count -gt 0 -and $validStrings -notcontains [string]$setting.Desired) {
                    $skipped.Add("$($adapter.Name): $keyword (driver does not support value $($setting.Desired))")
                    continue
                }
                $target = [string]$setting.Desired
            }

            $planned.Add([pscustomobject]@{
                Name = [string]$adapter.Name
                RegistryKeyword = $keyword
                RegistryValue = $originalValue
                DisplayName = [string]$prop.DisplayName
                DisplayValue = [string]$prop.DisplayValue
                TargetValue = [string]$target
            })
        }
    }
    if ($planned.Count -eq 0) {
        throw 'ไดรเวอร์ Network Adapter นี้ไม่แสดงค่าที่ BY TRXP ปรับได้ จึงไม่ได้เปลี่ยนค่าใด ๆ'
    }

    # Save every original value before applying anything.
    $backupRecords = @($planned | ForEach-Object {
        [pscustomobject]@{
            Name=$_.Name
            RegistryKeyword=$_.RegistryKeyword
            RegistryValue=$_.RegistryValue
            DisplayName=$_.DisplayName
            DisplayValue=$_.DisplayValue
            TargetValue=$_.TargetValue
        }
    })
    ConvertTo-Json -InputObject ([object[]]$backupRecords) -Depth 8 | Set-Content -LiteralPath $script:NetworkBackupFile -Encoding UTF8

    $applied = New-Object System.Collections.Generic.List[string]
    $applyFailed = New-Object System.Collections.Generic.List[string]
    $changedAdapters = New-Object System.Collections.Generic.List[string]
    foreach ($item in $planned) {
        try {
            Set-NetAdapterAdvancedProperty -Name $item.Name -RegistryKeyword $item.RegistryKeyword -RegistryValue ([string]$item.TargetValue) -NoRestart -ErrorAction Stop
            $applied.Add("$($item.Name): $($item.RegistryKeyword)=$($item.TargetValue)")
            $changedAdapters.Add([string]$item.Name)
        } catch {
            $applyFailed.Add("$($item.Name): $($item.RegistryKeyword) — $($_.Exception.Message)")
        }
    }

    $restartFailed = New-Object System.Collections.Generic.List[string]
    foreach ($name in @($changedAdapters | Select-Object -Unique)) {
        try { Restart-NetAdapter -Name $name -Confirm:$false -ErrorAction Stop }
        catch { $restartFailed.Add($name) }
    }

    if ($applied.Count -eq 0) {
        # Keep the backup even when no property accepted the proposed values.
        throw "ไดรเวอร์ไม่ยอมรับค่าที่เสนอ จึงไม่มีรายการใดเปลี่ยนสำเร็จ; เก็บข้อมูลสำรองไว้ที่ $($script:NetworkBackupFile). $($applyFailed -join ' | ')"
    }
    $message = "ประมวลผล Network เสร็จ: ปรับสำเร็จ $($applied.Count) รายการจากค่าที่ไดรเวอร์รองรับ และสำรองค่าเดิมไว้แล้ว."
    if ($skipped.Count -gt 0) { $message += " ข้าม $($skipped.Count) รายการที่ไม่รองรับ/ไม่มีค่าเดิม." }
    if ($applyFailed.Count -gt 0) { $message += " มีรายการที่ตั้งค่าไม่สำเร็จ $($applyFailed.Count) รายการ." }
    if ($restartFailed.Count -gt 0) { $message += " รีสตาร์ต Adapter ไม่สำเร็จ: $($restartFailed -join ', ') — อาจต้องรีสตาร์ตเอง." }
    $message += ' อะแดปเตอร์อาจตัดการเชื่อมต่อชั่วคราว; การปิด Interrupt Moderation อาจเพิ่มภาระ CPU และไม่รับประกัน Ping/FPS.'
    return $message
}

function Restore-NetworkAdapterSettings {
    if (-not (Test-Path -LiteralPath $script:NetworkBackupFile -PathType Leaf)) {
        throw 'ไม่พบไฟล์สำรอง Network — ต้องใช้ Network Optimizer อย่างน้อยหนึ่งครั้งก่อน จึงจะมีข้อมูลคืนค่า'
    }
    $parsed = Get-Content -LiteralPath $script:NetworkBackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = @($parsed)
    if ($items.Count -eq 0) { throw 'ไฟล์สำรอง Network ว่างหรืออ่านไม่ได้ จึงเก็บไฟล์ไว้และหยุดการคืนค่า' }
    $restored = 0
    $failed = New-Object System.Collections.Generic.List[string]
    $affected = New-Object System.Collections.Generic.List[string]
    foreach ($item in $items) {
        $adapterName = [string]$item.Name
        $keyword = [string]$item.RegistryKeyword
        if ([string]::IsNullOrWhiteSpace($adapterName) -or $keyword -notin $script:NetworkKeywords) {
            $failed.Add('รายการสำรองไม่ถูกต้องหรือไม่ได้อยู่ในรายการที่อนุญาต')
            continue
        }
        try {
            $value = @($item.RegistryValue | ForEach-Object { [string]$_ })
            if ($value.Count -eq 0) { throw 'ค่าที่สำรองว่าง' }
            Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword $keyword -RegistryValue ([string[]]$value) -NoRestart -ErrorAction Stop
            $restored++
            $affected.Add($adapterName)
        } catch { $failed.Add("$adapterName / $keyword : $($_.Exception.Message)") }
    }
    foreach ($name in @($affected | Select-Object -Unique)) {
        try { Restart-NetAdapter -Name $name -Confirm:$false -ErrorAction Stop }
        catch { $failed.Add("รีสตาร์ต $name ไม่สำเร็จ: $($_.Exception.Message)") }
    }
    if ($failed.Count -eq 0) {
        Remove-Item -LiteralPath $script:NetworkBackupFile -Force
        return "คืนค่า Network Adapter จากข้อมูลสำรองเดิมสำเร็จ $restored รายการ"
    }
    throw "คืนค่า Network สำเร็จ $restored รายการ แต่มีปัญหา $($failed.Count) รายการ; เก็บไฟล์สำรองไว้เพื่อให้ลองใหม่. $($failed -join ' | ')"
}

function Apply-SettingTRXPNetwork {
    $adapters = @(Get-ActiveNetworkAdapters)
    if ($adapters.Count -eq 0) { throw 'ไม่พบ Network Adapter ที่กำลังเชื่อมต่ออยู่' }
    if (Test-Path -LiteralPath $script:TrxpSettingBackupFile -PathType Leaf) {
        throw 'พบข้อมูลสำรอง Setting TRXP อยู่แล้ว กรุณากด Restore Setting TRXP ก่อนปรับซ้ำ เพื่อไม่เขียนทับค่าเดิม'
    }

    $planned = New-Object System.Collections.Generic.List[object]
    $skipped = New-Object System.Collections.Generic.List[string]
    foreach ($adapter in $adapters) {
        $props = @(Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue)
        foreach ($prop in $props) {
            $display = [string]$prop.DisplayName
            $target = $null
            if ($display -match '^(Interrupt Moderation|Interrupt Moderation Rate)$') { $target = 'Disabled' }
            elseif ($display -match 'Energy[- ]?Efficient Ethernet|Energy Efficient Ethernet|Power Saving Mode|Green Ethernet') { $target = 'Disabled' }
            elseif ($display -eq 'Flow Control') { $target = 'Disabled' }
            if ($null -eq $target) { continue }
            $valid = @($prop.ValidDisplayValues | ForEach-Object { [string]$_ })
            if ($valid.Count -gt 0 -and $valid -notcontains $target) {
                $skipped.Add("$($adapter.Name): $display ไม่รองรับค่า Disabled")
                continue
            }
            $regValues = @($prop.RegistryValue | ForEach-Object { [string]$_ })
            if ($regValues.Count -eq 0) { $skipped.Add("$($adapter.Name): $display ไม่มีค่าเดิมให้สำรอง"); continue }
            $planned.Add([pscustomobject]@{ Name=[string]$adapter.Name; DisplayName=$display; RegistryKeyword=[string]$prop.RegistryKeyword; RegistryValue=$regValues; DisplayValue=[string]$prop.DisplayValue; TargetDisplayValue=$target })
        }
    }

    if ($planned.Count -eq 0) { throw 'ไม่พบ Interrupt Moderation, Energy Efficient หรือ Flow Control ที่ไดรเวอร์รองรับ จึงยังไม่ได้เปลี่ยนค่า Adapter' }

    # Back up the relevant TCP/IP registry branches before applying the requested netsh settings.
    $reg = Get-RegExePath
    $tcpKey = 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    $tcp6Key = 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
    $exportTcp = Invoke-NativeCommand -FilePath $reg -Arguments @('export', $tcpKey, $script:TrxpTcpBackupFile, '/y')
    $exportTcp6 = Invoke-NativeCommand -FilePath $reg -Arguments @('export', $tcp6Key, $script:TrxpTcp6BackupFile, '/y')
    # Do not use @($planned) here: Windows PowerShell 5.1 can throw
    # 'Argument types do not match' when wrapping a New-Object List[object].
    # ToArray() materializes a normal object[] reliably.
    $backup = $planned.ToArray()
    $backupJson = ConvertTo-Json -InputObject ([object[]]$backup) -Depth 8
    Set-Content -LiteralPath $script:TrxpSettingBackupFile -Value $backupJson -Encoding UTF8

    $applied = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    $changedAdapters = New-Object System.Collections.Generic.List[string]
    foreach ($item in $planned) {
        try {
            Set-NetAdapterAdvancedProperty -Name $item.Name -DisplayName $item.DisplayName -DisplayValue $item.TargetDisplayValue -NoRestart -ErrorAction Stop
            $applied.Add("$($item.Name): $($item.DisplayName)=Disabled")
            $changedAdapters.Add($item.Name)
        } catch { $failed.Add("$($item.Name): $($item.DisplayName) — $($_.Exception.Message)") }
    }

    $netsh = Join-Path $env:WINDIR 'System32\netsh.exe'
    $tcpCommands = @(
        [pscustomobject]@{ Args=[string[]]@('int','tcp','set','global','rsc=disabled') },
        [pscustomobject]@{ Args=[string[]]@('int','tcp','set','global','rss=enabled') },
        [pscustomobject]@{ Args=[string[]]@('int','tcp','set','global','autotuninglevel=normal') },
        [pscustomobject]@{ Args=[string[]]@('int','tcp','set','global','timestamps=disabled') },
        [pscustomobject]@{ Args=[string[]]@('int','tcp','set','global','netdma=disabled') },
        [pscustomobject]@{ Args=[string[]]@('int','tcp','set','global','chimney=disabled') },
        [pscustomobject]@{ Args=[string[]]@('int','ip','set','global','taskoffload=disabled') }
    )
    foreach ($command in $tcpCommands) {
        $cmdArgs = [string[]]$command.Args
        $cmdDisplay = 'netsh ' + ($cmdArgs -join ' ')
        try { $null = Invoke-NativeCommand -FilePath $netsh -Arguments $cmdArgs; $applied.Add($cmdDisplay) }
        catch { $failed.Add($cmdDisplay + ' — ' + $_.Exception.Message) }
    }
    try { Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Enable-NetAdapterRss -ErrorAction Stop | Out-Null } catch { $failed.Add('Enable-NetAdapterRss — ' + $_.Exception.Message) }
    foreach ($name in @($changedAdapters | Select-Object -Unique)) { try { Restart-NetAdapter -Name $name -Confirm:$false -ErrorAction Stop } catch { $failed.Add("รีสตาร์ต Adapter $name ไม่สำเร็จ: $($_.Exception.Message)") } }

    $message = "Setting TRXP เสร็จ: ทำคำสั่งสำเร็จ $($applied.Count) รายการ; สำรองค่า Adapter และ TCP/IP ไว้แล้ว."
    if ($skipped.Count) { $message += " ข้ามค่าที่ไดรเวอร์ไม่รองรับ $($skipped.Count) รายการ." }
    if ($failed.Count) { $message += " มีรายการไม่สำเร็จ $($failed.Count) รายการ: " + ($failed -join ' | ') }
    $message += ' อาจตัดการเชื่อมต่อชั่วคราว และค่าบางรายการเป็น legacy/ไม่รองรับใน Windows บางรุ่น; ไม่รับประกัน Ping/FPS.'
    return $message
}

function Restore-SettingTRXPNetwork {
    if (-not (Test-Path -LiteralPath $script:TrxpSettingBackupFile -PathType Leaf)) { throw 'ไม่พบข้อมูลสำรอง Setting TRXP; ต้องใช้ Setting TRXP ก่อนจึงจะมีค่าที่คืนได้' }
    $items = @(Get-Content -LiteralPath $script:TrxpSettingBackupFile -Raw -Encoding UTF8 | ConvertFrom-Json)
    if ($items.Count -eq 0) { throw 'ข้อมูลสำรอง Setting TRXP ว่างหรืออ่านไม่ได้' }
    $restored = 0; $failed = New-Object System.Collections.Generic.List[string]; $affected = New-Object System.Collections.Generic.List[string]
    foreach ($item in $items) {
        try {
            if ([string]::IsNullOrWhiteSpace([string]$item.Name) -or [string]::IsNullOrWhiteSpace([string]$item.DisplayName)) { throw 'ข้อมูลสำรองไม่ถูกต้อง' }
            $vals = @($item.RegistryValue | ForEach-Object { [string]$_ })
            Set-NetAdapterAdvancedProperty -Name ([string]$item.Name) -RegistryKeyword ([string]$item.RegistryKeyword) -RegistryValue ([string[]]$vals) -NoRestart -ErrorAction Stop
            $restored++; $affected.Add([string]$item.Name)
        } catch { $failed.Add("$($item.Name) / $($item.DisplayName): $($_.Exception.Message)") }
    }
    $reg = Get-RegExePath
    foreach ($file in @($script:TrxpTcpBackupFile,$script:TrxpTcp6BackupFile)) {
        if (Test-Path -LiteralPath $file -PathType Leaf) {
            try { $null = Invoke-NativeCommand -FilePath $reg -Arguments @('import',$file) }
            catch { $failed.Add("คืน TCP/IP จาก $([IO.Path]::GetFileName($file)) ไม่สำเร็จ: $($_.Exception.Message)") }
        }
    }
    foreach ($name in @($affected | Select-Object -Unique)) { try { Restart-NetAdapter -Name $name -Confirm:$false -ErrorAction Stop } catch { $failed.Add("รีสตาร์ต $name ไม่สำเร็จ: $($_.Exception.Message)") } }
    if ($failed.Count -eq 0) {
        Remove-Item -LiteralPath $script:TrxpSettingBackupFile,$script:TrxpTcpBackupFile,$script:TrxpTcp6BackupFile -Force -ErrorAction SilentlyContinue
        return "คืนค่า Setting TRXP สำเร็จ $restored รายการ และนำเข้า TCP/IP registry backup แล้ว แนะนำรีสตาร์ต Windows เพื่อให้ค่า TCP/IP มีผลครบ"
    }
    throw "คืนค่า Setting TRXP ได้ $restored รายการ แต่มีปัญหา $($failed.Count) รายการ; เก็บข้อมูลสำรองไว้. $($failed -join ' | ')"
}

function Flush-DnsResolverCache {
    $file = Join-Path $env:WINDIR 'System32\ipconfig.exe'
    $result = Invoke-NativeCommand -FilePath $file -Arguments @('/flushdns')
    $line = (([string]$result.Output).Trim() -replace '\s+', ' ')
    if ([string]::IsNullOrWhiteSpace($line)) { $line = 'Windows DNS Resolver Cache ถูกล้างแล้ว' }
    return "Flush DNS สำเร็จ: $line"
}

function Get-RAMMapPath {
    foreach ($name in @('RAMMap64.exe','RAMMap64a.exe','RAMMap.exe')) {
        $file = Join-Path $script:DashboardRoot $name
        if (Test-Path -LiteralPath $file -PathType Leaf) { return $file }
    }
    return $null
}

function Open-RAMMap {
    $file = Get-RAMMapPath
    if (-not $file) { Start-Process $script:RamMapOfficialUrl; return 'ไม่พบ RAMMap ในโฟลเดอร์โปรแกรม จึงเปิดหน้า Microsoft Sysinternals ให้ดาวน์โหลด' }
    Start-Process -FilePath $file | Out-Null
    return 'เปิด RAMMap แล้ว หากเป็นครั้งแรกให้ยอมรับ EULA ในหน้าต่าง RAMMap'
}

function Clear-RAMMapStandbyList {
    $file = Get-RAMMapPath
    if (-not $file) { throw 'ไม่พบ RAMMap; ใช้ปุ่มเปิด RAMMap เพื่อดาวน์โหลดจากหน้า Microsoft ก่อน' }
    $proc = Start-Process -FilePath $file -ArgumentList '-accepteula -Et' -PassThru -Wait -WindowStyle Hidden -ErrorAction Stop
    if ($proc.ExitCode -ne 0) { throw "RAMMap คืน ExitCode $($proc.ExitCode); ตรวจสอบว่าไฟล์ถูกบล็อกหรือไม่" }
    return 'ส่งคำสั่งล้าง Standby List ผ่าน RAMMap แล้ว; Windows จะสร้างแคชใหม่ตามการใช้งาน ซึ่งไม่ใช่การเพิ่ม RAM จริง'
}

function Clear-TempJunk {
    $candidates = @($env:TEMP, $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Temp' }), $(if ($env:WINDIR) { Join-Path $env:WINDIR 'Temp' }))
    $allowed = @{}
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace([string]$candidate)) { continue }
        try {
            $full = [IO.Path]::GetFullPath([string]$candidate).TrimEnd('\')
            $root = [IO.Path]::GetPathRoot($full).TrimEnd('\')
            if ($full -and $full -ne $root -and (Test-Path -LiteralPath $full -PathType Container)) { $allowed[$full] = $true }
        } catch { }
    }
    if ($allowed.Count -eq 0) { return 'ไม่พบโฟลเดอร์ Temp มาตรฐานที่ล้างได้' }
    $removed = 0; $failed = 0; $bytes = 0L
    foreach ($tempPath in $allowed.Keys) {
        try { $items = @(Get-ChildItem -LiteralPath $tempPath -Force -ErrorAction Stop) } catch { $failed++; continue }
        foreach ($item in $items) {
            try {
                $isReparsePoint = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
                if ($isReparsePoint) {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                } else {
                    if (-not $item.PSIsContainer) { try { $bytes += [long]$item.Length } catch { } }
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                $removed++
            } catch { $failed++ }
        }
    }
    $mb = [Math]::Round($bytes / 1MB, 1)
    return "ล้าง Temp เสร็จแล้ว: ลบรายการสำเร็จ $removed รายการ, ข้าม/ลบไม่ได้ $failed รายการ; ประเมินขนาดไฟล์เดี่ยวที่ลบได้ประมาณ $mb MB. ไม่แตะ Downloads, Documents หรือ Recycle Bin"
}

function Clear-FiveMCache {
    $dataRoot = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app\data'
    if (-not (Test-Path -LiteralPath $dataRoot -PathType Container)) { throw "ไม่พบ FiveM data ที่ตำแหน่งมาตรฐาน: $dataRoot" }
    $cleared = New-Object System.Collections.Generic.List[string]
    $failed = 0; $removed = 0
    foreach ($name in @('cache','server-cache','server-cache-priv')) {
        $path = Join-Path $dataRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
        $resolvedData = [IO.Path]::GetFullPath($dataRoot).TrimEnd('\') + '\'
        $resolvedPath = [IO.Path]::GetFullPath($path)
        if (-not $resolvedPath.StartsWith($resolvedData,[StringComparison]::OrdinalIgnoreCase)) { throw 'พบพาธ cache อยู่นอกโฟลเดอร์ FiveM data จึงหยุดเพื่อความปลอดภัย' }
        try {
            foreach ($item in @(Get-ChildItem -LiteralPath $resolvedPath -Force -ErrorAction Stop)) {
                try {
                    $isReparsePoint = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
                    if ($isReparsePoint) { Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop }
                    else { Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop }
                    $removed++
                } catch { $failed++ }
            }
            $cleared.Add($name)
        } catch { $failed++ }
    }
    if ($cleared.Count -eq 0 -and $failed -eq 0) { return 'ไม่พบ cache folder ที่ต้องล้าง' }
    return "ล้าง FiveM cache แล้ว: $($cleared -join ', '); ลบรายการสำเร็จ $removed, ลบไม่ได้ $failed. ปิด FiveM ก่อนล้าง และไฟล์บางส่วนอาจดาวน์โหลดใหม่"
}

function Get-FiveMIniPath {
    if ([string]::IsNullOrWhiteSpace([string]$env:LOCALAPPDATA)) {
        throw 'ไม่พบตัวแปร LOCALAPPDATA ของผู้ใช้ปัจจุบัน'
    }
    $appFolder = Join-Path ([string]$env:LOCALAPPDATA) 'FiveM\FiveM.app'
    if (-not (Test-Path -LiteralPath $appFolder -PathType Container)) {
        throw "ไม่พบโฟลเดอร์ FiveM.app ที่ตำแหน่งมาตรฐาน: $appFolder`nเปิด FiveM อย่างน้อยหนึ่งครั้ง หรือตรวจสอบตำแหน่งติดตั้งก่อน"
    }
    return (Join-Path $appFolder 'CitizenFX.ini')
}

function Set-FiveMIniSectionKey([System.Collections.Generic.List[string]]$Lines, [string]$Section, [string]$Key, [string]$Value) {
    $sectionStart = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match ('^\s*\[' + [regex]::Escape($Section) + '\]\s*$')) { $sectionStart = $i; break }
    }
    if ($sectionStart -lt 0) {
        if ($Lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Lines[$Lines.Count - 1])) { $Lines.Add('') }
        $Lines.Add("[$Section]")
        $sectionStart = $Lines.Count - 1
    }
    $sectionEnd = $Lines.Count
    for ($i = $sectionStart + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\[[^\]]+\]\s*$') { $sectionEnd = $i; break }
    }
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*(?:=|\s)'
    $matchingLineIndexes = New-Object System.Collections.Generic.List[int]
    for ($i = $sectionStart + 1; $i -lt $sectionEnd; $i++) {
        if ($Lines[$i] -match $pattern) { $matchingLineIndexes.Add([int]$i) }
    }
    if ($matchingLineIndexes.Count -gt 0) {
        $Lines[$matchingLineIndexes[0]] = "$Key=$Value"
        for ($j = $matchingLineIndexes.Count - 1; $j -ge 1; $j--) { $Lines.RemoveAt($matchingLineIndexes[$j]) }
    } else {
        $Lines.Insert($sectionEnd, "$Key=$Value")
    }
}

function Apply-FiveMConfig {
    $iniPath = Get-FiveMIniPath
    $iniExisted = Test-Path -LiteralPath $iniPath -PathType Leaf
    $backupPath = $null
    if ($iniExisted) {
        $backupPath = $iniPath + '.BYTRXP-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff')
        Copy-Item -LiteralPath $iniPath -Destination $backupPath -ErrorAction Stop
    }

    try {
        $lines = New-Object System.Collections.Generic.List[string]
        if ($iniExisted) {
            $readLines = [IO.File]::ReadAllLines($iniPath, [System.Text.Encoding]::UTF8)
            foreach ($line in $readLines) { $lines.Add([string]$line) }
        }

        # Keep the documented [Game] keys and also write the user's requested
        # custom sections verbatim as INI key=value pairs. FiveM may ignore keys
        # that are not documented/supported by the client.
        $groups = [ordered]@{
            'Game' = [ordered]@{
                'UpdateChannel' = 'production'
                'DisableNVSP' = '0'
                'DisableCrashUpload' = '1'
                'DisableOSVersionCheck' = '0'
                'EnableFullMemoryDump' = '0'
            }
            'Renderer' = [ordered]@{
                'DisableShadowOptimizations' = 'true'
                'DisableNvLowLatency' = 'false'
                'DisableVSync' = 'true'
                'UseDirectFlip' = 'true'
                'UseGpuFlush' = 'true'
                'UseHighPrecision' = 'false'
                'UseDynamicTextureAllocator' = 'true'
                'UseShaderCache' = 'true'
                'EnablePresentationOptimizations' = 'true'
                'SwapChainUseWaitableSwapChain' = 'true'
                'EnableFramePacing' = '0'
                'DisableLatencyLimiter' = '1'
                'WaitForVBlank' = '0'
                'EnableReflex' = '1'
                'ReflexLowLatencyMode' = '2'
            }
            'System' = [ordered]@{
                'EnableCpuBoost' = 'true'
                'UseExtraThreads' = 'true'
                'EnableFileCache' = 'true'
                'DisableCpuSleep' = 'true'
            }
            'GameTweaks' = [ordered]@{
                'DisableAudioThread' = 'false'
                'UseLockFreeQueue' = 'true'
            }
            'Network' = [ordered]@{
                'cl_interp_ratio' = '1'
                'cl_interp' = '0'
                'net_thread_priority' = '1'
                'voice_sample_rate' = '24000'
                'DisablePacketThrottling' = 'true'
                'UseUdpQueue' = 'true'
                'ForceReliability' = 'false'
                'NetQueueSize' = '8192'
            }
            'Input' = [ordered]@{
                'RawMouseInput' = 'true'
                'UseRawInput' = '1'
                'DisableMouseSmoothing' = '1'
                'DisableControllerRumble' = 'true'
                'UseDirectInput' = '1'
                'InputPriority' = 'high'
                'RawInputBufferSize' = '4096'
            }
            'Streaming' = [ordered]@{
                'cl_forceStreamingPrefetch' = '0'
                'StreamerMode' = '0'
                'MinStreamingMemory' = '2048'
                'MaxStreamingRequests' = '16384'
                'MaxStreamingMemory' = '6144'
                'UseAdaptiveStreaming' = 'false'
                'HighPriorityStreaming' = '1'
            }
        }
        foreach ($section in $groups.Keys) {
            foreach ($key in $groups[$section].Keys) {
                Set-FiveMIniSectionKey -Lines $lines -Section ([string]$section) -Key ([string]$key) -Value ([string]$groups[$section][$key])
            }
        }
        [IO.File]::WriteAllLines($iniPath, $lines.ToArray(), [System.Text.UTF8Encoding]::new($false))
    } catch {
        throw "เขียน CitizenFX.ini ไม่สำเร็จ: $($_.Exception.Message)" + $(if ($backupPath) { " สำเนาไฟล์เดิม: $backupPath" } else { '' })
    }
    $backupMsg = if ($backupPath) { " สำเนาไฟล์ก่อนแก้ไขอยู่ที่ $backupPath" } else { 'ก่อนหน้านี้ยังไม่มี CitizenFX.ini จึงไม่มีไฟล์เดิมให้สำรอง' }
    return "เขียนค่า TRXP FIVEM ลง CitizenFX.ini แล้ว (รวม 7 sections: Game/Renderer/System/GameTweaks/Network/Input/Streaming).$backupMsg หมายเหตุ: คีย์ custom ที่ไม่อยู่ในเอกสาร FiveM อาจถูกละเลยและไม่รับประกันว่าจะเพิ่ม FPS หรือลด Ping."
}

function Open-FiveMIni {
    $iniPath = Get-FiveMIniPath
    if (-not (Test-Path -LiteralPath $iniPath -PathType Leaf)) { throw "ยังไม่มี CitizenFX.ini: $iniPath`nกด Apply FiveM Supported INI Settings หรือเปิด FiveM ก่อน" }
    $notepad = Join-Path $env:WINDIR 'System32\notepad.exe'
    Start-Process -FilePath $notepad -ArgumentList ('"' + $iniPath + '"') | Out-Null
    return 'เปิด CitizenFX.ini ใน Notepad แล้ว'
}

function Open-FilterKeysSetter {
    $file = Join-Path $script:DashboardRoot 'FilterKeysSetter.exe'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw 'ไม่พบ FilterKeysSetter.exe ในโฟลเดอร์นี้' }
    Start-Process -FilePath $file | Out-Null
    return 'เปิด FilterKeysSetter แล้ว (เป็นเครื่องมือ Filter Keys/คีย์บอร์ด ไม่ใช่ตัวปรับ double-click เมาส์)'
}

function Restore-AllBackups {
    $done = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $script:DriverBackupFile) { try { $done.Add((Restore-RegistryValueBackup -BackupPath $script:DriverBackupFile -Label 'Mouse/Keyboard Driver REG')) } catch { $failed.Add($_.Exception.Message) } }
    if (Test-Path -LiteralPath $script:UserBackupFile) { try { $done.Add((Restore-RegistryValueBackup -BackupPath $script:UserBackupFile -Label 'Mouse/Keyboard FAST settings')) } catch { $failed.Add($_.Exception.Message) } }
    if (Test-Path -LiteralPath $script:PowerBackupFile) { try { $done.Add((Restore-TRXPPowerPlan)) } catch { $failed.Add($_.Exception.Message) } }
    if (Test-Path -LiteralPath $script:NetworkBackupFile) { try { $done.Add((Restore-NetworkAdapterSettings)) } catch { $failed.Add($_.Exception.Message) } }
    if (Test-Path -LiteralPath $script:TrxpSettingBackupFile) { try { $done.Add((Restore-SettingTRXPNetwork)) } catch { $failed.Add($_.Exception.Message) } }
    if ($done.Count -eq 0 -and $failed.Count -eq 0) { throw 'ไม่พบข้อมูลสำรองของ BY TRXP จึงไม่มีค่าที่โปรแกรมนี้สามารถคืนให้ได้' }
    $message = 'คืนค่าสำเร็จ: ' + $(if ($done.Count) { $done -join ' | ' } else { 'ไม่มี' })
    if ($failed.Count) { $message += ' | มีปัญหา (เก็บไฟล์สำรองไว้): ' + ($failed -join ' | ') }
    $message += ' หากเปลี่ยนค่า Driver REG ให้รีสตาร์ต Windows'
    return $message
}

function Get-PCSpecifications {
    # Read-only inventory. Do not include serial numbers, usernames, or other identifiers.
    $windows = 'อ่านข้อมูล Windows ไม่สำเร็จ'
    $windowsVersion = 'ไม่ทราบ'
    $cpuName = 'อ่านข้อมูล CPU ไม่สำเร็จ'
    $cpuCoreThread = 'ไม่ทราบ'
    $ramSummary = 'อ่านข้อมูล RAM ไม่สำเร็จ'
    $motherboard = 'ไม่พบข้อมูลเมนบอร์ด'
    $gpuNames = @()
    $storageNames = @()
    $networkLines = @()

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($os.Caption) { $windows = [string]$os.Caption }
        $arch = [string]$os.OSArchitecture
        $windowsVersion = ('Version {0} · Build {1} · {2}' -f [string]$os.Version, [string]$os.BuildNumber, $arch)
        try {
            $freeGB = [math]::Round(([double]$os.FreePhysicalMemory * 1KB) / 1GB, 1)
        } catch { $freeGB = $null }
    } catch { $freeGB = $null }

    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $totalGB = [math]::Round(([double]$computer.TotalPhysicalMemory) / 1GB, 1)
        if ($null -ne $freeGB) { $ramSummary = ('{0} GB total · {1} GB available' -f $totalGB, $freeGB) }
        else { $ramSummary = ('{0} GB total' -f $totalGB) }
    } catch { }

    try {
        $processors = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | ForEach-Object { $_ })
        $names = @($processors | ForEach-Object { ([string]$_.Name).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        if ($names.Count -gt 0) { $cpuName = $names -join ' / ' }
        $cores = 0; $threads = 0
        foreach ($processor in $processors) {
            if ($null -ne $processor.NumberOfCores) { $cores += [int]$processor.NumberOfCores }
            if ($null -ne $processor.NumberOfLogicalProcessors) { $threads += [int]$processor.NumberOfLogicalProcessors }
        }
        if ($cores -gt 0 -or $threads -gt 0) { $cpuCoreThread = ('{0} cores · {1} threads' -f $cores, $threads) }
    } catch { }

    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | ForEach-Object { $_ })
        $gpuNames = @($gpus | ForEach-Object { ([string]$_.Name).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    } catch { $gpuNames = @() }

    try {
        $boards = @(Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop | ForEach-Object { $_ })
        $boardParts = @()
        foreach ($board in $boards) {
            $part = @()
            if (-not [string]::IsNullOrWhiteSpace([string]$board.Manufacturer)) { $part += [string]$board.Manufacturer }
            if (-not [string]::IsNullOrWhiteSpace([string]$board.Product)) { $part += [string]$board.Product }
            if ($part.Count -gt 0) { $boardParts += ($part -join ' ') }
        }
        if ($boardParts.Count -gt 0) { $motherboard = ($boardParts | Select-Object -Unique) -join ' / ' }
    } catch { }

    try {
        $disks = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop | ForEach-Object { $_ } | Select-Object -First 8)
        $storageList = @()
        foreach ($disk in $disks) {
            $model = [string]$disk.Model
            if ([string]::IsNullOrWhiteSpace($model)) { $model = [string]$disk.Caption }
            $sizeLabel = 'ขนาดไม่ทราบ'
            if ($null -ne $disk.Size -and [double]$disk.Size -gt 0) { $sizeLabel = ('{0} GB' -f [math]::Round(([double]$disk.Size) / 1GB, 0)) }
            if (-not [string]::IsNullOrWhiteSpace($model)) { $storageList += ($model.Trim() + ' · ' + $sizeLabel) }
        }
        $storageNames = @($storageList)
    } catch { $storageNames = @() }

    try {
        $nics = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' } | ForEach-Object { $_ })
        $netItems = @()
        foreach ($nic in $nics) {
            $line = [string]$nic.Name
            if (-not [string]::IsNullOrWhiteSpace([string]$nic.InterfaceDescription)) { $line += ' · ' + [string]$nic.InterfaceDescription }
            if (-not [string]::IsNullOrWhiteSpace([string]$nic.LinkSpeed)) { $line += ' · ' + [string]$nic.LinkSpeed }
            $netItems += $line
        }
        $networkLines = @($netItems)
    } catch { $networkLines = @() }

    return [pscustomobject]@{
        windows = [string]$windows
        windowsVersion = [string]$windowsVersion
        cpu = [string]$cpuName
        cpuCoreThread = [string]$cpuCoreThread
        ram = [string]$ramSummary
        gpu = [string[]]@($gpuNames)
        motherboard = [string]$motherboard
        storage = [string[]]@($storageNames)
        network = [string[]]@($networkLines)
    }
}

function Get-DashboardStatus {
    $plan = $null; $planError = $null
    try { $plan = Get-ActivePowerPlan } catch { $planError = $_.Exception.Message }
    return [pscustomobject]@{
        isAdmin = (Test-IsAdministrator)
        activePowerPlan = $(if ($plan) { $plan.Name } else { 'อ่านไม่ได้' })
        activePowerPlanGuid = $(if ($plan) { $plan.Guid } else { '' })
        powerPlanError = $planError
        trxpPowerPlanExists = [bool](Get-TRXPPowerPlanGuid)
        driverBackupAvailable = (Test-Path -LiteralPath $script:DriverBackupFile -PathType Leaf)
        userBackupAvailable = (Test-Path -LiteralPath $script:UserBackupFile -PathType Leaf)
        powerBackupAvailable = (Test-Path -LiteralPath $script:PowerBackupFile -PathType Leaf)
        ramMapAvailable = [bool](Get-RAMMapPath)
        networkBackupAvailable = (Test-Path -LiteralPath $script:NetworkBackupFile -PathType Leaf)
        trxpSettingBackupAvailable = (Test-Path -LiteralPath $script:TrxpSettingBackupFile -PathType Leaf)
        fiveMIniPath = (Join-Path (Join-Path ([string]$env:LOCALAPPDATA) 'FiveM\FiveM.app') 'CitizenFX.ini')
        fiveMAppAvailable = (Test-Path -LiteralPath (Join-Path ([string]$env:LOCALAPPDATA) 'FiveM\FiveM.app') -PathType Container)
        fiveMIniExists = (Test-Path -LiteralPath (Join-Path (Join-Path ([string]$env:LOCALAPPDATA) 'FiveM\FiveM.app') 'CitizenFX.ini') -PathType Leaf)
        fiveMIniBackupAvailable = [bool](Get-ChildItem -LiteralPath (Split-Path -Parent (Join-Path (Join-Path ([string]$env:LOCALAPPDATA) 'FiveM\FiveM.app') 'CitizenFX.ini')) -Filter 'CitizenFX.ini.BYTRXP-backup-*' -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        activeNetworkAdapters = @((Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty Name))
        pcSpecs = (Get-PCSpecifications)
        driverRegFilesAvailable = ((Test-Path -LiteralPath $script:MouseRegFile -PathType Leaf) -and (Test-Path -LiteralPath $script:KeyboardRegFile -PathType Leaf))
        filterKeysAvailable = (Test-Path -LiteralPath (Join-Path $script:DashboardRoot 'FilterKeysSetter.exe') -PathType Leaf)
    }
}

function Invoke-AllowedAction([string]$Action) {
    switch ($Action) {
        'status' { return [pscustomobject]@{ Message='สถานะอัปเดตแล้ว'; Status=(Get-DashboardStatus); StopServer=$false } }
        'applyDriverReg' { $m = Apply-DriverReg; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'restoreDriverReg' { $m = Restore-RegistryValueBackup -BackupPath $script:DriverBackupFile -Label 'Mouse/Keyboard Driver REG'; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'applyUserMouseKeyboard' { $m = Apply-UserMouseKeyboard; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'restoreUserMouseKeyboard' { $m = Restore-RegistryValueBackup -BackupPath $script:UserBackupFile -Label 'Mouse/Keyboard FAST settings'; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'enablePowerPlan' { $m = Enable-TRXPPowerPlan; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'restorePowerPlan' { $m = Restore-TRXPPowerPlan; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'applyNetwork' { $m = Apply-NetworkAdapterOptimizer; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'applySettingTRXP' { $m = Apply-SettingTRXPNetwork; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'restoreSettingTRXP' { $m = Restore-SettingTRXPNetwork; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'restoreNetwork' { $m = Restore-NetworkAdapterSettings; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'flushDns' { $m = Flush-DnsResolverCache; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'openRamMap' { $m = Open-RAMMap; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'clearStandby' { $m = Clear-RAMMapStandbyList; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'cleanTemp' { $m = Clear-TempJunk; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'clearFiveMCache' { $m = Clear-FiveMCache; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'applyFiveMConfig' { $m = Apply-FiveMConfig; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'openFiveMIni' { $m = Open-FiveMIni; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'openFilterKeys' { $m = Open-FilterKeysSetter; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'restoreAll' { $m = Restore-AllBackups; return [pscustomobject]@{ Message=$m; StopServer=$false } }
        'stopServer' { return [pscustomobject]@{ Message='ปิด Local Web Dashboard แล้ว'; StopServer=$true } }
        default { throw 'คำสั่งนี้ไม่อยู่ในรายการที่อนุญาต' }
    }
}

# Random per-launch secret prevents unrelated local websites from invoking the API.
$randomBytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes); $rng.Dispose()
$script:Token = [Convert]::ToBase64String($randomBytes).Replace('+','-').Replace('/','_').TrimEnd('=')

$listener = New-Object System.Net.HttpListener
$port = 0
for ($candidate = 18735; $candidate -le 18755; $candidate++) {
    try {
        $listener.Prefixes.Clear()
        $listener.Prefixes.Add("http://127.0.0.1:$candidate/")
        $listener.Start()
        $port = $candidate
        break
    } catch { try { $listener.Stop() } catch { } }
}
if ($port -eq 0) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('เปิด Local Web Dashboard ไม่สำเร็จ เพราะพอร์ต 18735–18755 ใช้งานไม่ได้ ลองปิดโปรแกรมที่เปิดค้างแล้วเริ่มใหม่', 'BY TRXP Dashboard', 'OK', 'Error') | Out-Null
    exit 1
}
$baseUrl = "http://127.0.0.1:$port"
Write-Log "Dashboard started on $baseUrl; admin=$(Test-IsAdministrator)"

function Write-HttpResponse($Context, [int]$Status, [string]$ContentType, [byte[]]$Bytes) {
    $response = $Context.Response
    $response.StatusCode = $Status
    $response.ContentType = $ContentType
    $response.ContentEncoding = [Text.Encoding]::UTF8
    $response.ContentLength64 = $Bytes.Length
    $response.Headers['Cache-Control'] = 'no-store'
    $response.Headers['X-Content-Type-Options'] = 'nosniff'
    $response.Headers['Referrer-Policy'] = 'no-referrer'
    if ($ContentType -like 'text/html*') {
        $response.Headers['Content-Security-Policy'] = "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
    }
    try { $response.OutputStream.Write($Bytes,0,$Bytes.Length) } finally { try { $response.OutputStream.Close() } catch { } }
}

function Open-DashboardBrowser([string]$Url) {
    $paths = New-Object System.Collections.Generic.List[string]
    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $pf = [Environment]::GetEnvironmentVariable('ProgramFiles')
    foreach ($candidate in @(
        $(if ($pf86) { Join-Path $pf86 'Microsoft\Edge\Application\msedge.exe' }),
        $(if ($pf) { Join-Path $pf 'Microsoft\Edge\Application\msedge.exe' }),
        $(if ($pf86) { Join-Path $pf86 'Google\Chrome\Application\chrome.exe' }),
        $(if ($pf) { Join-Path $pf 'Google\Chrome\Application\chrome.exe' })
    )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { $paths.Add([string]$candidate) }
    }
    if ($paths.Count -gt 0) { Start-Process -FilePath $paths[0] -ArgumentList $Url | Out-Null }
    else { Start-Process -FilePath $Url | Out-Null }
}

try { Open-DashboardBrowser -Url ($baseUrl + '/') } catch { Write-Log "Browser launch error: $($_.Exception.Message)" }

$shouldStop = $false
while ($listener.IsListening -and -not $shouldStop) {
    $context = $null
    try { $context = $listener.GetContext() } catch { break }
    try {
        $request = $context.Request
        $path = $request.Url.AbsolutePath
        # Reject anything that did not reach the loopback listener address directly.
        if ($request.Url.Host -ne '127.0.0.1' -or $request.Url.Port -ne $port -or $request.RemoteEndPoint.Address.ToString() -ne '127.0.0.1') {
            Write-HttpResponse $context 403 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Forbidden'))
            continue
        }
        if ($request.HttpMethod -eq 'GET' -and $path -eq '/') {
            $htmlPath = Join-Path $script:DashboardRoot 'dashboard.html'
            if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) { throw 'ไม่พบ dashboard.html ในโฟลเดอร์โปรแกรม' }
            $html = [IO.File]::ReadAllText($htmlPath,[Text.Encoding]::UTF8).Replace('__TRXP_TOKEN__',$script:Token).Replace('__TRXP_PORT__',[string]$port)
            Write-HttpResponse $context 200 'text/html; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes($html))
            continue
        }
        if ($request.HttpMethod -eq 'GET' -and $path -match '^/assets/(BY_TRXP_Background|BY_TRXP_Banner)\.png$') {
            $name = [IO.Path]::GetFileName($path)
            $assetPath = Join-Path (Join-Path $script:DashboardRoot 'assets') $name
            if (Test-Path -LiteralPath $assetPath -PathType Leaf) {
                Write-HttpResponse $context 200 'image/png' ([IO.File]::ReadAllBytes($assetPath))
            } else { Write-HttpResponse $context 404 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Not found')) }
            continue
        }
        if ($path -eq '/api/action') {
            if ($request.HttpMethod -ne 'POST') { Write-HttpResponse $context 405 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('{"ok":false,"message":"Method not allowed"}')); continue }
            $origin = [string]$request.Headers['Origin']
            $auth = [string]$request.Headers['X-TRXP-Token']
            if ($origin -ne $baseUrl -or $auth -cne $script:Token) {
                Write-Log "Blocked API request: origin='$origin', ip=$($request.RemoteEndPoint.Address)"
                Write-HttpResponse $context 403 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('{"ok":false,"message":"คำขอถูกปฏิเสธ: origin/token ไม่ถูกต้อง"}'))
                continue
            }
            $reader = New-Object System.IO.StreamReader($request.InputStream,$request.ContentEncoding)
            try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($body.Length -gt 8192) { Write-HttpResponse $context 413 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('{"ok":false,"message":"Request too large"}')); continue }
            try {
                $data = $body | ConvertFrom-Json
                $action = [string]$data.action
                $confirmActions = @('applyDriverReg','restoreDriverReg','applyUserMouseKeyboard','restoreUserMouseKeyboard','enablePowerPlan','restorePowerPlan','applyNetwork','restoreNetwork','applySettingTRXP','restoreSettingTRXP','flushDns','clearStandby','cleanTemp','clearFiveMCache','applyFiveMConfig','restoreAll','stopServer')
                if ($action -in $confirmActions -and $data.confirmed -ne $true) { throw 'คำสั่งนี้ต้องยืนยันจากหน้า Dashboard ก่อน' }
                $result = Invoke-AllowedAction -Action $action
                Write-Log "Action '$action' succeeded."
                # Status refresh must not turn an otherwise successful action into a non-JSON/failed response.
                $statusPayload = $null
                if ($null -ne $result.Status) { $statusPayload = $result.Status }
                else { try { $statusPayload = Get-DashboardStatus } catch { Write-Log "Could not refresh dashboard status: $($_.Exception.Message)" } }
                $payload = [ordered]@{ ok=$true; message=[string]$result.Message; status=$statusPayload; stopServer=[bool]$result.StopServer }
                $json = ConvertTo-Json -InputObject $payload -Depth 7 -Compress
                Write-HttpResponse $context 200 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes([string]$json))
                if ($result.StopServer) { $shouldStop = $true }
            } catch {
                Write-Log "Action '$action' failed: $($_.Exception.Message) | $($_.ScriptStackTrace)"
                $failureMessage = [string]$_.Exception.Message
                # Do not run more system queries in the error handler; always return a compact JSON error.
                $payload = [ordered]@{ ok=$false; message=$failureMessage; status=$null; stopServer=$false }
                $json = ConvertTo-Json -InputObject $payload -Depth 7 -Compress
                Write-HttpResponse $context 500 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes([string]$json))
            }
            continue
        }
        Write-HttpResponse $context 404 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Not found'))
    } catch {
        $handlerError = [string]$_.Exception.Message
        Write-Log "HTTP handler error: $handlerError"
        try {
            if ($null -ne $context -and $context.Request.Url.AbsolutePath -eq '/api/action') {
                $jsonMessage = ConvertTo-Json -InputObject $handlerError -Compress
                $jsonError = '{"ok":false,"message":' + [string]$jsonMessage + ',"status":null}'
                Write-HttpResponse $context 500 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes([string]$jsonError))
            } else {
                Write-HttpResponse $context 500 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Internal server error'))
            }
        } catch { try { $context.Response.Abort() } catch { } }
    }
}
try { $listener.Stop(); $listener.Close() } catch { }
Write-Log 'Dashboard stopped.'
exit 0
