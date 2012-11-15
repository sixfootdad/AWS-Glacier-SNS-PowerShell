<#
NOTICE
Copyright 2012 Damian Karlson
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at 
http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
#>

function Connect-AWSGlacier {

<#
	.SYNOPSIS
		Connects to Amazon AWS Glacier & SNS.
	
	.DESCRIPTION
		Connects to Amazon AWS Glacier & SNS. AWSAccessKeyID, AWSSecretAccessKey, and RegionEndpoint parameters are mandatory and do not accept pipeline input.
	
	.PARAMETER AWSAccessKeyID
		The account's AWSAccessKeyID. This parameter is mandatory and does not accept pipeline input.
		This can be obtained under the Security Credentials link in the account console.
	
	.PARAMETER AWSSecretAccessKey
		The account's AWSSecretAccessKey. This parameter is mandatory and does not accept pipeline input.
		This can be obtained under the Security Credentials link in the account console.
	
	.PARAMETER RegionEndpoint
		RegionEndpoints as defined by [Amazon.RegionEndpoint]::EnumerableAllRegions.
		Valid endpoints are us-east-1, us-west-1, us-west-2, eu-west-1, ap-southeast-1, sa-east-1, us-gov-west-1.
		There is no default RegionEndpoint specified in this function. This parameter is mandatory and does not accept pipeline input.
	
	.INPUTS
		None. Connect-AWSGlacier does not accept pipeline input.
	
	.OUTPUTS
		None. Connect-AWSGlacier only creates global connection variables.
	
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[string]$AWSAccessKeyId,
		[Parameter(Mandatory=$true)]
		[string]$AWSSecretAccessKey,
		[Parameter(Mandatory=$true)]
		[ValidateSet("us-east-1","us-west-1","us-west-2","eu-west-1","ap-northeast-1","ap-southeast-1","sa-east-1","us-gov-west-1")]
		[string]$RegionEndpoint
	)
	try {
		$env = Get-ChildItem Env:
		if (Test-Path -LiteralPath "C:\Program Files\AWS SDK for .NET\bin\AWSSDK.dll") {
			Add-Type -Path "C:\Program Files\AWS SDK for .NET\bin\AWSSDK.dll"
		} elseif (Test-Path -LiteralPath "C:\Program Files (x86)\AWS SDK for .NET\bin\AWSSDK.dll") {
			Add-Type -Path "C:\Program Files (x86)\AWS SDK for .NET\bin\AWSSDK.dll"
		}
	}
	catch {
		Write-Host $_.Exception.Message
		Write-Host "The AWS SDK DLL for .NET was expected at '$env:ProgramFiles\AWS SDK for .NET\bin\AWSSDK.dll' or '$env:ProgramFiles(x86)\AWS SDK for .NET\bin\AWSSDK.dll' and was not found. Please see the README for details."
		return
	}
	$global:AWSSecretAccessKey = $AWSSecretAccessKey | ConvertTo-SecureString -AsPlainText -Force
	$global:AWSCredentials = New-Object Amazon.Runtime.BasicAWSCredentials($AWSAccessKeyId,$AWSSecretAccessKey)
	$global:GlacierConfig = New-Object Amazon.Glacier.AmazonGlacierConfig
	$global:GlacierConfig.RegionEndpoint = [Amazon.RegionEndpoint]::GetBySystemName($RegionEndpoint)
	$global:GlacierClient = New-Object Amazon.Glacier.AmazonGlacierClient($global:AWSCredentials,$global:GlacierConfig)
	$global:ArchiveTransferManager = New-Object Amazon.Glacier.Transfer.ArchiveTransferManager($global:GlacierClient)
	$global:SNSConfig = New-Object Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceConfig
	$global:SNSConfig.RegionEndpoint = [Amazon.RegionEndpoint]::GetBySystemName($RegionEndpoint)
	$global:SNSClient = New-Object Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceClient($global:AWSCredentials,$global:SNSConfig)
}

function Get-GlacierVault {

<#
	.SYNOPSIS
		Gets information on a specific Glacier vault, or all Glacier vaults within the account.
	
	.DESCRIPTION
		Gets information on a specific Glacier vault, or all Glacier vaults within the account.
	
	.PARAMETER VaultName
		The name of the vault to retrieve; not specifying a vault name will return all vaults in the account. This parameter is optional and does not accept pipeline input.
		
	.EXAMPLE
		C:\PS> Get-GlacierVault -VaultName <vault>
		
	.EXAMPLE
		C:\PS> Get-GlacierVault
	
	.INPUTS
		None. Get-GlacierVault does not accept pipeline input.
	
	.OUTPUTS
		Amazon.Glacier.Model.DescribeVaultOutput. Get-GlacierVault without the VaultName parameter supplied returns all vault results formatted as an object.
		
		Amazon.Glacier.Model.DescribeVaultResult. Get-GlacierVault with the VaultName parameter returns specific vault results formatted as an object.
		
	.LINK
		New-GlacierVault
		Remove-GlacierVault
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter()]
		[string]$VaultName,
		[Parameter()]
		[int]$Limit
	)
	if ($VaultName) {	
		$DescribeVaultRequest = New-Object Amazon.Glacier.Model.DescribeVaultRequest
		$DescribeVaultRequest.AccountId = "-"
		$DescribeVaultRequest.VaultName = $VaultName
		try {
			$DescribeVault = $global:GlacierClient.DescribeVault($DescribeVaultRequest)
			return $DescribeVault.DescribeVaultResult
		}
		catch [Amazon.Glacier.AmazonGlacierException] {
			Write-Host $_.Exception.Message
			return
		}
	} else {
		$ListVaultsRequest = New-Object Amazon.Glacier.Model.ListVaultsRequest
		$ListVaultsRequest.AccountId = "-"
		if ($Limit) {
			$ListVaultsRequest.Limit = $Limit
		}
		try {
			$ListVaults = $global:GlacierClient.ListVaults($ListVaultsRequest)
			if ($ListVaults.ListVaultsResult.Marker) {
				do {
				$ListVaults = $global:GlacierClient.ListVaults($ListVaultsRequest)
				Write-Output $ListVaults.ListVaultsResult.VaultList
				$ListVaultsRequest.Marker = $ListVaults.ListVaultsResult.Marker
				} until ($ListVaults.ListVaultsResult.Marker -eq $null)
			} else {
				return $ListVaults.ListVaultsResult.VaultList
			}
		}
		catch [Amazon.Glacier.AmazonGlacierException] {
			Write-Host $_.Exception.Message
			return
		}
	}
}

