#vmrc-cli
#version 1.0
#author: Zichuan Yang
#Create date: 24/04/2019
#Last modified: 24/05/2019
#PowerCLI 6.0 or above
#PowerShell Version 4.0 or above
#VMware Remote Console version 8 or above

#PowerCLI 6.0 or above
#PowerShell Version 4.0 or above
#VMware Remote Console version 8 or above

#const


Param(     
    [Parameter(Mandatory=$true)][string]$vCenter="vc01",
    [Parameter(Mandatory=$true)][string]$vmname
)
$MAXSESSTIONIDLEHOUR=1
$scriptstarttime=get-date

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
    
    $visession=Connect-VIServer -Server $vCenter -Protocol https -ErrorAction Stop
    #$sessionexpire=$sessionstart.addhours($MAXSESSTIONIDLEHOUR)
    $objsession = New-Object PSObject -Property @{VISession=$visession;SessionLastUse=$scriptstarttime}
    write-host $global:vcsessionlist[$vCenter].VIsession.User " -- "  $objsession.SessionLastUse 
    $global:vcsessionlist[$vCenter]=$objsession

}else
{
    write-host "$vCenter" $scriptstarttime "-" $global:vcsessionlist[$vCenter].SessionLastUse
    #write-host "$scriptstarttime -lt $global:vcsessionlist[$vCenter].SessionLastUse.addhours($MAXSESSTIONIDLEHOUR)"
    if(($scriptstarttime -gt $global:vcsessionlist[$vCenter].SessionLastUse.addhours($MAXSESSTIONIDLEHOUR))) #session expiry reached
    {
        write-host $global:vcsessionlist[$vCenter].VIsession.User "Re-logging on $vCenter..."
        #$visession=Connect-VIServer -Server $vCenter -Protocol https
        $callcommand = ".\disconnect-vcsessions.ps1 -vCenter $vCenter"
        $callcommand
        #invoke-expression -Command $callcommand
        <#
        $objsession = New-Object PSObject -Property @{VISession=$vsession;SessionLastUse=$scriptstarttime}
        $global:vcsessionlist[$vCenter]=$objsession
        write-host $global:vcsessionlist[$vCenter].User " -- " $global:vcsessionlist[$vCenter].SessionLastUse
        #>
    }else {
        write-host $vsession.User "Using existing session $vCenter... " $global:vcsessionlist[$vCenter].SessionId "sessionlastuse updated"
        $global:vcsessionlist[$vCenter].SessionLastUse=$scriptstarttime
    }
}

   
#$testvm="VM-NETTEST-01" #prt test vm
#$testvm="tdcvts"

try
{
    $vmfound=Get-VM $vmname -ErrorAction Stop
    if($vmfound.count -eq 1)
    {
        $vmfound
        write-host "open vm console: $vmfound" -ForegroundColor Green 
        $vmfound|Open-VMConsoleWindow
    }elseif($vmfound.count -gt 1)
    {   

        $vmdisplay=$vmfound|Foreach-Object{ $index = 0 } {[PSCustomObject] @{ Index = $index; Object = $_ }; $index++}
        $vmdisplay|select-object -property index,@{Label="Guest";Expression={$_.object.guest}},@{Label="PowerState";Expression={$_.object.PowerState}}|Format-Table -autosize       
        $vmindex_select=-1
        while(($vmindex_select -lt 0) -or ($vmindex_select -gt ($vmfound.count-1)))
        {

            $vmindex_select=read-host "Enter VM index (0 to" ($vmfound.count-1) "). -1 to quit"
            $vmindex_select=[int]::Parse($vmindex_select)
            if($vmindex_select -lt 0)
            {
                write-host "Operation cancelled" -ForegroundColor Green 
                exit
            }
        }
        get-vm $vmfound[$vmindex_select]|select name,powerstate,numCpu,MemoryGB|ft -AutoSize
        write-host "Open VM remote console:" $vmfound[$vmindex_select] -ForegroundColor Green 
    
        $vmfound[$vmindex_select]|Open-VMConsoleWindow
    }
    #do nothing if $vmfound.count <=0
}Catch
{
    write-host "VM $vmname not exist in $vCenter" 
}


#write-host "Logout Vcenter session"
#Disconnect-VIServer -Server $vCenter -Confirm:$false
## Get VM to verify its part of the specified vCenter

#get-vm -Name​​ $vmname|select​​ Name,​​ PowerState,​​ NumCpu,​​ MemoryGB,​​ Version,​​ @{N="Cluster";E={Get-Cluster​​ -VM​​ $_}},​​ VMHost​​ |​​ ft​​ -a​​ 
## Now run below command to open the VMRC in fullscreen mode
#Open-VMConsoleWindow -VM​​ $vmname​ -FullScreen​​ # Or use below
#Disconnect-VIServer​​ $vCentersvm  