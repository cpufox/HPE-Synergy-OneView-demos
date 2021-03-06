
<#
 
This PowerShell script collects server information managed by HPE OneView
and generate a text file report providing the following information:

-------------------------------------------------------------------------------------------------------
Report generated on 11/25/2020 13:56:08

RH75-SUT [Serial number: MXQ828048J - iLO: 192.168.0.9]: 
	Model: Synergy 480 Gen10
	Total Memory: 128GB
	Memory configuration :
		PROC 1 DIMM 10: HPE DDR4 DRAM 16GB - Part number: 840756-091
		PROC 2 DIMM 5: HPE DDR4 DRAM 16GB - Part number: 840756-091
		PROC 1 DIMM 5: HPE DDR4 DRAM 16GB - Part number: 840756-091
		PROC 2 DIMM 10: HPE DDR4 DRAM 16GB - Part number: 840756-091
		PROC 2 DIMM 3: HPE DDR4 DRAM 16GB - Part number: 840756-091
		PROC 2 DIMM 8: HPE DDR4 DRAM 16GB - Part number: 840756-091
		PROC 1 DIMM 3: HPE DDR4 DRAM 16GB - Part number: 840756-091
		PROC 1 DIMM 8: HPE DDR4 DRAM 16GB - Part number: 840756-091
	Adapters configuration :
		Synergy 3820C 10/20Gb CNA: Part number: 782833-001 - Number of ports: 5 - Position: NIC.Slot.3.1

ESX5-2.lj.lab [Serial number: MXQ828049J - iLO: 192.168.0.10]: 
	Model: Synergy 480 Gen10
	Total Memory: 256GB
	Memory configuration :
		PROC 2 DIMM 5: HPE DDR4 DRAM 64GB - Part number: 840759-091
		PROC 1 DIMM 8: HPE DDR4 DRAM 64GB - Part number: 840759-091
		PROC 2 DIMM 3: HPE DDR4 DRAM 64GB - Part number: 840759-091
		PROC 1 DIMM 10: HPE DDR4 DRAM 64GB - Part number: 840759-091
	Adapters configuration :
		Synergy 3830C 16G FC HBA: Part number: 782829-001 - Number of ports: 0 - Position: PCI.Slot.2.1
		Synergy 3820C 10/20Gb CNA: Part number: 782833-001 - Number of ports: 2 - Position: NIC.Slot.3.1
<...>

-------------------------------------------------------------------------------------------------------

Requirements:
- OneView administrator account is required. 
- HPE Oneview PowerShell library


Author: lionel.jullien@hpe.com
Date:   Nov 2020

--------------------------------------------------------------------------------------------------------

#################################################################################
#        (C) Copyright 2018 Hewlett Packard Enterprise Development LP           #
#################################################################################
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
#################################################################################
#>

# OneView Credentials and IP
$username = "Administrator" 
$password = "password" 
$IP = "192.168.1.110"

$file = "Server_HW_Report.txt"


Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Import-Module hpeoneview.530 

# Connection to the OneView / Synergy Composer
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)
Connect-OVMgmt -Hostname $IP -Credential $credentials | Out-Null

  
# Capture iLO4 and iLO5 IP adresses managed by OneView
$servers = Get-OVServer
#$servers
$iloIPs = $servers | where { $_.mpModel -eq "iLO4" -or "iLO5" } | % { $_.mpHostInfo.mpIpAddresses[1].address }
 
