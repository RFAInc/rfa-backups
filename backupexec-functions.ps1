# Copyright (c) 2016 Veritas Technologies LLC. All Rights Reserved SY39-6648-5573-26-15-5

######################### Globals #########################
$commandsToExport = '*-BE*'
$aliasesToExport = '*-BE*'
$typesToExport = Join-Path $PSScriptRoot BEMCLI.Types.ps1xml
$formatsToExport = Join-Path $PSScriptRoot BEMCLI.format.ps1xml

#######################################################################
function Get-BECommand
{
    [CmdletBinding(DefaultParameterSetName='AllCommandSet')]
	[OutputType([Object])]
    param(
        [Parameter(ParameterSetName='AllCommandSet', Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        ${Name},

        [Parameter(ParameterSetName='CmdletSet', ValueFromPipelineByPropertyName=$true)]
        [System.String[]]
        ${Verb},

        [Parameter(ParameterSetName='CmdletSet', ValueFromPipelineByPropertyName=$true)]
        [System.String[]]
        ${Noun},

        [Parameter(ParameterSetName='AllCommandSet', ValueFromPipelineByPropertyName=$true)]
        [Alias('Type')]
        [System.Management.Automation.CommandTypes]
        ${CommandType},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [System.Int32]
        ${TotalCount},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Switch]
        ${Syntax}
    )

    begin
    {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-Command', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd -Module BEMCLI.Scripts,BackupExec.Management.CLI,BackupExec.Management.CLI.PowerShell3 @PSBoundParameters}
        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    }

    process
    {
        $steppablePipeline.Process($_)
    }

    end
    {
        $steppablePipeline.End()
    }
    <#

    .ForwardHelpTargetName Get-Command
    .ForwardHelpCategory Cmdlet

    #>
}


#######################################################################
function Export-BEBackupDefinition
{
<#
	.EXTERNALHELP BackupExec.Management.CLI.Powershell3.dll-Help.xml
#>

    [CmdletBinding()]
	[OutputType([System.String])]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [BackupExec.Management.CLI.BEBackupDefinition]
        $BackupDefinition
    )
    
    
    ###############################################################################################################
    begin
    {    
        ###############################################################################################################
        $ErrorActionPreference = "Stop"
        $IndentPadding = ' ' * 4
    
        $GlobalNonParameterPropertyNames = @(
            "Id"
            "TaskType"
        )
    
        $NewBackupDefinitionCommand = Get-Command New-BEBackupDefinition
        $SelectionParameterNames = $NewBackupDefinitionCommand.Parameters.Keys | Where-Object { $_ -like "*Selection" }

        New-Variable -Name ManagementObjectsThatImportScriptDependsOn -Value @{} -Option AllScope
            
    
        ###############################################################################################################
        function IsParameterProperty
        {
            param
            (
                [Parameter(Mandatory=$true)]
                $MemberDefinition,

                $MemberValue,

                [Parameter(Mandatory=$true)]
                [System.Management.Automation.CommandInfo]
                $TargetCommand
            )

            $ret = $false

            if($TargetCommand.Parameters[($MemberDefinition.Name)])
            {
                if($null -eq $MemberValue)
                {
                    $parameterAttributes = $TargetCommand.Parameters[($MemberDefinition.Name)].Attributes
                    $validateNotNullAttributes = @(@($parameterAttributes | ForEach-Object { $_.GetType().Name }) -like "ValidateNotNull*")
                    if(-not $validateNotNullAttributes)
                    {
                        $ret = $true
                    }
                }
                else
                {
                    $ret = $true
                }
            }

            return $ret
        }


        ###############################################################################################################
        function GetManagementObjectGetCommand
        {
            param
            (
                [System.Type]
                $Type
            )        
        
            if($Type -eq [BackupExec.Management.CLI.BEManagementObject])
            {
                return
            }
        
            $ret = $null
            $typeName = $Type.Name
        
            $command = Get-Command "Get-$typeName" -ErrorAction SilentlyContinue
        
            if(-not $command)
            {
                $ret = GetManagementObjectGetCommand $Type.BaseType
            }
            else
            {
                $ret = $command.Name
            }
        
            return $ret
        }
    

        ###############################################################################################################
        function AddValueAsImportScriptDependency
        {
            param
            (
                $Value
            )
        
            if($null -ne $Value)
            {
                if($value -is [BackupExec.Management.CLI.BEManagementObject])
                {
                    $getCommand = GetManagementObjectGetCommand $value.GetType()
                    
                    if($getCommand)
                    {
                        $ManagementObjectsThatImportScriptDependsOn[$Value] = @{
                            "GetCommandName" = $getCommand
                            "ManagementObjectTypeName" = $value.GetType().Name
                        }
                    }
                }        
            }
        }
    
    
        ###############################################################################################################
        function GetScheduleParameterValue
        {
            param
            (
                [Parameter(Mandatory=$true)]
                [BackupExec.Management.CLI.BESchedule]
                $Schedule
            )
        
            if($Schedule -is [BackupExec.Management.CLI.BERunNowSchedule])
            {
                return "New-BESchedule -RunNow"
            }
        
            switch ($Schedule.RecurrenceType)
            {
                "Completed"
                {
                    return "New-BESchedule -RunNow"
                }
            
                "Once"
                {
                    return "New-BESchedule -RunOnce -StartingAt `"$($Schedule.StartDate)`""
                }
            
                "Minutely"
                {
                    return "New-BESchedule -Minutely -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"        
                }
                    
                "Hourly"
                {
                    return "New-BESchedule -Hourly -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"
                }
                    
                "Daily"
                {
                    return "New-BESchedule -Daily -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"
                }
                    
                "Weekday"
                {
                    return "New-BESchedule -Weekdays -StartingAt `"$($Schedule.StartDate)`""
                }
                    
                "Weekly"
                {
                    return "New-BESchedule -WeeklyEvery $(GetParameterPropertyValue $Schedule.DaysOfWeek) -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"
                }
                    
                "Monthly"
                {
                    return "New-BESchedule -MonthlyOnDayNumber $($Schedule.DayOfMonth) -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"
                }
                    
                "MonthlyQualifiedBy"
                {
                    return "New-BESchedule -MonthlyEvery $($Schedule.Qualifier) -Day $($Schedule.Day) -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"
                }        
            
                "Yearly"
                {
                    return "New-BESchedule -YearlyOnMonthDayNumber $($Schedule.DayOfMonth) -Month $($Schedule.Month) -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"
                }
                    
                "YearlyQualifiedBy"
                {
                    return "New-BESchedule -YearlyEvery $($Schedule.Qualifier) -Day $($Schedule.Day) -Month $($Schedule.Month) -StartingAt `"$($Schedule.StartDate)`" -Every $($Schedule.Every)"
                }        
            }
        }
    
    
        ###############################################################################################################
        function GetConvertToVirtualTargetEnvironmentValue
        {
            param
            (
                [Parameter(Mandatory=$true)]
                [BackupExec.Management.CLI.BEConvertToVirtualTargetEnvironment]
                $TargetEnvironment
            )
        
            if($TargetEnvironment -is [BackupExec.Management.CLI.BEConvertToVMwareVirtualMachineTargetEnvironment])
            {
                if($TargetEnvironment.VCenterServerName)
                {
                    $ret = "New-BEConvertToVirtualTargetEnvironment -VMwareVCenterServerName $(GetParameterPropertyValue $TargetEnvironment.VCenterServerName) -VMwareHostName $(GetParameterPropertyValue $TargetEnvironment.HostName) -VMwareDataStoreName $(GetParameterPropertyValue $TargetEnvironment.DataStoreName) -ToolsIsoPath $(GetParameterPropertyValue $TargetEnvironment.ToolsIsoPath) -LogonAccount $(GetParameterPropertyValue $TargetEnvironment.LogonAccount)"
                    
                    if($TargetEnvironment.VirtualMachineFolder)
                    {
                        $ret += " -VMwareVirtualMachineFolder $(GetParameterPropertyValue $TargetEnvironment.VirtualMachineFolder)"
                    }
                }
                else
                {
                    $ret = "New-BEConvertToVirtualTargetEnvironment -VMwareEsxServerName $(GetParameterPropertyValue $TargetEnvironment.HostName) -VMwareDataStoreName $(GetParameterPropertyValue $TargetEnvironment.DataStoreName) -ToolsIsoPath $(GetParameterPropertyValue $TargetEnvironment.ToolsIsoPath) -LogonAccount $(GetParameterPropertyValue $TargetEnvironment.LogonAccount)"
                }
            
                if($TargetEnvironment.ResourcePoolName)
                {
                    $ret += " -VMwareResourcePoolName $(GetParameterPropertyValue $TargetEnvironment.ResourcePoolName)"
                }
            
                return $ret        
            }
            else
            {
                return "New-BEConvertToVirtualTargetEnvironment -HyperVServerName $(GetParameterPropertyValue $TargetEnvironment.HyperVServerName) -HyperVDestinationPath $(GetParameterPropertyValue $TargetEnvironment.HyperVDestinationPath) -ToolsIsoPath $(GetParameterPropertyValue $TargetEnvironment.ToolsIsoPath) -LogonAccount $(GetParameterPropertyValue $TargetEnvironment.LogonAccount)"
            }
        }
    
    
        ###############################################################################################################
        function GetParameterPropertyValue
        {
            param
            (
                $Value
            )
        
            if($Value -eq $null)
            {
                return '$null'
            }
        
            if($Value -is [bool])
            {
                if($Value)
                {
                    return '$true'
                }
                else
                {
                    return '$false'
                }    
            }

            AddValueAsImportScriptDependency $Value
        
            if($Value -is [BackupExec.Management.CLI.BESchedule])
            {
                return GetScheduleParameterValue $Value
            }    
        
            if($Value -is [BackupExec.Management.CLI.BEConvertToVirtualTargetEnvironment])
            {
                return GetConvertToVirtualTargetEnvironmentValue $Value
            }
        
            if($Value -is [System.Collections.IEnumerable] -and
               -not ($Value -is [string]))
            {
				if ($Value.Count -eq 0)
				{
					return '@()'
				}

                return & {
                    $OFS = ", "
                    "$(@($Value) | ForEach-Object { GetParameterPropertyValue $_ })"
                }
            }
        
            return "`"$Value`""
        }
    
    
        ###############################################################################################################
        function GenerateParameterHashTable
        {
            param
            (
                [Parameter(Mandatory=$true)]
                $InputObject,
                
                [ScriptBlock]
                $PropertyPredicate,

                [Parameter(Mandatory=$true)]
                [System.Management.Automation.CommandInfo]
                $TargetCommand,
                
                [int]
                $IndentLevel = 0
            )
            
            
            if(-not $PropertyPredicate)
            {
                $PropertyPredicate = { $true }
            }
            
            "$($IndentPadding * $IndentLevel)@{"
            $InputObject | Get-Member -MemberType Property |
                Where-Object $PropertyPredicate |
                Where-Object { IsParameterProperty -MemberDefinition $_ -MemberValue $InputObject.($_.Name) -TargetCommand $TargetCommand } |
                ForEach-Object {
                    "$($IndentPadding * ($IndentLevel + 1))$($_.Name) = $(GetParameterPropertyValue $InputObject.($_.Name))"
                }
            "$($IndentPadding * $IndentLevel)}"
        }
    
    
        ###############################################################################################################
        function GenerateAdditionalBackup
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
                [BackupExec.Management.CLI.BEBackupTask]
                $BackupTask
            )
            
            begin
            {
                $excludeProperties = @(
                    "JobName"
                )            
            }
            
            process
            {
@"
        | ForEach-Object {
            ######################### '$($BackupTask.Name)' Options #########################
            `$backupTaskParameters =``
"@
                GenerateParameterHashTable $BackupTask -IndentLevel 3 { $excludeProperties -notcontains $_.Name } -TargetCommand (Get-Command "Add-BEFullBackupTask")
@"
        
            `$_ | Add-BEFullBackupTask @backupTaskParameters
        }``
"@    
            }
            
            end
            {
            }
        }


        ###############################################################################################################
        function GenerateVerifyBackup
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
                [BackupExec.Management.CLI.BEVerifyBackupTask]
                $BackupTask
            )
            
            begin
            {
                $excludeProperties = @(
                    "SourceBackups"
                    "ImmediatelyAfterSourceCompletes"
                    "Schedule"
                )            
            }
            
            process
            {            
@"
        | ForEach-Object {
            ######################### '$($BackupTask.Name)' Options #########################
            `$backupTaskParameters =``
"@
                GenerateParameterHashTable $BackupTask -IndentLevel 3 { $excludeProperties -notcontains $_.Name } -TargetCommand (Get-Command "Add-BEDuplicateStageBackupTask")

                if($BackupTask.ImmediatelyAfterSourceCompletes)
                {
@"

            `$_ | Add-BEVerifyBackupTask -ImmediatelyAfterBackup $(GetParameterPropertyValue $BackupTask.SourceBackups) @backupTaskParameters
"@
                }
                else
                {
@"

            `$_ | Add-BEVerifyBackupTask -SourceBackup $(GetParameterPropertyValue $BackupTask.SourceBackups) -Schedule ($(GetParameterPropertyValue $BackupTask.Schedule)) @backupTaskParameters
"@
                }
@"
        }``
"@
            }
            
            end
            {
            }
        }


        ###############################################################################################################
        function GenerateDuplicateStage
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
                [BackupExec.Management.CLI.BEDuplicateStageBackupTask]
                $BackupTask
            )
            
            begin
            {
                $excludeProperties = @(
                    "ImmediatelyAfterSourceCompletes"
                    "Schedule"
                    "Source"
                    "SpecificBackups"
                )            
            }
            
            process
            {            
@"
        | ForEach-Object {
            ######################### '$($BackupTask.Name)' Options #########################
            `$backupTaskParameters =``
"@
                GenerateParameterHashTable $BackupTask -IndentLevel 3 { $excludeProperties -notcontains $_.Name } -TargetCommand (Get-Command "Add-BEDuplicateStageBackupTask")
@"
            `$backupTaskParameters["DoNotAddDefaultVerifyTask"] = `$true
"@
            
                switch ($BackupTask.Source)
                {
                    "AllBackups"
                    {
@"

            `$_ | Add-BEDuplicateStageBackupTask -SourceBackup AllBackups -Schedule ($(GetParameterPropertyValue $BackupTask.Schedule)) @backupTaskParameters
"@
                    }
            
                    "SpecificSourceBackups"
                    {
                        if($BackupTask.ImmediatelyAfterSourceCompletes)
                        {
                            if($BackupTask.SpecificBackups[0] -is [BackupExec.Management.CLI.BEDuplicateStageBackupTask])
                            {
@"

            `$_ | Add-BEDuplicateStageBackupTask -ImmediatelyAfterDuplicate "$($BackupTask.SpecificBackups[0].Name)" @backupTaskParameters
"@                    
                            }
                            else
                            {
@"

            `$_ | Add-BEDuplicateStageBackupTask -ImmediatelyAfterBackup "$($BackupTask.SpecificBackups[0].Name)" @backupTaskParameters
"@                                        
                            }           
                        }
                        else
                        {
                            if($BackupTask.SpecificBackups[0] -is [BackupExec.Management.CLI.BEDuplicateStageBackupTask])
                            {
@"

            `$_ | Add-BEDuplicateStageBackupTask -SourceDuplicate "$($BackupTask.SpecificBackups[0].Name)" -Schedule ($(GetParameterPropertyValue $BackupTask.Schedule)) @backupTaskParameters
"@
                            }
                            else
                            {
@"

            `$_ | Add-BEDuplicateStageBackupTask -SourceBackup SpecificSourceBackups -SpecificSourceBackup $(GetParameterPropertyValue $BackupTask.SpecificBackups) -Schedule ($(GetParameterPropertyValue $BackupTask.Schedule)) @backupTaskParameters
"@
                            }   
                        }
                    }
                
                    "MostRecentFullBackup"
                    {
@"

            `$_ | Add-BEDuplicateStageBackupTask -SourceBackup MostRecentFullBackup -Schedule ($(GetParameterPropertyValue $BackupTask.Schedule)) @backupTaskParameters
"@            
                    }
                }
@"
        }``
"@    
            }
            
            end
            {
            }
        }


        ###############################################################################################################
        function GenerateConvertBackupToVirtualStage
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
                $InputObject
            )
            
            begin
            {
            }
        
            process
            {
                $options = $null
                $backupTask = $null
                $name = $null
                if($InputObject -is [BackupExec.Management.CLI.BEBackupTask])
                {
                    $options = $InputObject.Options
                    $backupTask = $InputObject
                    $name = $backupTask.Name
                }
                else
                {
                    $options = $InputObject
                    $name = "Convert to virtual simultaneously with backup"
                }
                
                $excludeProperties = @(
                    "ImmediatelyAfterSourceCompletes"
                    "Schedule"
                    "Source"
                    "SpecificBackups"
                    "Options"
                    "ConvertToVirtualType"
                    "VirtualMachineCpuCount"
                    "VirtualMachineName"
                    "VirtualMachinePhysicalRamMB"
                )
                
@"
        | ForEach-Object {
            ######################### '$name' Options #########################
            `$backupTaskParameters =``
"@    
                GenerateParameterHashTable $options -IndentLevel 3 { $excludeProperties -notcontains $_.Name } -TargetCommand (Get-Command "Add-BEConvertToVirtualStageBackupTask")
        
                if($backupTask)
                {
@"

            `$backupTaskParameters +=``
"@      
                    GenerateParameterHashTable $backupTask -IndentLevel 3 { $excludeProperties -notcontains $_.Name } -TargetCommand (Get-Command "Add-BEConvertToVirtualStageBackupTask")       
        
                    switch ($BackupTask.Source)
                    {
                        "AllBackups"
                        {
@"

            `$_ | Add-BEConvertToVirtualStageBackupTask -SourceBackup AllBackups -Schedule ($(GetParameterPropertyValue $BackupTask.Schedule)) @backupTaskParameters
"@
                        }
            
                        "SpecificSourceBackups"
                        {                
@"

            `$_ | Add-BEConvertToVirtualStageBackupTask -ImmediatelyAfterFullBackup "$($BackupTask.SpecificBackups[0].Name)" @backupTaskParameters
"@                              
                        }
            
                        "MostRecentFullBackup"
                        {
@"

            `$_ | Add-BEConvertToVirtualStageBackupTask -SourceBackup MostRecentFullBackup -Schedule ($(GetParameterPropertyValue $BackupTask.Schedule)) @backupTaskParameters
"@            
                        }
                    }
                }
                else
                {
@"

            `$_ | Add-BEConvertToVirtualStageBackupTask -SimultaneouslyWithBackup @backupTaskParameters
"@
                }
@"
        }``
"@    
            }
            
            end
            {
            }
        }
        
        
        ###############################################################################################################
        function GenerateBackupDefinition
        {
@'        
    ######################### Backup Definition Options #########################
    $backupDefinitionParameters = $PSBoundParameters
    $backupDefinitionParameters +=`
'@
            $excludeBackupDefinitionProperties = @(
                "Name"
                "AgentServer"
                "SelectionSummary"
				"SelectionList"
                "SimplifiedDisasterRecoveryEnabled"
                "InitialFullBackup"
                "AdditionalBackups"
                "Verifies"
                "DuplicateStages"
                "SimultaneousConvertToVirtualStage"
                "ConvertBackupToVirtualStages"
                "EditMode"
            )

			$excludeInitialFullProperties = @(
                "JobName"
            )            
    
            GenerateParameterHashTable $BackupDefinition { $excludeBackupDefinitionProperties -notcontains $_.Name }  -IndentLevel 1 -TargetCommand (Get-Command "New-BEBackupDefinition")

@"

    New-BEBackupDefinition -BackupJobDefault BackupToDisk -WithInitialFullBackupOnly @backupDefinitionParameters ``
        | ForEach-Object {
            if(`$_.InitialFullBackup.Name -ne `"$($BackupDefinition.InitialFullBackup.Name)`")
            {
                `$_ | Rename-BEBackupTask -Name `$_.InitialFullBackup.Name -NewName `"$($BackupDefinition.InitialFullBackup.Name)`"
            }
            else
            {
                `$_
            }
        }``
        | ForEach-Object {
            ######################### '$($BackupDefinition.InitialFullBackup.Name)' Options #########################
            `$backupTaskParameters =``
"@
            GenerateParameterHashTable $BackupDefinition.InitialFullBackup { $excludeInitialFullProperties -notcontains $_.Name }  -IndentLevel 3 -TargetCommand (Get-Command "Set-BEBackupTask")
@"        

            `$_ | Set-BEBackupTask @backupTaskParameters $(if ($BackupDefinition.InitialFullBackup.DeleteSelectedFilesAfterSuccessfulBackup -ne "Never") {"-Force"})
        }``
"@

            if($BackupDefinition.AdditionalBackups)
            {
                $BackupDefinition.AdditionalBackups | GenerateAdditionalBackup
            }
        
            if($BackupDefinition.DuplicateStages)
            {
                $BackupDefinition.DuplicateStages | GenerateDuplicateStage
            }
        
            if($BackupDefinition.SimultaneousConvertToVirtualStage)
            {
                $BackupDefinition.SimultaneousConvertToVirtualStage | GenerateConvertBackupToVirtualStage
            }
        
            if($BackupDefinition.ConvertBackupToVirtualStages)
            {
                $BackupDefinition.ConvertBackupToVirtualStages | GenerateConvertBackupToVirtualStage
            }
    
            if($BackupDefinition.Verifies)
            {
                $BackupDefinition.Verifies | GenerateVerifyBackup
            }
@"
"@        

    # Need to synthesize the SDR param because the param name does not match the property name on BackupDefinition.
    # Also need to enforce SDR OFF when grooming option is used:
    if ($BackupDefinition.InitialFullBackup.DeleteSelectedFilesAfterSuccessfulBackup -ne "Never")
    {
        # Grooming jobs must set SDR off:
@"
        | ForEach-Object { Set-BEBackupDefinition `$_ -EnableSimplifiedDisasterRecovery $(GetParameterPropertyValue $false) } ``
"@
    }
    elseif ([bool]$PSBoundParameters["EnableSimplifiedDisasterRecovery"])
    {
@"
        | ForEach-Object { Set-BEBackupDefinition `$_ -EnableSimplifiedDisasterRecovery $(GetParameterPropertyValue $PSBoundParameters["EnableSimplifiedDisasterRecovery"]) } ``
"@
    }

        }
        
        
        ###############################################################################################################
        function GenerateDependencyCheck
        {
@'
    $dependenciesMissing = $false
'@
            $ManagementObjectsThatImportScriptDependsOn.Keys | ForEach-Object {
@"

    ######################### Check for `"$_`" #########################
    `$command = Get-Command $($ManagementObjectsThatImportScriptDependsOn.$_.GetCommandName)
    try
    {
        & `$command -Name '$_' | Out-Null
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        Write-Warning `"The $($ManagementObjectsThatImportScriptDependsOn.$_.ManagementObjectTypeName) named '$_' was not found. Please ensure it exists before running this script.`"
        `$dependenciesMissing = `$true
    }
"@
            }            
