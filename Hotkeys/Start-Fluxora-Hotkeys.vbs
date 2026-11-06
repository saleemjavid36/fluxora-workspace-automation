Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

folder = fso.GetParentFolderName(WScript.ScriptFullName)
script = folder & "\Fluxora-HotkeyManager.ps1"

powershell = shell.ExpandEnvironmentStrings( _
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" _
)

command = """" & powershell & """ -STA -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & script & """"

shell.Run command, 0, False
