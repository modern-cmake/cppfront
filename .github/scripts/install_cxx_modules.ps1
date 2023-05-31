# Adapted from https://github.com/actions/runner-images/issues/3949#issuecomment-1009162911

Set-Location "C:\Program Files (x86)\Microsoft Visual Studio\Installer\"
$InstallPath = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"

$componentsToAdd = @(
  "Microsoft.VisualStudio.Component.VC.Modules.x86.x64"
)
[string]$workloadArgs = $componentsToAdd | ForEach-Object {" --add " +  $_}
$Arguments = ('/c', "vs_installer.exe", 'modify', '--installPath', "`"$InstallPath`"", $workloadArgs, '--quiet', '--norestart', '--nocache')
$process = Start-Process -FilePath cmd.exe -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
if ($process.ExitCode -eq 0)
{
    Write-Host "components have been successfully added"
}
else
{
    Write-Host "components were not installed"
    exit 1
}