function New-GlacierVault {

<#
	.SYNOPSIS
		Creates a new Glacier vault.
	
	.DESCRIPTION
		Creates a new Glacier vault.

	.PARAMETER VaultName
		Name for the new Glaciervault. The name must not contain spaces and must be between 1 and 255 characters in length. This parameter is mandatory and does not accept pipeline input.
	
	.EXAMPLE
		C:\PS> New-GlacierVault -VaultName <vault>
	
	.INPUTS
		None. New-GlacierVault does not accept pipeline input.
	
	.OUTPUTS
		System.String. New-GlacierVault returns the newly created vault's URI formatted as a string.
	
	.LINK
		Get-GlacierVault
		Remove-GlacierVault
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[ValidateLength(1,255)]
		[string]$VaultName
	)
	if ($VaultName -notmatch "^\S+$") {
		Write-Host "The VaultName Parameter must not include spaces."
		return
	}
	$CreateVaultRequest = New-Object Amazon.Glacier.Model.CreateVaultRequest
	$CreateVaultRequest.AccountId = "-"
	$CreateVaultRequest.VaultName = $VaultName
	try {
		$CreateVault = $global:GlacierClient.CreateVault($CreateVaultRequest)
		return $CreateVault.CreateVaultResult.Location
	}
	catch [Amazon.Glacier.AmazonGlacierException] {
		Write-Host $_.Exception.Message
		return
	}
}

function Remove-GlacierVault {

<#
	.SYNOPSIS
		Removes a Glacier vault.
		
	.DESCRIPTION
		Removes a specific Glacier vault, or removes all vaults using the results from Get-GlacierVault. The vault(s) must be empty or an error will be returned.
		
	.PARAMETER VaultName
		Name of the Glacier vault to be deleted. The VaultName parameter is mandatory and accepts pipeline input.
	
	.EXAMPLE
		C:\PS> Remove-GlacierVault -VaultName <vault>
	
	.EXAMPLE
		C:\PS> Get-GlacierVault -VaultName <vault> | Remove-GlacierVault
	
	.EXAMPLE
		C:\PS> Get-GlacierVault | Remove-GlacierVault

	.INPUTS
		The VaultName parameter can accept pipeline input from Get-GlacierVault.
	
	.OUTPUTS
		Sytem.String. Remove-GlacierVault writes a vault deletion confirmation formatted as a string.
		
	.LINK
		Get-GlacierVault
		New-GlacierVaults
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$VaultName
	)
	begin {}
	process {
		$DeleteVaultRequest = New-Object Amazon.Glacier.Model.DeleteVaultRequest
		$DeleteVaultRequest.AccountId = "-"
		$DeleteVaultRequest.VaultName = $VaultName
		try {
			$DeleteVault = $global:GlacierClient.DeleteVault($DeleteVaultRequest)
			Write-Host "Vault $VaultName deleted."
			return
		}
		catch [Amazon.Glacier.AmazonGlacierException] {
			Write-Host $_.Exception.Message
			return
		}
	}
	end {}
}

function Remove-GlacierArchive {

<#
	.SYNOPSIS
		Removes an archive from a Glacier vault.
	
	.DESCRIPTION
		Removes an archive from a Glacier vault, or all of the archives returned from an inventory retrieval job on a Glacier vault.
		
	.PARAMETER ArchiveId
		ArchiveId can be retrieved from an inventory retrieval job. This parameter is mandatory and accepts pipeline input.
	
	.PARAMETER VaultName
		Name of the vault containing the archive to be deleted. This parameter is mandatory and does not accept pipeline input.
	
	.EXAMPLE
		C:\PS> Remove-GlacierArchive -ArchiveId <archive> -VaultName <vault>
	
	.EXAMPLE
		C:\PS> $Inventory = (Get-Content -Path <path to JSON inventory job results> | ConvertFrom-Json)
		C:\PS> $Inventory.ArchiveList | Remove-GlacierArchive -VaultName <vault>
	
	.INPUTS
		The ArchiveId parameter can accept pipeline input from an inventory job output.
		
	.OUTPUTS
		Sytem.String. Remove-GlacierArchive writes an archive deletion confirmation formatted as a string.
	
	.LINK
		New-GlacierUpload
		New-GlacierJob
		Get-GlacierJobOutput
		
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$ArchiveId,
		[Parameter(Mandatory=$true)]
		[string]$VaultName
	)
	begin {}
	process {
		$DeleteArchiveRequest = New-Object Amazon.Glacier.Model.DeleteArchiveRequest
		$DeleteArchiveRequest.AccountId = "-"
		$DeleteArchiveRequest.VaultName = $VaultName
		$DeleteArchiveRequest.ArchiveId = $ArchiveId
		try {
			$DeleteArchive = $global:GlacierClient.DeleteArchive($DeleteArchiveRequest)
			Write-Host "Archive deleted."
			return
		}
		catch [Amazon.Glacier.AmazonGlacierException] {
			Write-Host $_.Exception.Message
			return
		}
	}
	end {}
}

