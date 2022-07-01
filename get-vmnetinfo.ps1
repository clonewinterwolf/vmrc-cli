Param(     
    [Parameter(Mandatory=$true)][string]$vCenter,
    [Parameter(Mandatory=$true)][string]$vmname
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


$vm=get-vm $vmname
$vmnet= $vm.ExtensionData.Guest.Net
$dec=[Convert]::ToUInt32($(("1" * $vmnet.IpConfig.IpAddress[0].PrefixLength).PadRight(32, "0")), 2) 
#$dec
For ($i = 3; $i -gt -1; $i--)
{
    $Remainder = $dec % [Math]::Pow(256, $i)
    $subvalue=($dec - $Remainder)/[Math]::Pow(256, $i)
    $submask= $submask +$subvalue.tostring() +'.'
    $dec = $Remainder
    #write-host "reminder:" $Remainder
}
$submask=$submask.substring(0,$submask.length-1)
#$val = 0 
#$submask -split "\." | % {$val = $val * 256 + [Convert]::ToInt64($_)}
#$ipaddress=$vmnet.IpConfig.IpAddress[0].ipAddress+'/'+$vmnet.IpConfig.IpAddress[0].PrefixLength
#>
$vmnet | Select-object @{N="VM";E={$vm.Name}},MacAddress,Network, @{N="DHCP";E={$_.IpConfig.Dhcp.Ipv4.Enable}},@{N="IP";E={$_.IpConfig.IpAddress[0].ipAddress+'/'+$_.IpConfig.IpAddress[0].PrefixLength}},@{N="Submask";E={
    $dec=[Convert]::ToUInt32($(("1" * $_.IpConfig.IpAddress[0].PrefixLength).PadRight(32, "0")), 2) 
    $submask=""
    For ($i = 3; $i -gt -1; $i--)
    {
        $Remainder = $dec % [Math]::Pow(256, $i)
        $subvalue=($dec - $Remainder)/[Math]::Pow(256, $i)
        $submask= $submask +$subvalue.tostring() +'.'
        $dec = $Remainder
        #write-host "reminder:" $Remainder
    }
    $submask=$submask.substring(0,$submask.length-1)
    $submask
    
 }}
    