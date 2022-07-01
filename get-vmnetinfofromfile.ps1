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
$array_vmnotfound= @()
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
        $array_vmnotfound+= $vmname
    }else
    {
        write-host "True (" $vmmeasure.count ")" -ForegroundColor green  #show number of vms found from the search criteria
    }
  
    foreach ($vm in $vmlist)
    {
        #$vm.guest|fl

        $vmnetlist= $vm.ExtensionData.Guest.Net
        $htadapter=@{}#hashtable to held networkadapters using mac address as key
        get-networkadapter $vm|foreach-object{$htadapter.add($_.MacAddress,$_)}
        Foreach($vmnet in $vmnetlist)
        {
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

            $objvm =New-Object PSObject -Property @{
                    VMName= $vm.Name;
                    ServerName = $VM.Guest.HostName;
                    RPool=$vm.ResourcePool;
                    VMfolder=$vm.Folder; 
                    NUM_IPs=$vm.Guest.IPAddress.Count;
                    #Adapter = $htadapter[$vmnet.MacAddress].Name|format-table
                    Network =  $vmnet.Network
                    NetworkStatus =  $htadapter[$vmnet.MacAddress].ConnectionState
                    IP = $str_ipaddr
                    DNS = $str_dnsip
            }
            $array_vm += $objvm
            $totalVMs ++
        }    

    }# $vm in $vmlist
}
#$array_vm|select-object VMName,ServerName,OS,PowerState,VMSizeGB,IPs,NUM_IPs,VSAReady,HardwareVer,VMtoolVer|format-table -AutoSize|Out-host
#$array_vm|select-object VMName,ServerName,OS,PowerState,VMSizeGB,IPs,VSAReady,VMfolder,Snapshots,VMHost|format-table -AutoSize|Out-host
$array_vm|select-object VMName,ServerName,NUM_IPs,Network,NetworkStatus,IP,DNS|format-table -AutoSize|Out-host

#$array_vm|select-object VMName,ServerName,PowerState,VMSizeGB,IPs,NUM_IPs,VSAReady,NetName,Snapshots,VMHost|format-table -AutoSize|Out-host
write-host "Number of VMs: $totalVMs"
write-host "Number of VMs not found: $totalVMnotFound"

$array_vmnotfound
