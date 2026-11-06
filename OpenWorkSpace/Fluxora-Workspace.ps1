. "$PSScriptRoot\Workspace-Config.ps1"

# ==========================================
# COMMON FUNCTIONS
# ==========================================

$ErrorActionPreference = "Continue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "========== $Title ==========" -ForegroundColor Cyan
}

function Find-AppExe {
    param(
        [string]$ExeName,
        [string[]]$SearchRoots
    )

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        # Search only the supplied application roots.
        $found = Get-ChildItem -LiteralPath $root -Filter $ExeName `
            -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Test-FolderPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Warning "Folder does not exist: $Path"
        return $false
    }

    return $true
}

# ==========================================
# 1. MICROSOFT EDGE
# ==========================================

if ($OpenEdge) {
    Write-Section "MICROSOFT EDGE"

    if (Test-Path -LiteralPath $EdgeExe) {
        $validUrls = @(
            $EdgeUrls | Where-Object {
                $_ -match '^https?://'
            }
        )

        if ($validUrls.Count -gt 0) {
            Write-Host "Opening $($validUrls.Count) Edge URL(s)..."
            Start-Process -FilePath $EdgeExe -ArgumentList $validUrls
        }
        else {
            Write-Warning "No valid Edge URLs are configured."
        }
    }
    else {
        Write-Warning "Microsoft Edge executable not found: $EdgeExe"
    }
}
else {
    Write-Host "Skipping Microsoft Edge."
}

# ==========================================
# 2. DBEAVER
# ==========================================

if ($OpenDBeaver) {
    Write-Section "DBEAVER"

    if (Get-Process -Name "dbeaver" -ErrorAction SilentlyContinue) {
        Write-Host "DBeaver is already running. Skipping launch."
    }
    else {
        $dbeaverExe = Find-AppExe "dbeaver.exe" $DBeaverSearchRoots

        if ($dbeaverExe) {
            Write-Host "Opening DBeaver..."
            Start-Process -FilePath $dbeaverExe
        }
        else {
            Write-Warning "DBeaver executable not found."
        }
    }
}
else {
    Write-Host "Skipping DBeaver."
}

# ==========================================
# 3. MICROSOFT ONENOTE
# ==========================================

if ($OpenOneNote) {
    Write-Section "MICROSOFT ONENOTE"

    $oneNoteRunning = Get-Process -Name "ONENOTE" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 }

    if ($oneNoteRunning) {
        Write-Host "OneNote is already running. Skipping launch."
    }
    else {
        $oneNoteExe = $OneNotePaths |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1

        if ($oneNoteExe) {
            Write-Host "Opening Microsoft OneNote..."
            Start-Process -FilePath $oneNoteExe
        }
        else {
            $oneNoteApp = Get-StartApps |
                Where-Object { $_.Name -eq "OneNote" } |
                Select-Object -First 1

            if ($oneNoteApp) {
                Start-Process explorer.exe "shell:AppsFolder\$($oneNoteApp.AppID)"
            }
            else {
                Write-Warning "OneNote installation not found."
            }
        }
    }
}
else {
    Write-Host "Skipping OneNote."
}

# ==========================================
# 4. POSTMAN
# ==========================================

if ($OpenPostman) {
    Write-Section "POSTMAN"

    if (Get-Process -Name "Postman" -ErrorAction SilentlyContinue) {
        Write-Host "Postman is already running. Skipping launch."
    }
    else {
        $postmanExe = Find-AppExe "Postman.exe" $PostmanSearchRoots

        if ($postmanExe) {
            Write-Host "Opening Postman..."
            Start-Process -FilePath $postmanExe
        }
        else {
            Write-Warning "Postman executable not found."
        }
    }
}
else {
    Write-Host "Skipping Postman."
}

# ==========================================
# 5. VISUAL STUDIO CODE - FRONTEND
# ==========================================

if ($OpenVSCode) {
    Write-Section "VISUAL STUDIO CODE"

    if (-not (Test-FolderPath $FrontendPath)) {
        Write-Warning "VS Code frontend launch skipped because the frontend path is invalid."
    }
    else {
        $codeExe = Find-AppExe "Code.exe" $VSCodeSearchRoots

        if ($codeExe) {
            Write-Host "Opening Fluxora Frontend in VS Code..."
            Start-Process -FilePath $codeExe -ArgumentList @("--new-window", $FrontendPath)
        }
        else {
            Write-Warning "VS Code executable not found."
        }
    }
}
else {
    Write-Host "Skipping VS Code."
}

# ==========================================
# 6. INTELLIJ IDEA - BACKEND
# ==========================================

if ($OpenIntelliJ) {
    Write-Section "INTELLIJ IDEA"

    if (-not (Test-FolderPath $BackendPath)) {
        Write-Warning "IntelliJ launch skipped because the backend path is invalid."
    }
    else {
        $ideaExe = Find-AppExe "idea64.exe" $IntelliJSearchRoots

        if ($ideaExe) {
            Write-Host "Opening Fluxora Backend in IntelliJ IDEA..."
            Start-Process -FilePath $ideaExe -ArgumentList @($BackendPath)
        }
        else {
            Write-Warning "IntelliJ IDEA executable not found."
        }
    }
}
else {
    Write-Host "Skipping IntelliJ IDEA."
}

# ==========================================
# 7. FILE EXPLORER - OPEN SELECTED PROJECT TABS
# ==========================================

if ($OpenExplorer) {
    Write-Section "FILE EXPLORER"

    if (-not ("ExplorerWindowActivator" -as [type])) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ExplorerWindowActivator
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr hWnd, out uint processId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(
        uint idAttach, uint idAttachTo, bool attach);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int command);

    [DllImport("user32.dll")]
    public static extern IntPtr SetFocus(IntPtr hWnd);
}
"@
    }

    $selectedFolders = @(
        $ExplorerFolders |
            Where-Object { Test-FolderPath $_ } |
            Select-Object -Unique
    )

    function Get-NormalizedFolderPath {
        param([string]$LocationUrl)

        try {
            $uri = [System.Uri]$LocationUrl
            return [System.IO.Path]::GetFullPath($uri.LocalPath).TrimEnd('\')
        }
        catch {
            return $null
        }
    }

    function Get-ExplorerFolderWindows {
        $result = @()
        $shell = New-Object -ComObject Shell.Application

        foreach ($window in $shell.Windows()) {
            try {
                if ([System.IO.Path]::GetFileName($window.FullName) -ieq "explorer.exe") {
                    $path = Get-NormalizedFolderPath $window.LocationURL

                    if ($path) {
                        $result += [PSCustomObject]@{
                            Window = $window
                            Path   = $path
                            HWND   = [IntPtr]$window.HWND
                        }
                    }
                }
            }
            catch {}
        }

        return $result
    }

    function Activate-ExplorerWindow {
        param($WindowInfo)

        $target = $WindowInfo.HWND

        if ($target -eq [IntPtr]::Zero) {
            return $false
        }

        $foreground = [ExplorerWindowActivator]::GetForegroundWindow()
        $currentThread = [ExplorerWindowActivator]::GetCurrentThreadId()

        [uint32]$foregroundProcess = 0
        [uint32]$targetProcess = 0

        $foregroundThread = [ExplorerWindowActivator]::GetWindowThreadProcessId(
            $foreground, [ref]$foregroundProcess
        )

        $targetThread = [ExplorerWindowActivator]::GetWindowThreadProcessId(
            $target, [ref]$targetProcess
        )

        try {
            if ($foregroundThread -ne 0) {
                [ExplorerWindowActivator]::AttachThreadInput(
                    $currentThread, $foregroundThread, $true
                ) | Out-Null
            }

            if ($targetThread -ne 0 -and $targetThread -ne $foregroundThread) {
                [ExplorerWindowActivator]::AttachThreadInput(
                    $currentThread, $targetThread, $true
                ) | Out-Null
            }

            [ExplorerWindowActivator]::ShowWindow($target, 9) | Out-Null
            [ExplorerWindowActivator]::BringWindowToTop($target) | Out-Null
            [ExplorerWindowActivator]::SetForegroundWindow($target) | Out-Null

            Start-Sleep -Milliseconds 500
            [ExplorerWindowActivator]::SetFocus($target) | Out-Null
            Start-Sleep -Milliseconds 300

            return (
                [ExplorerWindowActivator]::GetForegroundWindow() -eq $target
            )
        }
        finally {
            if ($targetThread -ne 0 -and $targetThread -ne $foregroundThread) {
                [ExplorerWindowActivator]::AttachThreadInput(
                    $currentThread, $targetThread, $false
                ) | Out-Null
            }

            if ($foregroundThread -ne 0) {
                [ExplorerWindowActivator]::AttachThreadInput(
                    $currentThread, $foregroundThread, $false
                ) | Out-Null
            }
        }
    }

    function Add-FolderTab {
        param(
            $WindowInfo,
            [string]$FolderPath
        )

        Write-Host "Activating Explorer window..."

        if (-not (Activate-ExplorerWindow $WindowInfo)) {
            Write-Warning "Explorer activation failed. Skipping keyboard input."
            return $false
        }

        $keyboard = New-Object -ComObject WScript.Shell

        $keyboard.SendKeys("^t")
        Start-Sleep -Milliseconds 600

        if ([ExplorerWindowActivator]::GetForegroundWindow() -ne $WindowInfo.HWND) {
            Write-Warning "Explorer lost focus. Folder navigation cancelled."
            return $false
        }

        $keyboard.SendKeys("^l")
        Start-Sleep -Milliseconds 200
        $keyboard.SendKeys($FolderPath)
        $keyboard.SendKeys("{ENTER}")

        Start-Sleep -Seconds 2
        Write-Host "Explorer tab opened: $FolderPath"

        return $true
    }

    if ($selectedFolders.Count -eq 0) {
        Write-Host "No Explorer folders selected. Skipping."
    }
    else {
        $existingWindows = @(Get-ExplorerFolderWindows)
        $anchorWindow = $null

        # Prefer reusing an Explorer window already showing one of the selected folders.
        foreach ($folder in $selectedFolders) {
            $match = $existingWindows |
                Where-Object { $_.Path -ieq $folder.TrimEnd('\') } |
                Select-Object -First 1

            if ($match) {
                $anchorWindow = $match
                break
            }
        }

        # If none of the selected folders is open, open the first one.
        if (-not $anchorWindow) {
            $firstFolder = $selectedFolders[0]
            Write-Host "Opening Explorer folder: $firstFolder"
            Start-Process explorer.exe -ArgumentList "`"$firstFolder`""
            Start-Sleep -Seconds 3

            $existingWindows = @(Get-ExplorerFolderWindows)
            $anchorWindow = $existingWindows |
                Where-Object { $_.Path -ieq $firstFolder.TrimEnd('\') } |
                Select-Object -First 1
        }

        if (-not $anchorWindow) {
            Write-Warning "Could not locate an Explorer window for the selected folders."
        }
        else {
            # Recheck the current tab set before opening each folder.
            foreach ($folder in $selectedFolders) {
                $currentWindows = @(Get-ExplorerFolderWindows)

                $alreadyOpen = $currentWindows |
                    Where-Object { $_.Path -ieq $folder.TrimEnd('\') } |
                    Select-Object -First 1

                if ($alreadyOpen) {
                    Write-Host "Explorer folder already open. Skipping: $folder"
                    continue
                }

                [void](Add-FolderTab $anchorWindow $folder)
            }
        }
    }
}
else {
    Write-Host "Skipping File Explorer."
}

# ==========================================
# COMPLETED
# ==========================================

Write-Host ""
Write-Host "Fluxora workspace launch sequence completed." -ForegroundColor Green
