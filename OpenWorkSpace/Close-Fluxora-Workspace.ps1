. "$PSScriptRoot\Workspace-Config.ps1"

$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Windows.Forms

# ==========================================
# WINDOWS API
# ==========================================

if (-not ("FluxoraWindowNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class FluxoraWindowNative {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@
}

# Separate class to avoid conflicts if the old class is already loaded.
if (-not ("FluxoraWindowStateNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class FluxoraWindowStateNative {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
}
"@
}

# Remember windows that were minimized before the script started.
$originallyMinimizedWindows = New-Object 'System.Collections.Generic.List[System.IntPtr]'

function Activate-TargetWindow {
    param([IntPtr]$Handle)

    if ($Handle -eq [IntPtr]::Zero) {
        return $false
    }

    # Restore the window if it is minimized.
    if ([FluxoraWindowStateNative]::IsIconic($Handle)) {
        if (-not $originallyMinimizedWindows.Contains($Handle)) {
            $originallyMinimizedWindows.Add($Handle)
        }

        [void][FluxoraWindowStateNative]::ShowWindow($Handle, 9)
        Start-Sleep -Milliseconds 300
    }

    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        [void][FluxoraWindowNative]::SetForegroundWindow($Handle)
        Start-Sleep -Milliseconds 150

        if ([FluxoraWindowNative]::GetForegroundWindow() -eq $Handle) {
            return $true
        }
    }

    return $false
}


# ==========================================
# SAVE ORIGINAL STATE
# ==========================================

$originalForeground = [FluxoraWindowNative]::GetForegroundWindow()

$clipboardBackup = ""
$clipboardWasText = $false

try {
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $clipboardBackup = [System.Windows.Forms.Clipboard]::GetText()
        $clipboardWasText = $true
    }
}
catch {}

# ==========================================
# CLOSE APPLICATION WINDOWS
# ==========================================

function Close-MatchingWindow {
    param(
        [string]$ProcessName,
        [scriptblock]$TitleMatch,
        [string]$Description
    )

    Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and
            (& $TitleMatch $_.MainWindowTitle)
        } |
        ForEach-Object {
           Write-Host "Closing: $Description [$($_.MainWindowTitle)]"

			$closeResult = $_.CloseMainWindow()

			if ($closeResult) {
				Write-Host "Close request accepted: $Description"
			}
			else {
				Write-Warning "Windows did not accept the close request: $Description"
			}
        }
}

# 1. VS Code frontend
if ($CloseVSCodeFrontend) {
    Close-MatchingWindow "Code" {
        param($title)
        $title -match "Fluxora" -and
        $title -notmatch "Fluxora_Backend"
    } "VS Code Fluxora frontend"
}

# 2. IntelliJ backend
#Close-MatchingWindow "idea64" {
#    param($title)
#    $title -match "Fluxora_Backend"
#} "IntelliJ Fluxora backend"
# 2. IntelliJ Fluxora project
if ($CloseIntelliJ) {
    Close-MatchingWindow "idea64" {
        param($title)
        $title -match "(?i)Fluxora"
    } "IntelliJ Fluxora project"
}

# 3. DBeaver
if ($CloseDBeaver) {
    Close-MatchingWindow "dbeaver" {
        param($title) $true
    } "DBeaver"
}

# 4. Postman
if ($ClosePostman) {
    Close-MatchingWindow "Postman" {
        param($title) $true
    } "Postman"
}

# ==========================================
# EDGE TAB CLOSING
# ==========================================

