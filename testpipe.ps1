function get-vminfo
{
    [CmdletBinding()]
    Param(     
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string[]]$vmname,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string[]]$vcenter

    )
    begin{
        write-host "call bengin block"
        $vminfoList = [System.Collections.ArrayList]@()
    }
 
    #process block
    process {
        write-host "call process block $vmname in $vcenter"
        $vminfoList.Add($vmname)
        # $vm in $vmlist
    } #end of process block
    
    end {
        write-host "call end block"
        write-host $vminfoList
    }
 
}

$vmhashtable = @(
    [pscustomobject]@{
        'vmname'='vm01'
        'vcenter'='vcenter01'
    }
    [pscustomobject]@{
        'vmname'='vm02'
        'vcenter'='vcenter02'
    }

)
$vmhashtable|get-vminfo