function Get-GlacierVaultNotification {

<#
	.SYNOPSIS
		Gets Glacier vault notification configuration.
	
	.DESCRIPTION
		Gets vault notification configuration for a specific vault, or gets all vault notification configurations using the results from Get-GlacierVault.
		
	.PARAMETER VaultName
		 The VaultName parameter is mandatory and accepts pipeline input.
		 
	.EXAMPLE
		C:\PS> Get-GlacierVaultNotification -VaultName <vault>
		
	.EXAMPLE
		C:\PS> Get-GlacierVault -VaultName <vault> | Get-GlacierVaultNotification
		
	.EXAMPLE
		C:\PS> Get-GlacierVault | Get-GlacierVaultNotification
		
	.INPUTS
		The VaultName parameter can accept pipeline input from Get-GlacierVault.
	
	.OUTPUTS
		Amazon.Glacier.Model.VaultNotificationConfig. Get-GlacierVaultNotification returns vault notification configuration formatted as an object.
	
	.LINK
		Set-GlacierVaultNotification
		Remove-GlacierVaultNotification
	
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$VaultName
	)
	begin {}
	process {
		$GetVaultNotificationsRequest = New-Object Amazon.Glacier.Model.GetVaultNotificationsRequest
		$GetVaultNotificationsRequest.AccountId = "-"
		$GetVaultNotificationsRequest.VaultName = $VaultName
		try {
			$GetVaultNotifications = $global:GlacierClient.GetVaultNotifications($GetVaultNotificationsRequest)
			return $GetVaultNotifications.GetVaultNotificationsResult.VaultNotificationConfig
		}
		catch [Amazon.Glacier.Model.ResourceNotFoundException] {
			Write-Host "Vault $VaultName doesn't have any notifications configured."
			return
		}
		catch [Amazon.Glacier.AmazonGlacierException] {
			Write-Host $_.Exception.Message
			return
		}
	}
	end {}
}

function Set-GlacierVaultNotification {

<#
	.SYNOPSIS
		Sets Glacier vault notification configuration.
		
	.DESCRIPTION
		Sets Glacier vault notification configuration on a specific vault, or on all vaults returned by Get-GlacierVault. Vault notification options are ArchiveRetrievalCompleted, InventoryRetrievalCompleted, or All. Use Remove-GlacierVaultNotification to remove the notification configuration from a vault.
	
	.PARAMETER VaultName
		 The VaultName parameter is mandatory and accepts pipeline input.
		 
	.PARAMETER TopicArn
		The TopicArn parameter is mandatory and does not accept pipeline input. TopicArns can be retrieved with Get-SNSTopic.
		
	.PARAMETER Events
		The Events parameter is mandatory and does not accept pipeline input. Valid options are ArchiveRetrievalCompleted, InventoryRetrievalCompleted, or All.
		
	.EXAMPLE
		C:\PS> Set-GlacierVaultNotification -VaultName <vault> -TopicArn <topic> -Events <event>
			
	.EXAMPLE
		C:\PS> Get-GlacierVault -VaultName <vault> | Set-GlacierVaultNotification -TopicArn <topic> -Events <event>
	
	.EXAMPLE
		C:\PS> Get-GlacierVault | Set-GlacierVaultNotification -TopicArn <topic> -Events <event>
	
	.INPUTS
		The VaultName parameter can accept pipeline input from Get-GlacierVault.
	
	.OUTPUTS
		Amazon.Glacier.Model.VaultNotificationConfig. Returns the Glacier vault notification configuration formatted as an object.
		
	.LINK
		Get-GlacierVaultNotification
		Remove-GlacierVaultNotification
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$VaultName,
		[Parameter(Mandatory=$true)]
		[string]$TopicArn,
		[Parameter(Mandatory=$true)]
		[ValidateSet("ArchiveRetrievalCompleted","InventoryRetrievalCompleted","All")]
		[string]$Events
	)
	begin {}
	process {
		$SetVaultNotificationsRequest = New-Object Amazon.Glacier.Model.SetVaultNotificationsRequest
		$SetVaultNotificationsRequest.VaultNotificationConfig = New-Object Amazon.Glacier.Model.VaultNotificationConfig
		$SetVaultNotificationsRequest.AccountId = "-"
		$SetVaultNotificationsRequest.VaultName = $VaultName
		$SetVaultNotificationsRequest.VaultNotificationConfig.SNSTopic = $TopicArn
		switch ($Events) {
			"ArchiveRetrievalCompleted" {
				$SetVaultNotificationsRequest.VaultNotificationConfig.Events.Add("ArchiveRetrievalCompleted")
			}
			"InventoryRetrievalCompleted" {
				$SetVaultNotificationsRequest.VaultNotificationConfig.Events.Add("InventoryRetrievalCompleted")
			}
			"All" {
				$SetVaultNotificationsRequest.VaultNotificationConfig.Events.Add("ArchiveRetrievalCompleted")
				$SetVaultNotificationsRequest.VaultNotificationConfig.Events.Add("InventoryRetrievalCompleted")
			}
		}
		try {
			$SetVaultNotifications = $global:GlacierClient.SetVaultNotifications($SetVaultNotificationsRequest)
			$GetVaultNotifications = Get-GlacierVaultNotification -VaultName $VaultName
			return $GetVaultNotifications.GetVaultNotificationsResult.VaultNotificationConfig
		}
		catch [Amazon.Glacier.AmazonGlacierException] {
			Write-Host $_.Exception.Message
			return
		}
	}
	end {}
}

function Remove-GlacierVaultNotification {

<#
	.SYNOPSIS
		Removes Glacier vault notifications.
	
	.DESCRIPTION
		Removes Glacier vault notifications from a specific vault or on all vaults returned by Get-GlacierVault.
	
	.PARAMETER VaultName
		 The VaultName parameter is mandatory and accepts pipeline input.
	
	.INPUTS
		The VaultName parameter can accept pipeline input from Get-GlacierVault.
	
	.OUTPUTS
		Sytem.String. Remove-GlacierVaultNotification writes a vault notification removal confirmation formatted as a string.
	
	.LINK
		Get-GlacierVaultNotification
		Set-GlacierVaultNotification
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$VaultName
	)
	begin {}
	process {
		$DeleteVaultNotificationsRequest = New-Object Amazon.Glacier.Model.DeleteVaultNotificationsRequest
		$DeleteVaultNotificationsRequest.AccountId = "-"
		$DeleteVaultNotificationsRequest.VaultName = $VaultName
		try {
			$DeleteVaultNotifications = $GlacierClient.DeleteVaultNotifications($DeleteVaultNotificationsRequest)
			Write-Host "Notifications for $VaultName have been deleted."
			return
		}
		catch [Amazon.Glacier.AmazonGlacierException] {
			Write-Host $_.Exception.Message
			return
		}
	}
	end {}
}