Write-Host ""
if ($CloseEdgeTabs) {
    Write-Host "========== EDGE TAB CLOSING =========="

    $targetUrls = $EdgeUrlsToClose

    function Get-EdgeTabUrl {
        try {
            [System.Windows.Forms.Clipboard]::Clear()

            [System.Windows.Forms.SendKeys]::SendWait("^l")
            Start-Sleep -Milliseconds 150

            [System.Windows.Forms.SendKeys]::SendWait("^c")

            for ($i = 0; $i -lt 15; $i++) {
                Start-Sleep -Milliseconds 100

                $url = [System.Windows.Forms.Clipboard]::GetText().Trim()

                if ($url -match '^https?://') {
                    [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
                    return $url
                }
            }
        }
        catch {
            Write-Warning "Edge clipboard error: $($_.Exception.Message)"
        }

        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        return ""
    }

    function Test-TargetEdgeUrl {
        param([string]$Url)

        try {
            $currentUri = [System.Uri]$Url

            foreach ($target in $targetUrls) {
                $targetUri = [System.Uri]$target

                if (
                    $currentUri.Scheme -ieq $targetUri.Scheme -and
                    $currentUri.Host -ieq $targetUri.Host -and
                    $currentUri.Port -eq $targetUri.Port -and
                    $currentUri.AbsolutePath.TrimEnd('/') -ieq
                        $targetUri.AbsolutePath.TrimEnd('/') -and
                    $currentUri.Query -ieq $targetUri.Query
                ) {
                    return $true
                }
            }
        }
        catch {}

        return $false
    }

    $edgeWindows = @(
        Get-Process -Name "msedge" -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } |
            Group-Object MainWindowHandle |
            ForEach-Object { $_.Group[0] }
    )

    foreach ($edge in $edgeWindows) {
        Write-Host ""
        Write-Host "Inspecting Edge window: $($edge.MainWindowHandle)"

        if (-not (Activate-TargetWindow $edge.MainWindowHandle)) {
            Write-Warning "Could not activate Edge window. Skipping."
            continue
        }

        $seenUrls = New-Object 'System.Collections.Generic.HashSet[string]' (
            [System.StringComparer]::OrdinalIgnoreCase
        )

        $targetAttempts = @{}
        $closeRequests = 0

        for ($i = 0; $i -lt 40; $i++) {

            if ([FluxoraWindowNative]::GetForegroundWindow() -ne $edge.MainWindowHandle) {
                Write-Warning "Edge lost foreground focus. Stopping this scan."
                break
            }

            $url = Get-EdgeTabUrl

            Write-Host "Inspected Edge tab: [$url]"

            if ([string]::IsNullOrWhiteSpace($url)) {
                break
            }

            $isTarget = Test-TargetEdgeUrl $url

            if ($isTarget) {

                if (-not $targetAttempts.ContainsKey($url)) {
                    $targetAttempts[$url] = 0
                }

                $targetAttempts[$url]++

                # Prevent endless attempts if a tab refuses to close.
                if ($targetAttempts[$url] -gt 3) {
                    Write-Warning "Could not close tab after 3 attempts: $url"
                    break
                }

                Write-Host "Requesting closure of Fluxora Edge tab: $url"

                [System.Windows.Forms.SendKeys]::SendWait("^{w}")
                Start-Sleep -Milliseconds 500

                $closeRequests++

                # Inspect the newly active tab.
                continue
            }

            # A previously inspected URL means we have completed a cycle.
            if ($seenUrls.Contains($url)) {
                Write-Host "Completed Edge tab scan."
                break
            }

            [void]$seenUrls.Add($url)

            [System.Windows.Forms.SendKeys]::SendWait("^{TAB}")
            Start-Sleep -Milliseconds 150
        }

        Write-Host "Edge close requests sent: $closeRequests"
    }



}

# ==========================================
# FILE EXPLORER - EXACT PATH TAB CLOSING
# ==========================================

