
$ErrorActionPreference = "Stop"

# ==========================================
# CUSTOM SCRIPT DIRECTORIES
# ==========================================

$root = Split-Path -Parent $PSScriptRoot

$workspaceDirectory = Join-Path $root "OpenWorkSpace"

$openScript = Join-Path $workspaceDirectory "Fluxora-Workspace.ps1"
$closeScript = Join-Path $workspaceDirectory "Close-Fluxora-Workspace.ps1"

$logFile = Join-Path $root "Fluxora-HotkeyManager.log"

function Write-Log {
    param([string]$Message)

    Add-Content -LiteralPath $logFile -Value (
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    )
}

function Start-WorkspaceScript {
    param(
        [string]$ScriptPath,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Write-Log "$Description script not found: $ScriptPath"
        return
    }

    try {
        $arguments = @(
            "-NoLogo"
            "-NoProfile"
            "-STA"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            ('"{0}"' -f $ScriptPath)
        )

        $process = Start-Process `
            -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList $arguments `
            -WindowStyle Hidden `
            -PassThru

        Write-Log "$Description started. PID: $($process.Id)"
    }
    catch {
        Write-Log "$Description launch error: $($_.Exception.Message)"
    }
}

# ==========================================
# PREVENT DUPLICATE MANAGERS
# ==========================================

$createdNew = $false

$mutex = New-Object System.Threading.Mutex(
    $false,
    "Local\FluxoraHotkeyManager",
    [ref]$createdNew
)

if (-not $createdNew) {
    Write-Log "Another Hotkey Manager is already running."
    $mutex.Dispose()
    exit
}

# ==========================================
# WINDOWS HOTKEY API
# ==========================================

if (-not ("FluxoraHotkeyNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct FluxoraPoint {
    public int X;
    public int Y;
}

[StructLayout(LayoutKind.Sequential)]
public struct FluxoraMessage {
    public IntPtr HWnd;
    public uint Message;
    public UIntPtr WParam;
    public IntPtr LParam;
    public uint Time;
    public FluxoraPoint Point;
}

public static class FluxoraHotkeyNative {

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool RegisterHotKey(
        IntPtr hWnd, int id, uint modifiers, uint virtualKey);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    public static extern int GetMessage(
        out FluxoraMessage message,
        IntPtr hWnd,
        uint minFilter,
        uint maxFilter);
}
"@
}

# ==========================================
# SHORTCUT CONFIGURATION
# ==========================================

$MOD_ALT = 0x0001
$MOD_CONTROL = 0x0002
$MOD_SHIFT = 0x0004

$MODIFIERS = $MOD_ALT -bor $MOD_CONTROL -bor $MOD_SHIFT

$VK_O = 0x4F
$VK_X = 0x58
$VK_Q = 0x51

$HOTKEY_OPEN = 1
$HOTKEY_CLOSE = 2
$HOTKEY_QUIT = 3

$registered = @()

# ==========================================
# REGISTER HOTKEY
# ==========================================

function Register-FluxoraHotkey {
    param(
        [int]$Id,
        [uint32]$Modifiers,
        [uint32]$Key,
        [string]$Description
    )

    $success = [FluxoraHotkeyNative]::RegisterHotKey(
        [IntPtr]::Zero,
        $Id,
        $Modifiers,
        $Key
    )

    if (-not $success) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Failed to register $Description. Windows error code: $errorCode"
    }

    $script:registered += $Id
    Write-Log "Registered $Description successfully."
}

# ==========================================
# MAIN
# ==========================================

try {
    Write-Log "Starting Fluxora Hotkey Manager."

    if (-not (Test-Path $openScript)) {
        throw "Opening script not found: $openScript"
    }

    if (-not (Test-Path -LiteralPath $closeScript)) {
        throw "Closing script not found: $closeScript"
    }

    Write-Log "Open script: $openScript"
    Write-Log "Close script: $closeScript"

    # Ctrl + Alt + Shift + O
    Register-FluxoraHotkey $HOTKEY_OPEN $MODIFIERS $VK_O "Ctrl+Alt+Shift+O"

    # Ctrl + Alt + Shift + X
    Register-FluxoraHotkey $HOTKEY_CLOSE $MODIFIERS $VK_X "Ctrl+Alt+Shift+X"

    # Ctrl + Alt + Shift + Q
    Register-FluxoraHotkey $HOTKEY_QUIT $MODIFIERS $VK_Q "Ctrl+Alt+Shift+Q"

    Write-Log "All shortcuts registered. Manager is listening."

    # ==========================================
    # LISTEN FOR SHORTCUTS
    # ==========================================

    while ($true) {
        $message = New-Object FluxoraMessage

        $result = [FluxoraHotkeyNative]::GetMessage(
            [ref]$message,
            [IntPtr]::Zero,
            0,
            0
        )

        if ($result -le 0) {
            throw "Windows message listener stopped. Result: $result"
        }

        if ($message.Message -ne 0x0312) {
            continue
        }

        $hotkeyId = $message.WParam.ToUInt32()

        if ($hotkeyId -eq $HOTKEY_OPEN) {
            Write-Log "Opening Fluxora workspace."
            Start-WorkspaceScript $openScript "Open workspace"
        }
        elseif ($hotkeyId -eq $HOTKEY_CLOSE) {
            Write-Log "Closing Fluxora workspace."
            Start-WorkspaceScript $closeScript "Close workspace"
        }
        elseif ($hotkeyId -eq $HOTKEY_QUIT) {
            Write-Log "Stop shortcut received. Shutting down manager."
            break
        }
    }
}
catch {
    Write-Log "MANAGER ERROR: $($_.Exception.Message)"
}
finally {
    foreach ($id in $registered) {
        [void][FluxoraHotkeyNative]::UnregisterHotKey(
            [IntPtr]::Zero,
            $id
        )
    }

    $mutex.Dispose()

    Write-Log "Fluxora Hotkey Manager stopped."
}
