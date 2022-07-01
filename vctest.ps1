#PowerCLI 6.0 or above
#PowerShell Version 4.0 or above
#VMware Remote Console version 8 or above

Param(     
    [Parameter(Mandatory=$true)][string]$vCenter="rvgartvc01",
    [Parameter(Mandatory=$true)][string]$vmname
)

$certaction = get-PowerCLIConfiguration -scope User
if($certaction.InvalidCertificateAction -ne "Ignore")
{
    write-host "set certificate action to Ignore:"
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
}
#create global hashtable to hold vc session 
if(!$global:vcsessionlist)
{
    $global:vcsessionlist=@{}
}
if (!$global:vcsessionlist[$vCenter])
{
    write-host $vsession.User "logging on $vCenter..."
    $visession=Connect-VIServer -Server $vCenter -Protocol https
    $global:vcsessionlist[$vCenter]=$visession
}else
{
    write-host $vsession.User "Using existing session $vCenter... "+$global:vcsessionlist[$vCenter].SessionId 
    $visession=Connect-VIServer -Server $vCenter -Session $global:vcsessionlist[$vCenter].SessionId
}

get-vm test*