Write-Host ""
if ($CloseExplorerTabs) {
    Write-Host "========== FILE EXPLORER TAB CLOSING =========="

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes

    $normalizedFolders = @(
        $ExplorerFoldersToClose |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object {
                [System.IO.Path]::GetFullPath($_).TrimEnd('\')
            } |
            Select-Object -Unique
    )

    function Get-ExplorerCurrentPath {
        try {
            [System.Windows.Forms.Clipboard]::Clear()
            [System.Windows.Forms.SendKeys]::SendWait("^l")
            Start-Sleep -Milliseconds 100
            [System.Windows.Forms.SendKeys]::SendWait("^c")

            for ($i = 0; $i -lt 10; $i++) {
                Start-Sleep -Milliseconds 100

                if ([System.Windows.Forms.Clipboard]::ContainsText()) {
                    $value = [System.Windows.Forms.Clipboard]::GetText().Trim().Trim('"')

                    if ($value -match '^file:') {
                        $value = ([System.Uri]$value).LocalPath
                    }

                    if (Test-Path -LiteralPath $value -PathType Container) {
                        return [System.IO.Path]::GetFullPath($value).TrimEnd('\')
                    }
                }
            }
        }
        catch {}

        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        return ""
    }

    $explorerCloseRequests = 0

    try {
        $shellApp = New-Object -ComObject Shell.Application

        $explorerHandles = @(
            $shellApp.Windows() |
                Where-Object {
                    try {
                        [System.IO.Path]::GetFileName($_.FullName) -ieq "explorer.exe"
                    }
                    catch {
                        $false
                    }
                } |
                ForEach-Object { [IntPtr]$_.HWND } |
                Sort-Object -Unique
        )

        foreach ($handle in $explorerHandles) {
            if ($handle -eq [IntPtr]::Zero) {
                continue
            }

            if (-not (Activate-TargetWindow $handle)) {
                Write-Warning "Could not activate Explorer window: $handle"
                continue
            }

            # Re-scan after every closure because UI Automation elements
            # may become stale when an Explorer tab is removed.
            for ($scan = 0; $scan -lt 10; $scan++) {
                $closedThisPass = $false

                $rootElement = [System.Windows.Automation.AutomationElement]::FromHandle($handle)

                if ($null -eq $rootElement) {
                    break
                }

                $tabCondition = [System.Windows.Automation.PropertyCondition]::new(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::TabItem
                )

                $tabElements = $rootElement.FindAll(
                    [System.Windows.Automation.TreeScope]::Descendants,
                    $tabCondition
                )

                foreach ($tab in $tabElements) {
                    try {
                        $selectionPattern = $null

                        if (-not $tab.TryGetCurrentPattern(
                            [System.Windows.Automation.SelectionItemPattern]::Pattern,
                            [ref]$selectionPattern
                        )) {
                            continue
                        }

                        # Select this candidate, even if another tab has
                        # exactly the same visible title.
                        $selectionPattern.Select()
                        $tab.SetFocus()
                        Start-Sleep -Milliseconds 150

                        $currentPath = Get-ExplorerCurrentPath

                        Write-Host "Inspected Explorer tab: [$currentPath]"

                        if ([string]::IsNullOrWhiteSpace($currentPath)) {
                            continue
                        }

                        $isTarget = $false

                        foreach ($targetPath in $normalizedFolders) {
                            if ($currentPath -ieq $targetPath) {
                                $isTarget = $true
                                break
                            }
                        }

                        if ($isTarget) {
                            Write-Host "Closing exact Fluxora Explorer tab: $currentPath"

                            [System.Windows.Forms.SendKeys]::SendWait("^{w}")
                            Start-Sleep -Milliseconds 400

                            $explorerCloseRequests++
                            $closedThisPass = $true
                            break
                        }
                    }
                    catch {
                        Write-Warning "Could not inspect an Explorer tab: $($_.Exception.Message)"
                    }
                }

                if (-not $closedThisPass) {
                    break
                }
            }
        }
    }
    catch {
        Write-Warning "Explorer UI Automation error: $($_.Exception.Message)"
    }

    Write-Host "Explorer close commands sent: $explorerCloseRequests"


}

# ==========================================
# RESTORE ORIGINAL STATE
# ==========================================

try {
    if ($clipboardWasText) {
        [System.Windows.Forms.Clipboard]::SetText($clipboardBackup)
    }
    else {
        [System.Windows.Forms.Clipboard]::Clear()
    }
}
catch {}


# Restore the window that was active before closing.
if ($originalForeground -ne [IntPtr]::Zero) {
    [void][FluxoraWindowNative]::SetForegroundWindow(
        $originalForeground
    )
}

# Return previously minimized Edge and Explorer windows
# to their original minimized state.
foreach ($handle in $originallyMinimizedWindows) {
    [void][FluxoraWindowStateNative]::ShowWindow($handle, 6)
}

Write-Host ""
Write-Host "Fluxora workspace close requests completed."

