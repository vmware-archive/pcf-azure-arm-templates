$StorageName = "pioneertest"
$ResourceGroup = "test-01"
$Location = $env:AZURE_DEFAULT_LOCATION
$SubscriptionName = $env:AZURE_SUBSCRIPTION_NAME
$OpsManURI = $env:OpsManURI
# set global verbosity for all commands.
$PSDefaultParameterValues['*:Verbose'] = $true

Write-Host "Cleaning out old Resource Group."
Remove-AzureRmResourceGroup -Name $ResourceGroup -Verbose -Force

Write-Host "Creating Resource Group and Storage Accounts"
New-AzureRmResourceGroup -Name $ResourceGroup -Location $Location
New-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -AccountName $StorageName -Kind Storage -Type "Standard_LRS" -Location $Location

$Context = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey (Get-AzureRmStorageAccountKey -StorageAccountName $StorageName -ResourceGroupName $ResourceGroup).Value[0]

Write-Host "Creating storage containers."

$arr = @("vhds", "opsmanager", "bosh", "stemcell")

New-AzureStorageContainer -Name opsman-image -Permission Blob -Context $Context
for ($i = 0; $i -lt $arr.Length; $i++) { New-AzureStorageContainer -Name $arr[$i] -Context $Context }
New-AzureStorageTable -Name stemcells -Context $Context

Write-Host "Copying OpsMan blob."
Start-AzureStorageBlobCopy -AbsoluteUri $OpsManURI -DestContainer "opsman-image" -DestBlob "image.vhd" -DestContext $Context

Get-AzureStorageBlobCopyState -Context $Context -Blob "image.vhd" -Container "opsman-image" -WaitForComplete

Write-Host "done."