Foreach ($iloIP in $iloIPs) {
    
    #Capture of the SSO Session Key
    $ilosessionkey = ($servers | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | Get-OVIloSso -IloRestSession)."X-Auth-Token"
    $iloModel = $servers | where { $_.mpHostInfo.mpIpAddresses[1].address -eq $iloIP } | % mpModel
   
    #Hardware info   
    $request = Invoke-webrequest -Method GET -Uri "https://$iloIP/redfish/v1/systems/1/" -Headers @{"X-Auth-Token" = $ilosessionkey } 

    if ($request -ne $Null) {
        $hwinfo = $request.content | Convertfrom-Json
        #Hostname
        $hostname = $hwinfo.HostName 
        if ($hostname -match "host is unnamed") { $hostname = "Host is unnamed [Serial number: $($hwinfo.SerialNumber) - iLO: $iloIP]" } else { $hostname = "$($hwinfo.HostName) [Serial number: $($hwinfo.SerialNumber) - iLO: $iloIP]" }
        
        #Model
        $model = $hwinfo.Model
        
        #Total memory
        if ($iloModel -eq "ILO4") { $memoryinGB = $hwinfo.Memory.TotalSystemMemoryGB } else { $memoryinGB = $hwinfo.MemorySummary.TotalSystemMemoryGiB }

        #Memory information
        $memoryinfo = (Invoke-webrequest -Method GET -Uri "https://$iloIP/redfish/v1/Systems/1/Memory/" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
    
        $memory_data = @{}
   
        foreach ( $dimm in $memoryinfo.Members.'@odata.id') {
        
            $dimm_data = @()    
            $memorydata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$dimm" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 

            $Manufacturer = ($memorydata.Manufacturer) -replace '\s', ''
            $PartNumber = $memorydata.PartNumber
        
            if ($iloModel -eq "iLO5" -and $memorydata.status.State -eq "Enabled") {
            
                $DIMMTechnology = $memorydata.MemoryDeviceType 
                $DIMMType = $memorydata.MemoryType 
                $SizeGB = $memorydata.CapacityMiB / 1024 
                $DIMMlocator = $memorydata.DeviceLocator

                $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part number: " + $PartNumber
                $memory_data.Add($DIMMlocator, $dimm_data)
            }
            if ($iloModel -eq "iLO4") {

                $DIMMTechnology = $memorydata.DIMMTechnology
                $DIMMType = $memorydata.DIMMType
                $SizeGB = $memorydata.SizeMB / 1024
                $DIMMlocator = $memorydata.SocketLocator

                $dimm_data = $Manufacturer + " " + $DIMMTechnology + " " + $DIMMType + " " + $SizeGB + "GB" + " - Part number: " + $PartNumber
                $memory_data.Add($DIMMlocator, $dimm_data)
            }
            
            

        }

        # PCI network adapters information
        if ($iloModel -eq "ILO4") { $adaptersuri = "https://$iloIP/redfish/v1/Systems/1/NetworkAdapters/" } else { $adaptersuri = "https://$iloIP/redfish/v1/Systems/1/BaseNetworkAdapters/" }
    
        $adapterinfo = (Invoke-webrequest -Method GET -Uri $adaptersuri -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 

        $adapters_data = @{}

        foreach ($adapter in $adapterinfo.Members.'@odata.id') {
        
            $adapter_data = @()    
            $adapterdata = (Invoke-webrequest -Method GET -Uri "https://$iloIP$adapter" -Headers @{"X-Auth-Token" = $ilosessionkey }).content | Convertfrom-Json 
        
            $AdapterName = $adapterdata.Name
            $PartNumber = $adapterdata.PartNumber
            $StructuredName = $adapterdata.StructuredName
            $Numberofports = ($adapterdata.PhysicalPorts).Count

            $adapter_data = "Part number: " + $PartNumber + " - Number of ports: " + $Numberofports + " - Position: " + $StructuredName
            $adapters_data.Add($AdapterName, $adapter_data)
        }

        # Creation of the report

        "Report generated on $(get-date)" | Out-File $file -Append
        "`n" + $hostname + ": `n`tModel: " + $model + "`n`tTotal Memory: " + $memoryinGB + "GB" + "`n`tMemory configuration :"  | Out-File $file -Append
    
        ForEach ($item in $memory_data.GetEnumerator()) {
      
            "`t`t$($item.Name): $($item.Value)"  | Out-File $file -Append
        } 

        "`tAdapters configuration :"  | Out-File $file -Append

        ForEach ($item in $adapters_data.GetEnumerator()) {
      
            "`t`t$($item.Name): $($item.Value)"  | Out-File $file -Append
        } 
    }
    Else {
        write-warning "iLO $iloIP cannot be contacted !"
        
    } 

}

write-host "Hardware report has been generated in $pwd\$file" -ForegroundColor Green

Disconnect-OVMgmt

Read-Host -Prompt "Operation done ! Hit return to close" 