function Get-GlacierJob {

<#
	.SYNOPSIS
		Gets Glacier vault jobs.
	
	.DESCRIPTION
		Get all Glacier jobs on a specific vault, a specific job on a specific vault, or all jobs on all vaults returned by Get-GlacierVault.
		Results can be filtered using the Completed switch, or the StatusCode parameter. Valid StatusCode options are InProgress, Succeeded, or Failed.
	
	.PARAMETER VaultName
		 The VaultName parameter is mandatory and accepts pipeline input.
	
	.PARAMETER JobId
		Optional parameter. This is returned from New-GlacierJob.
	
	.PARAMETER StatusCode
		Optional parameter that returns filtered job results. Valid StatusCode options are InProgress, Succeeded, or Failed.
		
	.PARAMETER Completed
		Optional switch that only returns completed jobs.
		
	.EXAMPLE
		C:\PS> Get-GlacierJob -VaultName <vault>
	
	.EXAMPLE
		C:\PS> Get-GlacierJob -VaultName <vault> -Completed
		
	.EXAMPLE
		C:\PS> Get-GlacierJob -VaultName <vault> -StatusCode <status>
		
	.EXAMPLE
		C:\PS> Get-GlacierVault -VaultName <vault> | Get-GlacierJob
		
	.EXAMPLE
		C:\PS> Get-GlacierVault | Get-GlacierJob
	
	.INPUTS
		The VaultName parameter can accept pipeline input from Get-GlacierVault.
		
	.OUTPUTS
		Amazon.Glacier.Model.DescribeJobResult. Get-GlacierJob returns Glacier vault jobs formatted as an object.
		
	.LINK
		New-GlacierJob
		Get-GlacierJobOutput
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$VaultName,
		[Parameter()]
		[string]$JobId,
		[Parameter()]
		[ValidateSet("InProgress","Succeeded","Failed")]
		[string]$StatusCode,
		[Parameter()]
		[switch]$Completed,
		[Parameter()]
		[int]$Limit
	)
	begin {}
	process {
		if ($JobId) {
			$DescribeJobRequest = New-Object Amazon.Glacier.Model.DescribeJobRequest
			$DescribeJobRequest.AccountId = "-"
			$DescribeJobRequest.VaultName = $VaultName
			$DescribeJobRequest.JobId = $JobId
			try {
				$DescribeJob = $GlacierClient.DescribeJob($DescribeJobRequest)
				return $DescribeJob.DescribeJobResult
			}
			catch [Amazon.Glacier.AmazonGlacierException] {
				Write-Host $_.Exception.Message
				return
			}
		} else {
			$ListJobsRequest = New-Object Amazon.Glacier.Model.ListJobsRequest
			$ListJobsRequest.AccountId = "-"
			$ListJobsRequest.VaultName = $VaultName
			if ($StatusCode) {
				switch ($StatusCode) {
					"inprogress" {
						$ListJobsRequest.Statuscode = "InProgress"
					}
					"succeeded" {
						$ListJobsRequest.Statuscode = "Succeeded"
					}
					"failed" {
						$ListJobsRequest.Statuscode = "Failed"
					}
				}
			}
			if ($Completed) {
				$ListJobsRequest.Completed = $true
			}
			if ($Limit) {
				$ListJobsRequest.Limit = $Limit
			}
			try {
				$ListJobs = $global:GlacierClient.ListJobs($ListJobsRequest)
				if ($ListJobs.ListJobsResult.Marker) {
					do {
					$ListJobs = $global:GlacierClient.ListJobs($ListJobsRequest)
					Write-Output $ListJobs.ListJobsResult.JobList
					$ListJobsResult.Marker = $ListJobs.ListJobsResult.Marker
					} until ($ListJobs.ListJobsResult.Marker -eq $null)
				} else {
					if ($ListJobs.ListJobsResult.Joblist) {
						return $ListJobs.ListJobsResult.JobList
					} else {
						Write-Host "No jobs available for $VaultName."
						return
					}
				}
			}
			catch [Amazon.Glacier.AmazonGlacierException] {
				Write-Host $_.Exception.Message
				return
			}
		}
	}
	end {}
}

