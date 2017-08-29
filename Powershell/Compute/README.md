# Get-HPOVservertelemetry
   This PowerShell function provides average power consumption, CPU utilization and Temperature report from a Compute Module. 
     
   _Example of the statistics output:_   
   
   ![](https://user-images.githubusercontent.com/13134334/29814096-72ed6360-8cac-11e7-8212-7af50ca4cb30.png)   
   
## Download

### [Click here to download the function (right click to save)](https://github.com/jullienl/OneView-demos/blob/master/Powershell/Compute/Get-HPOVservertelemetry.ps1)

   
## Parameter `IP`
  IP address of the Composer   
  Default: 192.168.1.110
  
## Parameter `username`
  OneView administrator account of the Composer   
  Default: Administrator
  
## Parameter `password`
  password of the OneView administrator account    
  Default: password
  
## Parameter `profile`
  Name of the server profile   
  This is normally retrieved with a 'Get-HPOVServerProfile' call like '(get-HPOVServerProfile).name'
  
## Example
  ```sh
  PS C:\> Get-HPOVservertelemetry -IP 192.168.1.110 -username Administrator -password password -profile "W2016-1" 
  ```
  Provides average power consumption, CPU utilization and Temperature report for the compute module using the server profile "W2016-1"
  
## Component
  This script makes use of the PowerShell language bindings library for HPE OneView   
  https://github.com/HewlettPackard/POSH-HPOneView