@'

    if($dependenciesMissing)
    {
        throw "One or more dependencies that this script requires are missing. See warning messages above."
    }
'@            
        }
    }

    
    ###############################################################################################################
    process
    {
        $backupDefinitionScript = GenerateBackupDefinition
@'
[CmdletBinding(DefaultParameterSetName = 'NoSelectionsParameterSet')]
param
(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='SelectionListParameterSet')]
    [BackupExec.Management.CLI.BEAgentServerBackupSelectionList[]]
    $SelectionList,

    [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName='AgentServerSelectionParameterSet')]
    [BackupExec.Management.CLI.BEAgentServer]
    $AgentServer,

'@
    
  if ($BackupDefinition.InitialFullBackup.DeleteSelectedFilesAfterSuccessfulBackup -eq "Never")
  {
@'  
    [Parameter(ParameterSetName='AgentServerSelectionParameterSet')]
    [bool]
    $EnableSimplifiedDisasterRecovery,

'@
  }

        $SelectionParameterNames | ForEach-Object {$firstItem=$true}{
                $parameter = $NewBackupDefinitionCommand.Parameters[$_]
@"
    [Parameter(ParameterSetName='AgentServerSelectionParameterSet')]
    [$($parameter.ParameterType)]
    `$$($parameter.Name),
    
"@
        }

@'
    [string]
    $Name
)

begin
{
    $ErrorActionPreference = "Stop"
    
'@
        GenerateDependencyCheck
@'
}

process
{
'@
        $backupDefinitionScript
@'
}

end
{
}
'@
    }
    
    
    ###############################################################################################################
    end
    {
    }
}



#######################################################################
# Returns multiple arrays.
# First array is InputObjects that match the Filter, second are non-matches
#
function Split-UsingFilter
{
    [CmdletBinding()]
	[OutputType([System.Void])]#This command should not be public
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $InputObject,
        
        [Parameter(Position=1, ValueFromPipeline=$false, Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]
        $Filter={$true}
    )
    
    $passed = @()
    $failed = @()
    
    $input | ForEach-Object {
        if ($_ | Where-Object -FilterScript $Filter) {
            $passed += $_
        } else {
            $failed += $_
        }          
    }

    ,$passed    
    ,$failed
}


#######################################################################
function Filter-Or
{
    [CmdletBinding()]
	[OutputType([System.Void])]#This command should not be public
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $InputObject,
        
        [Parameter(Position=1, ValueFromPipeline=$false, Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock[]]
        $Filter={$true}
    )
    
    # Try all Filters until a passing item is found, and write passing items to pipeline *once*
    $input | ForEach-Object {
        $passingInput = $null
        for ($i=0; ((-not $passingInput) -and ($i -lt $Filter.Count)); ++$i) {
            $passingInput = $_ | Where-Object -FilterScript $Filter[$i]
            if ($passingInput) {
                Write-Output $passingInput
            }
        }
    }
}


#######################################################################
# Returns InputObjects sorted by groups, where the groups are derived from the Filters passed in.
# All items are returned to the pipeline in the order passed in, sorted first by matching Filter,
# and then by the order passed in.
#
# Example:
# 1,2,3,4,5 | Sort-UsingFilters -Filters {$_ -eq 4},{$_ % 2}
# 4
# 1
# 3
# 5
# 2
#
function Sort-UsingFilters
{
    [CmdletBinding()]
	[OutputType([System.Void])]#This command should not be public
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true)]
        $InputObject,
        
        [Parameter(ValueFromPipeline=$false, Mandatory=$false)]
        [ScriptBlock[]]
        $Filters=@({$true})
    )
    
    $remainingInput = $input
    $Filters | Where-Object {$_} | ForEach-Object {
        $currentFilter = $_
        $matchedInput, $remainingInput = $remainingInput | Split-UsingFilter $currentFilter
        if ($matchedInput)
        {
            Write-Output $matchedInput
        }
    }
    
    if ($remainingInput)
    {
        Write-Output $remainingInput
    }
}


#######################################################################
function Set-BEBackupSelectionListOrder
{
<#
	.EXTERNALHELP BackupExec.Management.CLI.Powershell3.dll-Help.xml
#>
    [CmdletBinding(DefaultParameterSetName='AllCommandSet')]
	[OutputType([BackupExec.Management.CLI.BEAgentServerSelection])]
    param(
        # InputObject is the list of BEAgentServerBackupSelectionList objects.
        # Each contains an AgentServer and a list of Selection objects.
        # The Selection objects have different sets of properties, depending on which agent they represent selections for.
        [Parameter(ParameterSetName='AllCommandSet', Position=0, ValueFromPipeline=$true, Mandatory=$true)]
        $InputObject,
        
        # You can specify an ordered list of AgentServerNames, and any input objects whose AgentServer.Name matches a name in this list
        # is used for all subsequent operations.
        # Any non-matched agent servers (and their related Selection list) are untouched, and pushed to the top or bottom of the output,
        # depending on whether the MakeLast switch is used.
        [Parameter(ParameterSetName='AllCommandSet', Position=1, ValueFromPipeline=$false, Mandatory=$false)]
        [String[]]
        $AgentServerNameOrder=@('*'),
        
        # SelectionMatcher is an ordered list of predicate scriptblocks (using $_ for the current Selection item)
        # Only BEAgentServerBackupSelectionList that matched an AgentServerName are processed.  
        # Items from the Selection list of each included BEAgentServerBackupSelectionList are tested against the SelectionMatcher predicates.
        # All items that match the first predicate are output first, the second predicate (if given) second, and so on.  Unmatched items are put
        # at the and of the list.
        #
        # Some selections have rules that Backup Exec will enforce.  For example, System State must be backed up last when it is included in a backup.
        # This cmdlet will not let you override that rule.
        [Parameter(ParameterSetName='AllCommandSet', ValueFromPipeline=$false, Mandatory=$false)]
        [String[]]
        $AgentServerBackupSourceNameOrder=@('*'),
        
        # MakeLast causes matched items to be put at the end of the output list, rather than the front.
        # If A, B, C, D is given, and A, B, D are matched, the normal output would be A, B, D, C.  With -MakeLast, the output order would be C, D, B, A.
        [Parameter(ParameterSetName='AllCommandSet', ValueFromPipeline=$false, Mandatory=$false)]
        [switch]
        $MakeLast
    )
    
    $input | ForEach-Object {
        # Selection lists are owned by different object types, including BEBackupDefinitions and BEOneTimeBackupJobs.
        # The contract is: there mst be a SelectionList property that contains an ordered collection of BEAgentServerBackupSelectionList objects.
        # After the sort is complete, this function will commit the changes automatically by calling the "Set-" cmdlet, followed by the "Save-" cmdlet (if necessary and available)
        $selectionListOwner = $_
        
        # Pull out the selection list and go to work:
        $selectionList = $selectionListOwner.SelectionList
        
        if (-not $selectionList) {
            Write-Warning "SelectionList property missing or empty: $InputObject"
            return
        }
    
        # Make sure we have a way of setting the value before we try to calculate it!
        $cmdletName = "Set-$($selectionListOwner.GetType().Name)"
        $paramName  = "SelectionList"
        try
        {
            $cmdlet = Get-Command -Name $cmdletName
            $param  = Get-Command -Name $cmdletName -ParameterName $paramName
        }
        catch
        {
            if (-not $cmdlet) {
                Write-Error "$cmdletName not found.  A cmdlet or function named $cmdletName is required to set the sorted backup selection list to its owner.  The cmdlet must have a parameter named '$($paramName)'."            
                return
            }
            
            if (-not $param) {
                Write-Error "-$($paramName) not found.  The cmdlet or function named $cmdletName must have a parameter named '$($paramName)'."
                return
            }            
        }
        
        $cmdletSaveName = "Save-$($selectionListOwner.GetType().Name)"
        try
        {
            $cmdletSave = Get-Command -Name $cmdletSaveName -ErrorAction SilentlyContinue
        }
        catch
        {
        }
        
        # Both the outer and inner collections (BEAgentServerSelectionList and Selections property of the lists) need to be:
        #   A. Split into "sort" and "Don't sort" groups.  "Sort" item collection is created by matching ANY of the filters passed in (Split-UsingFilter + Filter-Or handles this)
        #   B. Sorted (see Sort-UsingFilter)
        #   C. Recombined, honoring 'MakeLast' switch
        
        # Create Filter scriptblocks for each AgentServerName given
        $sortFilterAgentServerNames = $AgentServerNameOrder | ForEach-Object { [ScriptBlock]::Create("`$_.AgentServer.Name -like '$_'") }
        $splitFilterAgentServerNames = { $input | Filter-Or $sortFilterAgentServerNames}
        
        # Split into "Sort" and "Don't Sort" InputObjects, based on matching *any* of the AgentServerNames
        $sortedAgentServers, $remainingAgentServers = $selectionList | Split-UsingFilter -Filter $splitFilterAgentServerNames
                
        # Sort the interior selections for the "Sort" group
        # Be sensitive to MakeLast
        if ($sortedAgentServers -and $AgentServerBackupSourceNameOrder)
        {
            # Within each AgentServers' worth of selections, we now need to isolate and sort the items whose BackupSource has been specified by invoker:
            $sortFilterBackupSourceNames = $AgentServerBackupSourceNameOrder | ForEach-Object { [ScriptBlock]::Create("`$_.AgentServerBackupSourceName -like '$_'") }
            $splitFilterBackupSourceNames = { $input | Filter-Or $sortFilterBackupSourceNames}
            
            $sortedAgentServers = $sortedAgentServers | ForEach-Object {            
                # Break out the items to sort (and the remainder to keep in current order)
                # Note: the Selections property is a ReadOnlyCollection`1 and doesn't work seamlessly with pipelines..hence the array notation to iterate over its items
                $sortedSelections, $remainingSelections = $_.Selections[0..($_.Selections.Count)] | Split-UsingFilter -Filter $splitFilterBackupSourceNames
                
                # Sort them
                $sortedSelections = $sortedSelections | Sort-UsingFilters -Filter $sortFilterBackupSourceNames

                # Put them in the back or front based on MakeLast
                if ($MakeLast) {
                    $sortedSelections = @() + $remainingSelections + $sortedSelections | ?{$_}
                } else {
                    $sortedSelections = @() + $sortedSelections + $remainingSelections | ?{$_}
                }
                
                # Re-create the selection with the new order                    
                New-BEBackupSelection -AgentServer $_.AgentServer -Selection $sortedSelections
            }
        }
        
        # Sort the InputObjects themselves using the AgentServerName Filters
        # Be sensitive to MakeLast
        if ($sortedAgentServers) {
            $sortedAgentServers = $sortedAgentServers | Sort-UsingFilters -Filter $sortFilterAgentServerNames
        }
        
        # Put them in the back or front based on MakeLast
        if ($MakeLast) {            
            $sortedAgentServers = @() + $remainingAgentServers + $sortedAgentServers | ?{$_} # Combine lists, filter out null items
        } else {
            $sortedAgentServers = @() + $sortedAgentServers + $remainingAgentServers | ?{$_} # Combine lists, filter out null items
        }

        # Set-XXXX property for InputObject
        $scriptBlock = "`$selectionListOwner | $cmdletName -$paramName `$sortedAgentServers"
        if ($cmdletSave) {
            $scriptBlock += " | $cmdletSave -Confirm:`$false"
        }
        &([ScriptBlock]::Create($scriptBlock).GetNewClosure())
    }
}