function New-GlacierJob {

<#
	.SYNOPSIS
		Creates a new Glacier vault job.
	
	.DESCRIPTION
		Creates a new Glacier vault job. Valid job operations are ArchiveJob and InventoryJob. ArchiveJob will create an archive retrieval and InventoryJob will create an inventory retrieval.
	
	.PARAMETER VaultName
		 The VaultName parameter is mandatory and does not accept pipeline input.
	
	.PARAMETER TopicArn
		This parameter is optional, but an SNS Topic or a vault notification configuration must exist.
		
	.PARAMETER ArchiveJob
		Switch specifying the new job will be an archive retrieval.
		
	.PARAMETER InventoryJob
		Switch specifying the new job will be an inventory retrieval.
		
	.PARAMETER Format
		Parameter specifying an archive retrieval job to be in either CSV or JSON format.
	
	.INPUTS
		None. New-GlacierJob does not accept pipeline input.
	
	.OUTPUTS
		Amazon.Model.InitiateJobResult. New-GlacierJob returns job request results formatted as an object.
		
	.LINK
		Get-GlacierJob
		Get-GlacierJobOutput
		Get-SNSTopic
		Set-SNSTopic
		Get-GlacierVaultNotification
		Set-GlacierVaultNotification
	
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[string]$VaultName,
		[Parameter()]
		[string]$TopicArn,
		[Parameter()]
		[ValidatePattern("[\x20-\x7E]")]
		[ValidateLength(1,1024)]
		[string]$Description,
		[Parameter(Mandatory=$true, ParameterSetName='ArchiveJob')]
		[switch]$ArchiveJob,
		[Parameter(Mandatory=$true, ParameterSetName='ArchiveJob')]
		[string]$ArchiveId,
		[Parameter(Mandatory=$true, ParameterSetName='InventoryJob')]
		[switch]$InventoryJob,
		[Parameter(ParameterSetName='InventoryJob')]
		[ValidateSet("CSV","JSON")]
		[string]$Format
	)
	$InitiateJobRequest = New-Object Amazon.Glacier.Model.InitiateJobRequest
	$InitiateJobRequest.JobParameters = New-Object Amazon.Glacier.Model.JobParameters
	$InitiateJobRequest.AccountId = "-"
	$InitiateJobRequest.VaultName = $VaultName
	if ($Description) {
		$InitiateJobRequest.JobParameters.Description = $Description
	}
	if ($ArchiveJob) {
		$InitiateJobRequest.JobParameters.ArchiveId = $ArchiveId
		$InitiateJobRequest.JobParameters.Type = "archive-retrieval"
	}
	if ($InventoryJob) {
		$InitiateJobRequest.JobParameters.Type = "inventory-retrieval"
		if ($Format) {
			$InitiateJobRequest.JobParameters.Format = $Format
		}
	}
	if (!$TopicArn) {
		if ($Notifications = Get-GlacierVaultNotification -VaultName $VaultName) {
			$TopicArn = $Notifications.SNSTopic
		} else {
			Write-Host "You must supply a valid SNS Topic Arn, or set vault notifications using Set-GlacierVaultNotification."
			return
		}
	}
	if ( ($TopicArn) -and ($TopicArn -notmatch "(arn:aws:)") ) {
		Write-Host "You must supply a valid SNS Topic Arn."
		return
	} else {
		$InitiateJobRequest.JobParameters.SNSTopic = $TopicArn
	}
	try {
		$InitiateJob = $global:GlacierClient.InitiateJob($InitiateJobRequest)
		return $InitiateJob.InitiateJobResult
	}
	catch [Amazon.Glacier.AmazonGlacierException] {
		Write-Host $_.Exception.Message
		return
	}
}

function Get-GlacierJobOutput {

<#
	.SYNOPSIS
		Retrieves Glacier job output.
	
	.DESCRIPTION
			Retrieves Glacier job output. Depending on the job type that was initiated, this will either retrieve an inventory (as JSON or CSV) or an archive.
	
	.PARAMETER JobId
		The JobId parameter is mandatory and accepts pipeline input.
		
	.PARAMETER VaultName
		 The VaultName parameter is mandatory and does not accept pipeline input.
		 
	.PARAMETER FilePath
		 The FilePath parameter is mandatory and does not accept pipeline input.
		 
	.EXAMPLE
		C:\PS> Get-GlacierJobOutput -JobId <job> -VaultName <vault> -FilePath <file>
		 
	.INPUTS
		The JobId parameter accepts pipeline input, but due to the Filepath parameter it can only accept one pipelined input.
		
	.OUTPUTS
		File. Depending on the job type that was initiated, this will either retrieve an inventory (as JSON or CSV) or an archive.
	
	.LINK
		Get-GlacierJob
		New-GlacierJob
		Remove-GlacierArchive
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$JobId,
		[Parameter(Mandatory=$true)]
		[string]$VaultName,
		[Parameter(Mandatory=$true)]
		[string]$Filepath
	)
	try {
		$FileStream = New-Object System.IO.FileStream $Filepath, "Create"
		$JobOutputRequest = New-Object Amazon.Glacier.Model.GetJobOutputRequest
		$JobOutputRequest.AccountId = "-"
		$JobOutputRequest.JobId = $JobId
		$JobOutputRequest.VaultName = $VaultName
		$GetJobOutput = $global:GlacierClient.GetJobOutput($JobOutputRequest)
		[System.IO.Stream]$Stream = $GetJobOutput.GetJobOutputResult.Body
		[byte[]]$buffer = New-Object byte[] 65536
		$total = 0
		while (($length = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
			$FileStream.Write($buffer, 0, $length)
			$total += $length
			$PercentComplete = "{0:N0}" -f (([int]$total/$GetJobOutput.ContentLength) * 100)
			Write-Progress -Activity "Downloading Job Output" -PercentComplete $PercentComplete
		}
		$FileStream.Close()
	}
	catch [Amazon.Glacier.AmazonGlacierException] {
		Write-Host $_.Exception.Message
		return
	}
}

function New-GlacierUpload {

<#
	.SYNOPSIS
		Uploads a new archive to a Glacier vault.
	
	.DESCRIPTION
		Uploads a new archive or archives to a Glacier vault. The filename of the upload is saved as the archive's description. Pipe output from New-GlacierUpload using Out-File to save the upload ArchiveId for future use.
		
	.PARAMETER VaultName
		 The VaultName parameter is mandatory and does not accept pipeline input.
		 
	.PARAMETER FullName
		The FullName parameter is mandatory and accepts pipeline input. Fullnames with spaces must be enclosed with quotation marks.
		
	.EXAMPLE
		C:\PS> New-GlacierUpload -VaultName <vault> -FullName <file>
		
	.EXAMPLE
		C:\PS> Get-ChildItem | New-GlacierUpload -VaultName <vault>
	
	.INPUTS
		The FullName parameter accepts pipeline input.
	
	.OUTPUTS
		Amazon.Glacier.Transfer.UploadResult. New-GlacierUpload returns upload results formatted as an object.
	
	.LINK
		New-GlacierJob
		Get-GlacierJobOutput
		Remove-GlacierArchive
	
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[string]$VaultName,
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[string]$FullName
	)
	begin {}
	process {
		if(!(Test-Path -LiteralPath $FullName)) {
			Write-Host "Fullname is invalid."
			return
		}
		if (Test-Path -LiteralPath $FullName -PathType Leaf) {
			$FileInfo = Get-ChildItem $FullName
			$ArchiveDescription = $FileInfo.Name
			$UploadOptions = New-Object Amazon.Glacier.Transfer.UploadOptions
			$UploadOptions.StreamTransferProgress += [System.EventHandler[Amazon.Runtime.StreamTransferProgressArgs]] {
				param($sender,[Amazon.Runtime.StreamTransferProgressArgs]$e)
				if ($e.PercentDone -ne 100) {
					Write-Progress -Activity "Archive Upload" -Status "Uploading $FullName to $VaultName" -PercentComplete $e.PercentDone
				}
			}
			try {
				$Upload = $global:ArchiveTransferManager.Upload($VaultName,$ArchiveDescription,$FullName,$UploadOptions)
				Write-Host "Upload $FullName to $VaultName complete."
				return $Upload
			}
			catch [Amazon.Glacier.AmazonGlacierException] {
				Write-Host $_.Exception.Message
				return
			}
		} else {
			Write-Host "$Fullname is a directory and wasn't uploaded."
			return
		}
	}
	end {}
}

