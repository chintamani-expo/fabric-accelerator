// Scope
targetScope = 'subscription'

// Parameters
@description('Resource group where Microsoft Fabric capacity will be deployed. Resource group will be created if it doesnt exist')
param dprg string= 'Fabric'

@description('Microsoft Fabric Resource group location')
param rglocation string = 'centralindia'

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string = 'Cost Centre'

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string = 'AdminTeam'

@description('Subject Matter EXpert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string ='SME'

@description('Timestamp that will be appendedto the deployment name')
param deployment_suffix string = utcNow()


@description('Flag to indicate whether auditing of data platform resources should be enabled')
param enable_audit bool = true

@description('Resource group where audit resources will be deployed if enabled. Resource group will be created if it doesnt exist')
param auditrg string= 'fabric-logs'


// Variables
var fabric_deployment_name = 'fabric_dataplatform_deployment_${deployment_suffix}'
var keyvault_deployment_name = 'keyvault_deployment_${deployment_suffix}'
var audit_deployment_name = 'audit_deployment_${deployment_suffix}'
var controldb_deployment_name = 'controldb_deployment_${deployment_suffix}'

// Create data platform resource group
resource fabric_rg  'Microsoft.Resources/resourceGroups@2020-06-01' = {
 name: dprg 
 location: rglocation
 tags: {
        CostCentre: cost_centre_tag
        Owner: owner_tag
        SME: sme_tag
  }
}



 // Create audit resource group
resource audit_rg  'Microsoft.Resources/resourceGroups@2020-06-01' = if(enable_audit) {
  name: auditrg 
  location: rglocation
  tags: {
         CostCentre: cost_centre_tag
         Owner: owner_tag
         SME: sme_tag
   }
 }



// Deploy Key Vault with default access policies using module
module kv './modules/keyvault.bicep' = {
  name: keyvault_deployment_name
  scope: fabric_rg
  params:{
     location: fabric_rg.location
     keyvault_name: 'fabric-keyuser'
     cost_centre_tag: cost_centre_tag
     owner_tag: owner_tag
     sme_tag: sme_tag
  }
}

resource kv_ref 'Microsoft.KeyVault/vaults@2016-10-01' existing = {
  name: kv.outputs.keyvault_name
  scope: fabric_rg
}

//Enable auditing for data platform resources
module audit_integration './modules/audit.bicep' = if(enable_audit) {
  name: audit_deployment_name
  scope: audit_rg
  params:{
    location: audit_rg.location
    audit_storage_name: 'fabricgen2datalake'
    audit_storage_sku: 'Standard_LRS'   
    audit_loganalytics_name: 'fabric-logs'
  }
}

//Deploy Microsoft Fabric Capacity
// module fabric_capacity './modules/fabric-capacity.bicep' = {
  // name: fabric_deployment_name
  // scope: fabric_rg
  // params:{
    // fabric_name: 'bafabric01'
    // location: fabric_rg.location
    // cost_centre_tag: cost_centre_tag
    // owner_tag: owner_tag
    // sme_tag: sme_tag
    // adminUsers: kv_ref.getSecret('fabric-capacity-admin-username')
    // skuName: 'F4' // Default Fabric Capacity SKU F2
  // }
}

// Reference existing Microsoft Fabric Capacity
resource existingFabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' existing = {
  name: 'fabricf2' // Use the name of your existing capacity
  scope: resourceGroup('Fabric') // Ensure the scope is set to the correct resource group
}

// Use the existing capacity in your deployment
output existingCapacityId string = existingFabricCapacity.id
output existingCapacityName string = existingFabricCapacity.name

//Deploy SQL control DB 
module sql_control_db './modules/sqldb.bicep' = {
  name: controldb_deployment_name
  scope: fabric_rg
  params:{
     sqlserver_name: 'fabric-database'
     database_name: 'Fabric' 
     location: fabric_rg.location
     cost_centre_tag: cost_centre_tag
     owner_tag: owner_tag
     sme_tag: sme_tag
//     ad_admin_username:  kv_ref.getSecret('sqlserver-ad-admin-username')
//     ad_admin_sid:  kv_ref.getSecret('sqlserver-ad-admin-sid')  
     auto_pause_duration: 60
         ad_admin_username: 'powerbipro@exponentia.ai'
    ad_admin_sid: 'a2ee70c0-b5d8-4496-b6ed-2fc0b824155e'
     database_sku_name: 'GP_S_Gen5_1' 
     enable_purview: false
     purview_resource: {}
     enable_audit: true
     audit_storage_name: enable_audit?audit_integration.outputs.audit_storage_uniquename:''
     auditrg: enable_audit?audit_rg.name:''
  }
}