#######################################################################
Function Remove-BENotificationRecipientObject
{
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="RecipientParameterSet")]
    [BackupExec.Management.CLI.BENotificationRecipient]$NotificationRecipient,

    [Parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="GroupParameterSet")]
    [BackupExec.Management.CLI.BENotificationRecipientGroup]$NotificationRecipientGroup,

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$Confirm,

    [Parameter()]
    [switch]$WhatIf
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            "RecipientParameterSet" {
                $NotificationRecipient | Remove-BENotificationRecipient -Confirm:$Confirm -WhatIf:$WhatIf -PassThru:$PassThru
            }
            "GroupParameterSet" {
                $NotificationRecipientGroup | Remove-BENotificationRecipientGroup -Confirm:$Confirm -WhatIf:$WhatIf -PassThru:$PassThru
            }
        }
    }
}



######################### Import/Export Logic #########################
# Import BackupExec.Management.CLI and create the relevant aliases
Import-Module (Join-Path $PSScriptRoot BackupExec.Management.CLI.PowerShell3.dll)

# Aliases that reconcile BE terminology with PowerShell terminology
New-Alias -Name 'Add-BENdmpAgentServer' -Value 'Add-BELinuxAgentServer'
New-Alias -Name 'Add-BEFileAgentServer' -Value 'Add-BELinuxAgentServer'
New-Alias -Name 'Associate-BEMediaWithMediaSet' -Value 'Move-BEMediaToMediaSet'
New-Alias -Name 'Cancel-BEJob' -Value 'Stop-BEJob'
New-Alias -Name 'Configure-BEDeduplicationDiskStorageDevice' -Value 'New-BEDeduplicationDiskStorageDevice'
New-Alias -Name 'Configure-BEDiskCartridgeDevice' -Value 'New-BEDiskCartridgeDevice'
New-Alias -Name 'Configure-BEDiskStorageDevice' -Value 'New-BEDiskStorageDevice'
New-Alias -Name 'Configure-BEUnconfiguredDiskCartridgeDevice' -Value 'Initialize-BEUnconfiguredDiskCartridgeDevice'
New-Alias -Name 'Configure-BEUnconfiguredDiskStorageDevice' -Value 'Initialize-BEUnconfiguredDiskStorageDevice'
New-Alias -Name 'Configure-BEUnconfiguredVirtualDiskDevice' -Value 'Initialize-BEUnconfiguredVirtualDiskDevice'
New-Alias -Name 'Hold-BEJob' -Value 'Suspend-BEJob'
New-Alias -Name 'Hold-BEJobQueue' -Value 'Suspend-BEJobQueue'
New-Alias -Name 'Replace-BEEncryptionKey' -Value 'Switch-BEEncryptionKey'
New-Alias -Name 'Run-BEJob' -Value 'Start-BEJob'
New-Alias -Name 'Run-BEReport' -Value 'Invoke-BEReport'
New-Alias -Name 'Take-BEJobOffHold' -Value 'Resume-BEJob'
New-Alias -Name 'Test-BECredential' -Value 'Test-BELogonAccount'
New-Alias -Name 'Establish-BETrust' -Value 'Grant-BETrust'
New-Alias -Name 'Get-BEJobQueue' -Value 'Get-BEBackupExecServer'
New-Alias -Name 'Reset-BETapeDriveToDefaultSetting' -Value 'Set-BETapeDriveToDefaultSetting'
New-Alias -Name 'New-BEActiveDirectoryLightweightDirectoryServiceSelection' -Value 'New-BEActiveDirectoryApplicationModeSelection'
New-Alias -Name 'Share-BECloudStorageDevice' -Value 'Add-BEBackupExecServerToCloudStorageDevice'
New-Alias -Name 'Share-BEDeduplicationDiskStorageDevice' -Value 'Add-BEBackupExecServerToDeduplicationDiskStorageDevice'
New-Alias -Name 'Share-BEDiskStorageDevice' -Value 'Add-BEBackupExecServerToDiskStorageDevice'
New-Alias -Name 'Share-BELegacyBackupToDiskFolderDevice' -Value 'Add-BEBackupExecServerToLegacyBackupToDiskFolderDevice'
New-Alias -Name 'Share-BENdmpServer' -Value 'Add-BEBackupExecServerToNdmpServer'
New-Alias -Name 'Share-BEOpenStorageDevice' -Value 'Add-BEBackupExecServerToOpenStorageDevice'
New-Alias -Name 'Share-BERemoteMediaAgentForLinux' -Value 'Add-BEBackupExecServerToRemoteMediaAgentForLinux'
New-Alias -Name 'Share-BEVirtualDiskDevice' -Value 'Add-BEBackupExecServerToVirtualDiskDevice'