function Get-SNSTopic {

<#
	.SYNOPSIS
		Gets a list of SNS topic ARNs (Amazon Resource Name).
	
	.DESCRIPTION
		Gets a list SNS topic ARNs (Amazon Resource Name) or a specific SNS topic's attributes.
	
	.PARAMETER TopicArn
		The SNS Topic's ARN (Amazon Resource Name). This parameter is optional and does not accept pipeline input.
		
	.EXAMPLE
		C:\PS> Get-SNSTopic
		
	.EXAMPLE
		C:\PS> Get-SNSTopic -TopicArn <arn>
	
	.INPUTS
		None. Get-SNSTopic does not accept pipeline input.
	
	.OUTPUTS
		Amazon.SimpleNotificationService.Model.TopicAttribute. Get-SNSTopic with the TopicArn parameter returns topic attributes formatted as an object.
		
		Amazon.SimpleNotificationService.Model.Topic. Get-SNSTopic without the TopicArn parameter returns all TopicArns formatted as an object.
		
	.LINK
		Set-SNSTopic
		New-SNSTopic
		Remove-SNSTopic
		Get-SNSSubscription
		New-SNSSubscription
		Remove-SNSSubscription
	
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter()]
		[string]$TopicArn
	)
	if ($TopicArn) {
		if ($TopicArn -match "(arn:aws:)") {
			$GetTopicAttributesRequest = New-Object Amazon.SimpleNotificationService.Model.GetTopicAttributesRequest
			$GetTopicAttributesRequest.TopicArn = $TopicArn
			try {
				$GetTopicAttributes = $global:SNSClient.GetTopicAttributes($GetTopicAttributesRequest)
				return $GetTopicAttributes.GetTopicAttributesResult.Attributes
			}
			catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
				Write-Host $_.Exception.Message
				return
			} 
		} else {
			Write-Host "TopicArn must be valid."
			return
		}
	} else {
		$ListTopicsRequest = New-Object Amazon.SimpleNotificationService.Model.ListTopicsRequest
		try {
			$ListTopics = $global:SNSClient.ListTopics($ListTopicsRequest)
			if ($ListTopicsRequest.ListTopicsResult.NextToken) {
				do {
				$ListTopics = $global:SNSClient.ListTopics($ListTopicsRequest)
				Write-Output $ListTopics.ListTopicsResult.Topics
				$ListTopicsRequest.ListTopicsResult.NextToken = $ListTopics.ListTopicsResult.NextToken
				} until ($ListTopicsRequest.ListTopicsResult.NextToken -eq $null)
			} else {
				return $ListTopics.ListTopicsResult.Topics
			}
		}
		catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
			Write-Host $_.Exception.Message
			return
		}
	}
}

function Set-SNSTopic {

<#
	.SYNOPSIS
		Sets an SNS Topic's description.
	
	.DESCRIPTION
		Sets an SNS Topic's description. The Amazon API alllows for changes to be made to the Policy, DeliveryPolicy, and DisplayName. Set-SNSTopic currently only sets the DisplayName.
	
	.PARAMETER TopicArn
		The SNS Topic's ARN (Amazon Resource Name). This parameter is mandatory and does not accept pipeline input.
	
	.PARAMETER DisplayName
		The SNS Topic's DisplayName. This parameter is mandatory and does not accept pipeline input.
		
	.EXAMPLE
		C:\PS> Set-SNSTopic -TopicArn <arn> -DisplayName <name>
	
	.INPUTS
		None. Set-SNSTopic does not accept pipeline input.
	
	.OUTPUTS
		Amazon.SimpleNotificationService.Model.TopicAttribute. Set-SNSTopic returns topic attributes formatted as an object.
	
	.LINK
		Get-SNSTopic
		New-SNSTopic
		Remove-SNSTopic
		Get-SNSSubscription
		New-SNSSubscription
		Remove-SNSSubscription
	
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[string]$TopicArn,
		[Parameter(Mandatory=$true)]
		[string]$DisplayName
	)
	$SetTopicAttributesRequest = New-Object Amazon.SimpleNotificationService.Model.SetTopicAttributesRequest
	$SetTopicAttributesRequest.TopicArn = $TopicArn
	$SetTopicAttributesRequest.AttributeName = "DisplayName"
	$SetTopicAttributesRequest.AttributeValue = $DisplayName
	try {
		$SetTopicAttributes = $global:SNSClient.SetTopicAttributes($SetTopicAttributesRequest)
		return Get-SNSTopic -TopicARN $TopicArn
	}
	catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
		Write-Host $_.Exception.Message
		return
	}
}

