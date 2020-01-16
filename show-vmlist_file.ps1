<#
    .Synopsis
    Function to show VM information
    .Description 
    disply infomraiton  of a VM. 
    .Example
    .\get-vminfofromlist.ps1 <file to list of vms> <vcenter name>
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
    [Parameter(Mandatory=$false)][string]$vCenter="rvvc01"
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

$totalDatasizeGB=0.0
$totalVMs=0

foreach($vmname in $vmnamelist)
{
    if(($vmname.length -lt $minVMnameLength) -or ($vmname -eq "*")) #skip VMname like "*" or vmname is too short.  
    {
        write-host "$vmname is not a suitable for search. Skip " -ForegroundColor Red
        continue
    }
    $vmname=$vmname+"*" #add wild char for more search return
    $vmlist=get-vm $vmname
    $vmmeasure=$vmlist|measure
    write-host -nonewLine "Searching VM $vmname ..." 
    if($vmmeasure.count -le 0)
    {   
        write-host "False" -ForegroundColor Red 
    }else
    {
        write-host "True (" $vmmeasure.count ")" -ForegroundColor green #show number of vms found from the search criteria 
    }
    foreach ($vm in $vmlist)
    {
        #$vm.guest|fl
        $vmview=$vm|Get-View
        $objvm =New-Object PSObject -Property @{
            VMName= $vm.Name;
            ServerName = $VM.Guest.HostName;
            OS = $vm.Guest.OSFullName;
            PowerState = $vm.PowerState;
            HardwareVersion=$vm.HardwareVersion;
            vCore=$vmview.Config.Hardware.NumCPU;
            MemoryGB = $vm.MemoryGB;
            VMSizeGB=[math]::Round($vm.ProvisionedSpaceGB,2);
            Vcenter=$vm.Uid.Substring($vm.Uid.IndexOf('@')+1).Split(":")[0];
           # IPAddresses=[string]::Join(',',($vm.Guest.IPAddress | Where {($vm.Split(".")).length -eq 4}));
        }
        $totalDatasizeGB+=[math]::Round($vm.ProvisionedSpaceGB,2)
        $array_vm+=$objvm
        $totalVMs++
    }# $vm in $vmlist
  
}
$array_vm|select-object VMName,ServerName,OS,PowerState,HardwareVersion,vCore,MemoryGB,VMSizeGB,Vcenter|format-table -AutoSize|Out-host
write-host "Total number of VMs: $totalVMs"
write-host "Total VM Size: $totalDatasizeGB"

