# =========================================================
# FLUXORA WORKSPACE - SHARED CONFIGURATION
# Edit this file to control both opening and closing.
# =========================================================

# 1. APPLICATION BEHAVIOUR
# Open = launch when opening workspace.
# Close = close when closing workspace.
$WorkspaceApps = @{
    Edge     = @{ Open = $true; Close = $true }
    DBeaver  = @{ Open = $true; Close = $true }
    OneNote  = @{ Open = $true; Close = $false } # Close logic is not implemented.
    Postman  = @{ Open = $true; Close = $true }
    VSCode   = @{ Open = $true; Close = $true }
    IntelliJ = @{ Open = $true; Close = $true }
    Explorer = @{ Open = $true; Close = $true }
}

# 2. PROJECT PATHS
$FrontendPath = "D:\01_Projects\Fluxora\FrontEnd\Fluxora"
$BackendPath  = "D:\01_Projects\Fluxora\BackEnd\Fluxora"

# 3. MICROSOFT EDGE URLS
# The open script opens these URLs; the close script closes matching tabs.
$EdgeUrls = @(
    "https://chatgpt.com/g/g-p-6a9c2047e710819197fa76a0fd6851f2-fluxora-backend/c/6a9d4d7e-4154-83e8-9fc7-5e5ad11c7392",
    "https://chatgpt.com/g/g-p-6a9c2047e710819197fa76a0fd6851f2/project?tab=sources",
    "http://localhost:3001/accounts"
)

# 4. FILE EXPLORER FOLDERS
# The open script opens these folders; the close script targets exact matches.
$ExplorerFolders = @(
    "D:\01_Projects\Fluxora\FrontEnd\Fluxora",
    "D:\01_Projects\Fluxora\BackEnd\Fluxora",
    "D:\02_Softwares",
    "D:\02_Softwares\AI"
)

# 5. EXECUTABLE AND SEARCH LOCATIONS
$EdgeExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

$DBeaverSearchRoots = @(
    "$env:ProgramFiles\DBeaver",
    "${env:ProgramFiles(x86)}\DBeaver",
    "$env:LOCALAPPDATA\Programs\DBeaver",
    "$env:LOCALAPPDATA\DBeaver"
)

$PostmanSearchRoots = @(
    "$env:LOCALAPPDATA\Postman",
    "$env:ProgramFiles\Postman"
)

$VSCodeSearchRoots = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
    "$env:ProgramFiles\Microsoft VS Code"
)

$IntelliJSearchRoots = @(
    "$env:ProgramFiles\JetBrains",
    "$env:LOCALAPPDATA\Programs\IntelliJ IDEA Community Edition",
    "$env:LOCALAPPDATA\JetBrains\Toolbox\apps"
)

$OneNotePaths = @(
    "$env:ProgramFiles\Microsoft Office\root\Office16\ONENOTE.EXE",
    "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\ONENOTE.EXE",
    "$env:ProgramFiles\Microsoft Office\Office16\ONENOTE.EXE",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ONENOTE.EXE"
)

# Compatibility variables used by the existing open/close implementations.
$OpenEdge       = [bool]$WorkspaceApps.Edge.Open
$OpenDBeaver    = [bool]$WorkspaceApps.DBeaver.Open
$OpenOneNote    = [bool]$WorkspaceApps.OneNote.Open
$OpenPostman    = [bool]$WorkspaceApps.Postman.Open
$OpenVSCode     = [bool]$WorkspaceApps.VSCode.Open
$OpenIntelliJ   = [bool]$WorkspaceApps.IntelliJ.Open
$OpenExplorer   = [bool]$WorkspaceApps.Explorer.Open

$CloseEdgeTabs       = [bool]$WorkspaceApps.Edge.Close
$CloseDBeaver        = [bool]$WorkspaceApps.DBeaver.Close
$ClosePostman        = [bool]$WorkspaceApps.Postman.Close
$CloseVSCodeFrontend = [bool]$WorkspaceApps.VSCode.Close
$CloseIntelliJ       = [bool]$WorkspaceApps.IntelliJ.Close
$CloseExplorerTabs   = [bool]$WorkspaceApps.Explorer.Close

$EdgeUrlsToClose = $EdgeUrls
$ExplorerFoldersToClose = $ExplorerFolders

# =========================================================
# END SHARED CONFIGURATION
# =========================================================