function New-SNSTopic {

<#
	.SYNOPSIS
		Creates a new SNS Topic.
	
	.DESCRIPTION
		Creates a new SNS Topic based on the provided topic name and display name.
	
	.PARAMETER TopicName
		This parameter is mandatory and does not provide pipeline input. The TopicName must not contain spaces.
	
	.PARAMETER DisplayName
		This parameter is mandatory and does not provide pipeline input.
		
	.EXAMPLE
		C:\PS> New-SNSTopic -TopicName <name> -DisplayName <name>
		
	.INPUTS
		None. New-SNSTopic does not accept pipeline input.
	
	.OUTPUTS
		System.String. New-SNSTopic returns the newly created topic ARN (Amazon Resource Name) formatted as a string.
		
	.LINK
		Get-SNSTopic
		Set-SNSTopic
		Remove-SNSTopic
		Get-SNSSubscription
		New-SNSSubscription
		Remove-SNSSubscription
		
	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[string]$TopicName,
		[Parameter(Mandatory=$true)]
		[string]$DisplayName
	)
	if ($TopicName -notmatch "^\S+$") {
		Write-Host "The TopicName Parameter must not include spaces."
		return
	}
	$CreateTopicRequest = New-Object Amazon.SimpleNotificationService.Model.CreateTopicRequest
	$CreateTopicRequest.Name = $TopicName
	try {
		if ($CreateTopic = $global:SNSClient.CreateTopic($CreateTopicRequest)) {
			$SetTopicAttributes = Set-SNSTopic -TopicArn $CreateTopic.CreateTopicResult.TopicArn -DisplayName $DisplayName
		}
		return $CreateTopic.CreateTopicResult.TopicArn
	}
	catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
		Write-Host $_.Exception.Message
		return
	}
}

function Remove-SNSTopic {

<#
	.SYNOPSIS
		Removes an SNS Topic.
	
	.DESCRIPTION
		Removes an SNS Topic identified by its Topic ARN. Remove-SNSTopic can also remove topics returned by Get-SNSTopic.
	
	.PARAMETER TopicArn
		The SNS Topic's ARN (Amazon Resource Name). This parameter is mandatory and accepts pipeline input.
		
	.EXAMPLE
		C:\PS> Remove-SNSTopic -TopicArn <arn>
		
	.EXAMPLE
		C:\PS> Get-SNSTopic -TopicArn <arn> | Remove-SNSTopic
		
	.EXAMPLE
		C:\PS> Get-SNSTopic | Remove-SNSTopic
	
	.INPUTS
		The TopicArn parameter accepts pipeline input.
	
	.OUTPUTS
		System.String. Remove-SNSTopic writes a topic removal confirmation formatted as a string.
		
	.LINK
		Get-SNSTopic
		Set-SNSTopic
		New-SNSTopic
		Get-SNSSubscription
		New-SNSSubscription
		Remove-SNSSubscription

	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true,
					ValueFromPipelineByPropertyName=$true)]
		[string]$TopicArn
	)
	begin {}
	process {
		$DeleteTopicRequest = New-Object Amazon.SimpleNotificationService.Model.DeleteTopicRequest
		$DeleteTopicRequest.TopicARN = $TopicArn
		try {
			$DeleteTopic = $global:SNSClient.DeleteTopic($DeleteTopicRequest)
			Write-Host "SNS Topic $TopicArn has been removed."
			return
		}
		catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
			Write-Host $_.Exception.Message
			return
		}
	}
	end {}
}

function Get-SNSSubscription {

<#
	.SYNOPSIS
		Get SNS Subscriptions associated with an SNS Topic's ARN (Amazon Resource Name).
	
	.DESCRIPTION
		Gets SNS Subscriptions associated with an SNS Topic's ARN (Amazon Resource Name) or all SNS Subscriptions on the account.
	
	.PARAMETER TopicArn
		The SNS Topic's ARN (Amazon Resource Name). This parameter is optional accepts pipeline input.
		
	.PARAMETER SubscriptionArn
		The SNS Subscription's ARN (Amazon Resource Name). This parameter is optional and accepts pipeline input
	
	.EXAMPLE
		C:\PS> Get-SNSSubscription
	
	.EXAMPLE
		C:\PS> Get-SNSSubscription -TopicArn <arn>
		
	.EXAMPLE
		C:\PS> Get-SNSTopic -TopicArn <arn> | Get-SNSSubscription
		
	.EXAMPLE
		C:\PS> Get-SNSTopic | Get-SNSSubscription
		
	.INPUTS
		TopicArn. This parameter is optional and accepts pipeline input.
	
	.OUTPUTS
		Amazon.SimpleNotificationService.Model.Subscription. Get-SNSSubscriptions returns results formatted as an object.
		
	.LINK
		Get-SNSTopic
		Set-SNSTopic
		New-SNSTopic
		Remove-SNSTopic
		New-SNSSubscription
		Remove-SNSSubscription

	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string]$TopicArn,
		[Parameter()]
		[string]$SubscriptionArn
	)
	begin {}
	process {
	if ($TopicArn) {
			$ListSubscriptionsByTopicRequest = New-Object Amazon.SimpleNotificationService.Model.ListSubscriptionsByTopicRequest
			$ListSubscriptionsByTopicRequest.TopicARN = $TopicArn
			try {
				$ListSubscriptionsByTopic = $global:SNSClient.ListSubscriptionsByTopic($ListSubscriptionsByTopicRequest)
				if ($ListSubscriptionsByTopic.ListSubscriptionsResult.NextToken) {
					do {
					$ListSubscriptions = $global:SNSClient.ListSubscriptions($ListSubscriptionsRequest)
					Write-Output $ListSubscriptions.ListSubscriptionsResult.Subscriptions
					$ListSubscriptionsRequest.NextToken = $ListSubscriptions.ListSubscriptionsResult.NextToken
					} until ($ListSubscriptions.ListSubscriptionsResult.NextToken -eq $null)
				} else {
					return $ListSubscriptionsByTopic.ListSubscriptionsByTopicResult.Subscriptions
				}
			}
			catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
				Write-Host $_.Exception.Message
				return
			}
		} elseif ($SubscriptionArn) {
			$GetSubscriptionAttributesRequest = New-Object Amazon.SimpleNotificationService.Model.GetSubscriptionAttributesRequest
			$GetSubscriptionAttributesRequest.SubscriptionArn = $SubscriptionArn
			try {
				$GetSubscriptionAttributes = $global:SNSClient.GetSubscriptionAttributes($GetSubscriptionAttributesRequest)
				Write-Output $GetSubscriptionAttributes.Attributes
			}
			catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
				Write-Host $_.Exception.Message
				return
			}
		} else {
			$ListSubscriptionsRequest = New-Object Amazon.SimpleNotificationService.Model.ListSubscriptionsRequest
			try {
				$ListSubscriptions = $SNSClient.ListSubscriptions($ListSubscriptionsRequest)
				if ($ListSubscriptions.ListSubscriptionsRequest.NextToken) {
					do {
					$ListSubscriptions = $global:SNSClient.ListSubscriptions($ListSubscriptionsRequest)
					Write-Output $ListSubscriptions.ListSubscriptionsResult.Subscriptions
					$ListSubscriptionsRequest.NextToken = $ListSubscriptions.ListSubscriptionsResult.NextToken
					} until ($ListSubscriptions.ListSubscriptionsResult.NextToken -eq $null)
				} else {
				return $ListSubscriptions.ListSubscriptionsResult.Subscriptions
				}
			}
			catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
				Write-Host $_.Exception.Message
				return
			}
		}
	}
	end {}
}

