<#
    .Synopsis
    Function to show VM information
    .Description 
    disply infomraiton  of a VM. 
    .Example
    .\get-vminfo.ps1 <VM name pattern> <vcenter name>
     .Parameter vmname
    Name of virtual machine. recommend to include wild char * to get list of vmname*     
    .Parameter vCenter
    Name of Vcenter
    .Example 
    .\get-vminfo.ps1 rvrwpd* rvrwpdvc01 
    .notes
    get-vmnetinfo.ps1
    Author: Zichuan Yang
    Ceated date: May 2019
    modified date: 11-08-2019
    description 
    to get VM information including netowrk adapter if vm hardware version support vm.extensiondata 
    Requirement: PowerCLI 6.0 or above; VMware Remote Console version 8 or above
    Usage get-vminfo.ps1 <VM name pattern> <vcenter name>     
#>

Param(     
    [Parameter(Mandatory=$true)][string]$vmname,
    [Parameter(Mandatory=$false)][string]$vCenter="rvgartvc01"
)

$certaction = get-PowerCLIConfiguration -scope User
if($certaction.InvalidCertificateAction -ne "Ignore")
{
    write-host "set certificate action to Ignore:"
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
}

#Use 
if ( !$DefaultViServers -or !$DefaultVIServers.Name.Contains($vCenter))
{
    write-host  "$vCenter authentication..."
    Connect-VIServer -Server $vCenter -Protocol https -ErrorAction Stop    
}else
{
    $index=$DefaultVIServers.Name.Indexof($vCenter)
    if($DefaultVIServers[$index].isconnected)
    {
        write-host "Existing session for " $DefaultVIServers[$index].Name " " $DefaultVIServers[$index].SessionId
    }else
    {
        Connect-VIServer -Server $vCenter -Protocol https -ErrorAction Stop  
    }
}

