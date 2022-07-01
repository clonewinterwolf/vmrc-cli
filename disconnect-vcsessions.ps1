#VMware Remote Console version 8 or above
#disconnect all vicenter in $global:visessionlist

Param(     
    [Parameter(Mandatory=$false)][string]$vCenter="all"
)

write-host "Log out $vCenter"
if($vCenter.ToLower() -eq "all")
{
    $vclist=$global:vcsessionlist.clone()
    foreach($vserver in $vclist.keys)
    {
        write-host "Disconnect " $vserver
        disconnect-viserver -server $vserver -Confirm:$true
        $global:vcsessionlist.Remove($vserver)
    }

}else{
    disconnect-viserver -server $vcenter -Confirm:$true
    $global:vcsessionlist.Remove($vserver)
}

