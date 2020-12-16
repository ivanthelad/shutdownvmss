# shutdownvmss
Simple image that uses managed identity to shutdown all vmss, vms in your subscription 
## build 
docker build -t  shutdownvm:latest
docker push shutdownvm:latest 
## run 
best way to run this is by creating a logic app with the following configuration.  the image expects to use a managed identity. by default it can use the default image ivmckinl/shutdownvm:latest
* go to Logic apps and create a empty logic app 
* Create a Schedule tadk that runs at 19:00 hours every day "Recurrence"
* create a Task that create a Container Group "Create or update a container group" 
* This Task will require a connection to Azure API. you will be asked to configure a connection 
* the file LogicApp.json is an example of the logicapp implementation. 
* The logic app  accepts  the following params 
    * SUBSCRIPTION_ID: subscription to shutdown resources in
    * USERMANAGEDIDENTITY. the userdefined managed identity. keep particular attention to the format. this identity require permissions to query and shutdown vms, vmss, containers. it will be assigned to the container when it starts up and the container will use this to shutdown vms. 
    * WORKSPACE_ID: log analytics workspace id. to save container logs 
    * WORKSPACE_KEY: log analytics workspace key. to save container logs  
  ```      "parameters": {
            "$connections": {
                "defaultValue": {},
                "type": "Object"
            },
            "SUBSCRIPTION_ID": {
                "defaultValue": "xxxxx",
                "type": "String"
            },
            "USERMANAGEDIDENTITY": {
                "defaultValue": {
                    "/subscriptions/xxxxx/resourcegroups/xxxxxx/providers/microsoft.managedidentity/userassignedidentities/xxxxx": {}
                },
                "type": "Object"
            },
            "WORKSPACE_ID": {
                "defaultValue": "xxxxxx",
                "type": "String"
            },
            "WORKSPACE_KEY": {
                "defaultValue": "xxxxxx",
                "type": "String"
            }```
        