function New-SNSSubscription {

<#
	.SYNOPSIS
		Creates a new SNS Subscription.
	
	.DESCRIPTION
		Creates a new SNS Subscription from a TopicArn, Protocol (notification type), and Endpoint (notification delivery endpoint). Subscriptions must be confirmed at the delivery endpoint. If your mail client is Entourage, it strips out the confirmation URL. Please use another mail client to view subscription confirmation messages.
	
	.PARAMETER TopicArn
		The SNS Topic's ARN (Amazon Resource Name). This parameter is mandatory and does not accept pipeline input.
	
	.PARAMETER Protocol
		The SNS Subscription's notification type. Valid protocols are email, email-json, and SMS.
		Specifying 'email' as the protocol delivers the notification message to an email address via SMTP. Specifying 'email-json' delivers the notification message in JSON format to an email address via SMTP.
		This parameter is mandatory and does not accept pipeline input.
		
	.PARAMETER Endpoint
		Valid SMS numbers must start with 1 and be exactly 11 digits in length. Amazon accepts only US-based phone numbers at this time.
		Valid email addresses must be properly formatted.
		HTTP, HTTPS, and Amazon SQS subscription endpoints are currently not supported by New-SNSSubscription.
		This parameter is mandatory and does not accept pipeline input.
	
	.INPUTS
		None. New-SNSSubscription does not accept pipeline input.
		
	.OUTPUTS
		System.String. New-SNSSubscription writes a subscription confirmation messages formatted as a string.
		
	.LINK
		Get-SNSTopic
		Set-SNSTopic
		New-SNSTopic
		Remove-SNSTopic
		Get-SNSSubscription
		Remove-SNSSubscription

	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
		[string]$TopicArn,
		[Parameter(Mandatory=$true)]
		[ValidateSet("email","sms","email-json")]
		[string]$Protocol,
		[Parameter(Mandatory=$true)]
		[string]$Endpoint
	)
	$SubscribeRequest = New-Object Amazon.SimpleNotificationService.Model.SubscribeRequest
	$SubscribeRequest.TopicArn = $TopicArn
	$SubscribeRequest.Protocol = $Protocol
	$SubscribeRequest.Endpoint = $Endpoint
	if (($Protocol -eq "sms") -and (($Endpoint -notmatch ("^1") -or $Endpoint.Length -ne "11"))) {
		Write-Host "Invalid phone number: Amazon SMS numbers must start with 1 and be exactly 11 digits in length."
		return
	}
	try {
		$Subscribe = $global:SNSClient.Subscribe($SubscribeRequest)
		Write-Host "SNS Subscription request is pending confirmation at the specified endpoint."
		return
	}
	catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
		Write-Host $_.Exception.Message
		return
	}
}

function Remove-SNSSubscription {

<#
	.SYNOPSIS
		Removes an SNS Subscription.
	
	.DESCRIPTION
		Removes an SNS Subscription. Remove-SNSSubscription can also remove subscriptions returned by Get-SNSSubscription. 
	
	.PARAMETER SubscriptionArn
		The SNS Subscription's ARN (Amazon Resource Name). This parameter is mandatory and accepts pipeline input.
	
	.EXAMPLE
		C:\PS> Remove-SNSSubscription -SubscriptionArn <arn>
		
	.EXAMPLE
		C:\PS> Get-SNSSubscription -SubscriptionArn <arn> | Remove-SNSSubscription
		
	.EXAMPLE
		C:\PS> Get-SNSSubscription | Remove-SNSSubscription

	.INPUTS
		TopicArn. This parameter is optional and accepts pipeline input.
		SubscriptionArn. This parameter is optional and accepts pipeline input.
	
	.OUTPUTS
		System.String. Remove-SNSSubscription writes a subscription deletion confirmation formatted as a string.
		
	.LINK
		Get-SNSTopic
		Set-SNSTopic
		New-SNSTopic
		Remove-SNSTopic
		Get-SNSSubscription
		New-SNSSubscription

	.NOTES
		Author: Damian Karlson, @sixfootdad
		Date: November 2012
#>

	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
		[string]$SubscriptionArn
	)
	$UnsubscribeRequest = New-Object Amazon.SimpleNotificationService.Model.UnsubscribeRequest
	$UnsubscribeRequest.SubscriptionArn = $SubscriptionArn
	try {
		$Unsubscribe = $SNSClient.Unsubscribe($UnsubscribeRequest)
		Write-Host "Subscription has been removed."
		return
	}
	catch [Amazon.SimpleNotificationService.AmazonSimpleNotificationServiceException] {
		Write-Host $_.Exception.Message
		return
	}
}