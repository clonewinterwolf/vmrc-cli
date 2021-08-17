<#
    .Synopsis
    Function to open VM consolue using the VMware Remote Console Application
    .Description 
     Open virtual machine console of a VM maching vmname parameter in all existing vcenter sessions in $defaultviservers
     Use open-myvmconsolewindow function to fix issue that Virtual CDrom grey out when using $vmfound|Open-VMConsoleWindow
    .Example
    .\vmrc-cli.ps1 <vm name> <vcenter name> 
    .Parameter vCenter
    Name of Vcenter
    .Parameter vmname
    Name of virtual machine. recommend to include wild char * to get list of vmname*
    .Example 
    .\vmrc-cli.ps1 rvrwpd* rvrwpdvc01
    .notes
    vmrc-cli 
    version: 2.0
    author: Zichuan Yang
    Create date: 24/04/2019
    Last modified: 18/08/2021
    Requirement: PowerCLI 6.0 or above; VMware Remote Console version 8 or above
    Usage vmrc-cli.ps1 <vcenter name> <VM name pattern>    
#>

Param(     
    [Parameter(Mandatory=$true)][string]$vmname,
    [Parameter(Mandatory=$false)][string]$vCenter="rvvc01"
)

function Open-MyVMConsoleWindow {
    <#
        .Synopsis
        Function to replicate Open-VMConsoleWindow but use the VMware Remote Console Application
        .Description 
        Connect to the virtual machine using the currently connected server object.
        .Example
        Get-VM "MyVM" | Open-MyVMConsoleWindow
        .Parameter VirtualMachine
        Virtual Machine object
        .notes
        csdibiase 2016 https://communities.vmware.com/thread/539980 
        PowerCLI 5.5R1: Open-VMConsoleWindow
    #>
        [CmdletBinding()]
        param ( 
            [Parameter(Mandatory=$true,ValueFromPipeline=$True)]
            [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$vm
        )
        process {
            #$vm|fl
            $vi=$vm.Uid.Substring($vm.Uid.IndexOf('@')+1).Split(":")[0]
            $ServiceInstance = Get-View -Id ServiceInstance -Server $vi
            $SessionManager  = Get-View -Id $ServiceInstance.Content.SessionManager -Server $vi
            #$ticket = $SessionManager.acquireCloneTicket();
            #$SessionManager.AcquireCloneTicket()
            #write-host "Current Session is " $SessionManager.currentSession.key  $SessionManager.currentSession.loginTime
            $vmrcURI = "vmrc://clone:" + ($SessionManager.AcquireCloneTicket()) + "@" + $vi + "/?moid=" + $vm.ExtensionData.MoRef.Value
            Start-Process -FilePath $vmrcURI    
        }
    }

$certaction = get-PowerCLIConfiguration -scope User
if($certaction.InvalidCertificateAction -ne "Ignore")
{
    write-host "set certificate action to Ignore:"
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
}

#connect to vcenter if $defaultviservers has no existing session for vcenter or the session is no conncted 
if ( !$DefaultViServers -or !$DefaultVIServers.Name.Contains($vCenter))
{
    write-host  "$vCenter authentication..."
    Connect-VIServer -Server $vCenter -Protocol https -ErrorAction Stop    
}else
{
    $index=$DefaultVIServers.Name.Indexof($vCenter)
    write-host $DefaultVIServers[$index].name $DefaultVIServers[$index].isconnected
    if($DefaultVIServers[$index].isconnected)
    {
        write-host "Use existing session for " $DefaultVIServers[$index].Name " " $DefaultVIServers[$index].SessionId
    }else
    {
        Connect-VIServer -Server $vCenter -Protocol https -ErrorAction Stop  
    }
}

$vmfound=Get-VM $vmname
if($vmfound.count -ge 1)
{   
    $vmdisplay=$vmfound|Foreach-Object{ $index = 0 } {[PSCustomObject] @{ Index = $index; Object = $_ }; $index++}
    $vmdisplay|select-object -property index,@{Label="Guest";Expression={$_.object.guest}},@{Label="PowerState";Expression={$_.object.PowerState}},@{Label="VC";Expression={$_.object.Uid.Substring($_.object.Uid.IndexOf('@')+1).Split(":")[0]}}|Format-Table -autosize
    $vmindex_select=-1
    while(($vmindex_select -lt 0) -or ($vmindex_select -gt ($vmfound.count-1)))
    {
        $vmindex_select=read-host "Enter VM index (0 to" ($vmfound.count-1)") or -1 to quit"
        $vmindex_select=[int]::Parse($vmindex_select)
        if($vmindex_select -lt 0)
        {
            write-host "Operation cancelled" -ForegroundColor Green 
            exit
        }
    }
    $vmdisplay[$vmindex_select].object|select name,powerstate,numCpu,MemoryGB|ft -AutoSize
    write-host "Open VM remote console:" $vmdisplay[$vmindex_select].Object -ForegroundColor Green 
    $vmdisplay[$vmindex_select].object|Open-MyVMConsoleWindow
    #$vmfound[$vmindex_select]|Open-VMConsoleWindow
}