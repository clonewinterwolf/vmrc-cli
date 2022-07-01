<#
    .Synopsis
    Function to show VM information
    .Description 
    disply infomraiton of VMs in a csv file 
    .Example
    .\get-vminfofromfile.ps1 <file with list of vm names> <vcenter name>
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
    [Parameter(Mandatory=$true)][string]$vmlistfile,
    [Parameter(Mandatory=$false)][string]$vCenter="vc01"
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
if(!(Test-Path $vmlistfile))
{
    write-host "File not exist error!" -ForegroundColor Red
    exit
}
$vmnamelist = Get-Content $vmlistfile
$array_vm= @() 
$array_vmnotfoud= @()
$totalDatasizeGB=0.0
$totalVMs=0
$totalVMnotFound=0
$minVMnameLength=2
foreach($vmname in $vmnamelist)
{

    if(($vmname.length -lt $minVMnameLength) -or ($vmname -eq "*")) #skip VMname like "*" or vmname is too short.  
    {
        write-host "$vmname is not a suitable for search. Skip " -ForegroundColor Red
        continue
    }
    $vmname=$vmname.Trim()+"*"
    $vmlist=get-vm $vmname
    $vmmeasure=$vmlist|measure-object
    write-host -nonewLine "Searching VM $vmname ..." 
    if($vmmeasure.count -le 0)
    {   
        write-host "False" -ForegroundColor Red 
        $totalVMnotFound++
        $array_vmnotfoud+= $vmname
    }else
    {
        write-host "True (" $vmmeasure.count ")" -ForegroundColor green  #show number of vms found from the search criteria
    }
  
    foreach ($vm in $vmlist)
    {
        #$vm.guest|fl
        $vmview=$vm|Get-View
        $objvm =New-Object PSObject -Property @{
            VMName= $vm.Name;
            ServerName = $VM.Guest.HostName;
            VMHost =$vm.Uid.Substring($vm.Uid.IndexOf('@')+1).Split(":")[0]+"\"+$vm.VMHost.Name;     
            OS = $vm.Guest.OSFullName;
            PowerState = $vm.PowerState;
            HardwareVer=$vm.HardwareVersion;
            VMtoolVer=$vm.Guest.toolsVersion;
            vCore=$vmview.Config.Hardware.NumCPU;
            MemoryGB = $vm.MemoryGB;
            RPool=$vm.ResourcePool;
            VMSizeGB=[math]::Round($vm.ProvisionedSpaceGB,2);
            VMfolder=$vm.Folder;
            #IPs=[string]::Join(',',($vm.Guest.IPAddress | Where-object {($_.Split(".")).length -eq 4}));
            IPs=[string]$vm.Guest.IPAddress[0];   
            #IP2=[string]$vm.Guest.IPAddress[2];   
            NUM_IPs=$vm.Guest.IPAddress.Count;
            Vcenter=$vm.Uid.Substring($vm.Uid.IndexOf('@')+1).Split(":")[0];           
        }

        $vmnetlist= $vm.ExtensionData.Guest.Net
        Foreach($vmnet in $vmnetlist)
        {
            foreach($ipaddr in $vmnet.IpConfig.IpAddress)
            {
                
                if($ipaddr.IpAddress -eq $vm.Guest.IPAddress[0])
                {
                    write-host "check" $ipaddr.IpAddress.tostring() "-" $vm.Guest.IPAddress[0]
                    $objvm|Add-Member -NotePropertyMembers @{NetName=$vmnet.Network}
                }
            }

        }
            #obtain VM vmdk information RawPhysical
        $isVSA='Ready'
        $objvm|Add-Member -NotePropertyMembers @{VSAReady=$isVSA}
        Get-HardDisk -VM $vm | ForEach-Object {
            $HardDisk = $_
            $disktype=$HardDisk.DiskType.toString()
            if($disktype -like 'RawPhysical')
            {
                $isVSA='Failed (RDM)'
                $objvm.VSAReady= $isVSA 
            }
        }
    
        $vmsnapshots=$vm|get-snapshot
        $objvm|Add-Member -NotePropertyMembers @{Snapshots=$vmsnapshots.count}
   
        #summary
        $totalDatasizeGB+=[math]::Round($vm.ProvisionedSpaceGB,2)
        $array_vm+=$objvm
        $totalVMs++
    }# $vm in $vmlist
}
#$array_vm|select-object VMName,ServerName,OS,PowerState,VMSizeGB,IPs,NUM_IPs,VSAReady,HardwareVer,VMtoolVer|format-table -AutoSize|Out-host
#$array_vm|select-object VMName,ServerName,OS,PowerState,VMSizeGB,IPs,VSAReady,VMfolder,Snapshots,VMHost|format-table -AutoSize|Out-host
$array_vm|select-object VMName,ServerName,OS,PowerState,VMSizeGB,IPs,NUM_IPs,VSAReady,Snapshots,VMHost|format-table -AutoSize|Out-host

#$array_vm|select-object VMName,ServerName,PowerState,VMSizeGB,IPs,NUM_IPs,VSAReady,NetName,Snapshots,VMHost|format-table -AutoSize|Out-host
write-host "Number of VMs: $totalVMs"
write-host "Number of VMs not found: $totalVMnotFound"
write-host "Total VM Size (GB): $totalDatasizeGB"

$array_vmnotfoud
