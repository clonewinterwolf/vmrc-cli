<#
.Synopsis
Function to get VM object in a single object
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
$vminfoList = @()
foreach ($vm in $vmlist)
{
    $vminfo = [PSCustomObject]@{
         VirtualMachine = $vm
         VMDKs = Get-HardDisk -VM $vm 
         snapshots = get-snapshot -VM $vm
    }
    $vminfoList.Add($vminfo)
}# $vm in $vmlist