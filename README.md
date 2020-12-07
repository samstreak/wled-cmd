# wled-cmd.ps1
Simple Windows Powershell interface for WLED devices

# requirements
Powershell 4? (needs version verification/testing)
# usage
```
powershell ./wled-cmd.ps1 192.168.1.147 on
powershell ./wled-cmd.ps1192.168.1.147 brightness 128
powershell ./wled-cmd.ps1192.168.1.147 cycle (this one cycles through a list of effects in the script)
powershell ./wled-cmd.ps1192.168.1.147 fx 68
powershell ./wled-cmd.ps1192.168.1.147 status
powershell ./wled-cmd.ps1192.168.1.147 off
```