$vmlist=get-vm $vmname
foreach ($vm in $vmlist)
{
    #$vm.guest|fl
    $vmview=$vm|Get-View
    #check VirtualUSBController is added to the VM
    $VM_usbcontroller=$vmview|Where-Object { $_.Config.Hardware.Device.Where({$_.gettype().name -match 'VirtualUSBController'})}
    #$vmview.Config.Hardware.Device
    $vm|Select-Object @{N="VM";E={$vm.Name}},
                #@{N="Domain";E={$domain=$VM.Guest.HostName -Split'\.' 
                #   ($Domain[1..($Domain.Count)] -Join'.').ToLower()}},
                @{N="OS Hostname";E={$VM.Guest.HostName}},                    
                @{N="UUID";E={(get-view $vm.id).config.uuid}},
                @{N='PowerState';E={$vm.PowerState}},
                @{N='Host Cluster';E={$vm.VMHost.Parent}},                
                @{N='Host';E={$vm.Uid.Substring($vm.Uid.IndexOf('@')+1).Split(":")[0]+"\"+$vm.VMHost.Name}},
                @{N='vCore';E={$vmview.Config.Hardware.NumCPU}},                
                @{N='CoresPerSocket';E={$vmview.Config.Hardware.NumCoresPerSocket}},
                @{N='vSocket';E={$vmview.Config.Hardware.NumCPU/$vmview.Config.Hardware.NumCoresPerSocket}},
                #@{N='CPUs';E={$vm.NumCpu}},
                @{N='Memory GB';E={$vm.MemoryGB}},
                @{N='VirtualUSBController';E={($VM_usbcontroller.count -ge 1)}},                
                @{N='HardwareVersion';E={$vm.HardwareVersion}},                                
                @{N='OS';E={$vm.Guest.OSFullName}},
                @{N='VM Size GB';E={[math]::Round($vm.ProvisionedSpaceGB,2)}},
                @{N='Folder';E={$vm.Folder}},
                @{N='ResourcePool';E={$vm.ResourcePool}},
                @{N='Tools';E={$vm.ExtensionData.Guest.ToolsRunningStatus}},
                @{N='IP Address';E={[string]::Join(',',($_.Guest.IPAddress | Where {($_.Split(".")).length -eq 4}))}},
                @{N='DNS';E={[string]::Join(',',$_.ExtensionData.Guest.net.dnsconfig.IpAddress)}},
                @{N='Gateway';E={[string]::Join(',',($vm.ExtensionData.Guest.IpStack.IpRouteConfig.IpRoute | %{if($_.Gateway.IpAddress){$_.Gateway.IpAddress}}))}}|out-host

    $htadapter=@{}#hashtable to held networkadapters using mac address as key
    get-networkadapter $vm|%{$htadapter.add($_.MacAddress,$_)}
    $vmnetlist= $vm.ExtensionData.Guest.Net 
    #obtain VM network information
    Foreach ($vmnet in $vmnetlist)
    {   
        #$vmnet|select MacAddress
        #$vmnet.IpConfig|fl
        write-host "Adapter Name: " $htadapter[$vmnet.MacAddress].Name|format-table
        write-host "Adapter Type: " $htadapter[$vmnet.MacAddress].Type
        write-host "Status      : " $htadapter[$vmnet.MacAddress].ConnectionState
        write-host "Mac Address : " $vmnet.MacAddress
        write-host "Network     : " $vmnet.Network
        write-host "DHCP        : " $vmnet.IpConfig.Dhcp.Ipv4.Enable
        $str_ipaddr=""
        foreach($ipaddr in $vmnet.IpConfig.IpAddress)
        {
            $str_ipaddr=$str_ipaddr+$ipaddr.ipAddress+'/'+$ipaddr.PrefixLength+";"
        }
        
        $str_dnsip=""
        foreach($dnsconfig in $vmnet.DnsConfig)
        {
            $str_dnsip=$str_dnsip+$dnsconfig.ipAddress+";"
        }
        write-host "IP          : " $str_ipaddr
        write-host "DNS         : " $str_dnsip
        write-host "------------------------------------------------"        
    }    
    
    #obtain VM vmdk information
    $array_vmdk= @() 
    Get-HardDisk -VM $vm | ForEach-Object {
        $HardDisk = $_
        $hdFileKeys = $HardDisk.Parent.ExtensionData.LayoutEx.Disk | Where-Object{$_.Key -eq $HardDisk.ExtensionData.Key};
        $files = $HardDisk.Parent.ExtensionData.LayoutEx.File | where-object{$hdFileKeys.Chain[0].FileKey -contains $_.Key};
        $used = ($files | Measure-Object -Property Size -sum | select-object -ExpandProperty Sum)/1GB
        $dcontroller =get-scsicontroller -HardDisk $HardDisk
        $objvmdk =New-Object PSObject -Property @{
            HardDisk= $HardDisk.Name;
            VMXpath = $HardDisk.FileName;
            ProvisionType = $HardDisk.StorageFormat;
            #DiskType = $HardDisk.get_DiskType();
            CapacityGB = ("{0:f1}" -f ($HardDisk.CapacityGB));
            ThinUsage=[math]::Round($used/$HardDisk.CapacityGB*100,1); #show actual thin provisioned vmdk usage comparing to provisioned size 
            Controller=$dcontroller.Type.tostring().Substring(7)
        }
        $array_vmdk+=$objvmdk

    }
    $array_vmdk|select-object HardDisk,VMXpath,ProvisionType,CapacityGB,ThinUsage,Controller|format-table -AutoSize|out-host
    write-host "VM Snapshots - - - - - - - - - - - - - - - - - - - - - - - - -"  -ForegroundColor green

    $vm|get-snapshot|select-object name,@{N="SIZEGB";E={($_.SizeGB).tostring("#.##")}},Created,CreatedBy,description| format-table -AutoSize
    write-host "* * * * * * * * * * * * * * * * * * * * * * * * * * * *"  -ForegroundColor green
}# $vm in $vmlist