Update-FormatData -PrependPath $formatsToExport
Update-TypeData -PrependPath $typesToExport

Export-ModuleMember -Function @('Get-BECommand','Export-BEBackupDefinition','Set-BEBackupSelectionListOrder','Remove-BENotificationRecipientObject')
Export-ModuleMember -Cmdlet $commandsToExport -Alias $aliasesToExport

# SIG # Begin signature block
# MIIXwQYJKoZIhvcNAQcCoIIXsjCCF64CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUiOm+XVIjA4Hnk3jXRVBLIKpv
# V76gghLnMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggTtMIID1aADAgECAhA8mAuEiJDNICWdc2bBRlCBMA0GCSqGSIb3DQEBCwUAMH8x
# CzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0G
# A1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEwMC4GA1UEAxMnU3ltYW50ZWMg
# Q2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5nIENBMB4XDTE5MTAxMDAwMDAwMFoX
# DTIwMTAyNjIzNTk1OVowgaMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIDApDYWxpZm9y
# bmlhMRYwFAYDVQQHDA1Nb3VudGFpbiBWaWV3MSEwHwYDVQQKDBhWZXJpdGFzIFRl
# Y2hub2xvZ2llcyBMTEMxITAfBgNVBAsMGGNvbmZpZ3VyYXRpb24gTWFuYWdlbWVu
# dDEhMB8GA1UEAwwYVmVyaXRhcyBUZWNobm9sb2dpZXMgTExDMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEA18ZMOLVSPwq/rBuJ50Fvv0gr+WKlcPTdkqQ7
# 18YPCawQ2Fy2zhYGG049goNsIH2v3ecKS9XMG1CZu1QdbowSNyN4SCynQ5YdQGk5
# 62gIY3KiIyQcnXP2GJDUhwwq/1DlM9r16XvvhnqTXUq4NNM0DUhxkY34MiV0VbRL
# 8JAXDGKTv4V4FwfH4EssiB53THC8TveScpzRU6l9ZQ71KC4gmoHNOYF5M7kkDgMC
# x6Gy5BkYUvpavyZLPvD2nqhLEAsO0TrfBte7shn5D64of18WzfTZKxu3kdplV7pJ
# wil/IxsuTrfcxtfUwrj1huIshRtJqND5ByIH7AG3+CdNmAyz6wIDAQABo4IBPjCC
# ATowCQYDVR0TBAIwADAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwYQYDVR0gBFowWDBWBgZngQwBBAEwTDAjBggrBgEFBQcCARYXaHR0cHM6Ly9k
# LnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIwGQwXaHR0cHM6Ly9kLnN5bWNiLmNv
# bS9ycGEwHwYDVR0jBBgwFoAUljtT8Hkzl699g+8uK8zKt4YecmYwKwYDVR0fBCQw
# IjAgoB6gHIYaaHR0cDovL3N2LnN5bWNiLmNvbS9zdi5jcmwwVwYIKwYBBQUHAQEE
# SzBJMB8GCCsGAQUFBzABhhNodHRwOi8vc3Yuc3ltY2QuY29tMCYGCCsGAQUFBzAC
# hhpodHRwOi8vc3Yuc3ltY2IuY29tL3N2LmNydDANBgkqhkiG9w0BAQsFAAOCAQEA
# JNfh74gbyyrV/CfpcYav5GISdateZCzgQxRQM7ZdIvTbnO/ejfhI+WoffUyVvU5Z
# pumYT0I4R+uhr4X/Bkhub0FGwkfpeSCUhQnAXup1k7lSPsFk65xOM3CVnbr3Zdbf
# mRHjFVO09yVfrqh7iW9/L5LvfSNAL5CaJIrsbE9WzplwVEgJrEkteVd0kHt933Ra
# 8fy00oxvEvJFxn+1I00eBI2np8Q/vQQ12WU5+4ptVFEWKTuCVHC416vmz1FVDJ+t
# GJThMW1et4nQI5FAs+h3upCg6+hIX9PF4vG7IPly3dpgS+wvshkVRjxQNapGbwal
# HVsElGSQxdYmqLu62R+mxzCCBVkwggRBoAMCAQICED141/l2SWCyYX308B7Khiow
# DQYJKoZIhvcNAQELBQAwgcoxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2ln
# biwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE6MDgGA1UE
# CxMxKGMpIDIwMDYgVmVyaVNpZ24sIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1c2Ug
# b25seTFFMEMGA1UEAxM8VmVyaVNpZ24gQ2xhc3MgMyBQdWJsaWMgUHJpbWFyeSBD
# ZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSAtIEc1MB4XDTEzMTIxMDAwMDAwMFoXDTIz
# MTIwOTIzNTk1OVowfzELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENv
# cnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMTAwLgYD
# VQQDEydTeW1hbnRlYyBDbGFzcyAzIFNIQTI1NiBDb2RlIFNpZ25pbmcgQ0EwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCXgx4AFq8ssdIIxNdok1FgHnH2
# 4ke021hNI2JqtL9aG1H3ow0Yd2i72DarLyFQ2p7z518nTgvCl8gJcJOp2lwNTqQN
# kaC07BTOkXJULs6j20TpUhs/QTzKSuSqwOg5q1PMIdDMz3+b5sLMWGqCFe49Ns8c
# xZcHJI7xe74xLT1u3LWZQp9LYZVfHHDuF33bi+VhiXjHaBuvEXgamK7EVUdT2bMy
# 1qEORkDFl5KK0VOnmVuFNVfT6pNiYSAKxzB3JBFNYoO2untogjHuZcrf+dWNsjXc
# jCtvanJcYISc8gyUXsBWUgBIzNP4pX3eL9cT5DiohNVGuBOGwhud6lo43ZvbAgMB
# AAGjggGDMIIBfzAvBggrBgEFBQcBAQQjMCEwHwYIKwYBBQUHMAGGE2h0dHA6Ly9z
# Mi5zeW1jYi5jb20wEgYDVR0TAQH/BAgwBgEB/wIBADBsBgNVHSAEZTBjMGEGC2CG
# SAGG+EUBBxcDMFIwJgYIKwYBBQUHAgEWGmh0dHA6Ly93d3cuc3ltYXV0aC5jb20v
# Y3BzMCgGCCsGAQUFBwICMBwaGmh0dHA6Ly93d3cuc3ltYXV0aC5jb20vcnBhMDAG
# A1UdHwQpMCcwJaAjoCGGH2h0dHA6Ly9zMS5zeW1jYi5jb20vcGNhMy1nNS5jcmww
# HQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIBBjAp
# BgNVHREEIjAgpB4wHDEaMBgGA1UEAxMRU3ltYW50ZWNQS0ktMS01NjcwHQYDVR0O
# BBYEFJY7U/B5M5evfYPvLivMyreGHnJmMB8GA1UdIwQYMBaAFH/TZafC3ey78DAJ
# 80M5+gKvMzEzMA0GCSqGSIb3DQEBCwUAA4IBAQAThRoeaak396C9pK9+HWFT/p2M
# XgymdR54FyPd/ewaA1U5+3GVx2Vap44w0kRaYdtwb9ohBcIuc7pJ8dGT/l3JzV4D
# 4ImeP3Qe1/c4i6nWz7s1LzNYqJJW0chNO4LmeYQW/CiwsUfzHaI+7ofZpn+kVqU/
# rYQuKd58vKiqoz0EAeq6k6IOUCIpF0yH5DoRX9akJYmbBWsvtMkBTCd7C6wZBSKg
# YBU/2sn7TUyP+3Jnd/0nlMe6NQ6ISf6N/SivShK9DbOXBd5EDBX6NisD3MFQAfGh
# EV0U5eK9J0tUviuEXg+mw3QFCu+Xw4kisR93873NQ9TxTKk/tYuEr2Ty0BQhMYIE
# RDCCBEACAQEwgZMwfzELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENv
# cnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMTAwLgYD
# VQQDEydTeW1hbnRlYyBDbGFzcyAzIFNIQTI1NiBDb2RlIFNpZ25pbmcgQ0ECEDyY
# C4SIkM0gJZ1zZsFGUIEwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKA
# AKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFHhfP1g2oITrpmSoe4OgR4jW
# p+LQMA0GCSqGSIb3DQEBAQUABIIBALGFfcl6Z0ri9NVSNaynd6dir015T5bRR/iX
# ZW27bAiKjIvYkM7YJ9HCKZh4KX/28UkHFAl9OCHAfyqrDUY6TnkVDYDHf/yUc8sF
# Wm6mg7wmNLbj+YJXabSYskhx8s5tiScwZ9FLd9gdvY4M9ktFrDEuwNHo/KtrVZSE
# iAUZ8G5KtAeGCUscW3C2Mcm8qOeEiv5MrcwzQtl7nZV4TyLy9ALtwcUplVcXuWoQ
# 9COo984EG0qhyKr+HZ9wAtDwRWjFC89ZwEJXYzYneca8mH2mHwPt1hLXQmXGIrTz
# L+sxYiU0++6fXwdQEv7Hl1FXOpRa8N+LvHdXvqgQbDFbqwuGwrOhggILMIICBwYJ
# KoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMU
# U3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3Rh
# bXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMC
# GgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcN
# MTkxMTE1MTczMTQxWjAjBgkqhkiG9w0BCQQxFgQUz3uwhAiaSoreCjtiTEoSsxOy
# 7Y4wDQYJKoZIhvcNAQEBBQAEggEAACEycvqka6MJ3Wp+Bwa9Ze1uryfOejB3TgJW
# ZAC4DEN5b75zgJygi+oqHHj7IF5cLPrqm+OAP8P5TKQC+NJ67NeQBFrdaLKHHTcZ
# nAfvIfMA4Lg4UJtr2B7ZWafHWemqIansQl1tdCm9auWE3L4890hPKU/yiGGYMQIF
# mDTs4xTnGgdPMS1Ok63suzoKXofiI9Q2fXgVtTHOcHqr9vu1/q3b7Wf21wtM6c1p
# YU3nu6u4JSbqxa+8PzCM2SMm5QbyrFR+DydmhsP0BqX4GJAYX2Sb8ydewmCPkiZR
# FDay3G5VTiCidYUNtHk+ZmdX9Xvmt8WGowoKM5L7DaEmDKUehw==
# SIG # End signature block
