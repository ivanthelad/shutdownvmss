#!/bin/bash
echo $HOSTNAME


ignoregrouplist=$EXCLUDE_RG
includegrouplist=$INCLUDE_RG


echo "building filter based on. Excluding takes priority  "
echo "   excluding [$ignoregrouplist]"
echo "   including [$includegrouplist]"

 

function  isempty ()
{
   paramname="$1"
   paramvalue="$2"

      if test -z "$paramvalue" 
      then
            echo -e "   \e[31mError\e[0m:$paramname is EMPTY, Please paas a parameter for the $paramname"
          return 0 
     else
           echo  -e "   \e[32m OK\e[0m   :$paramname=$paramvalue is set"
      fi
      return 1

}
function genFilter()
{
        ## #ignore list 
    IFS=',' read -ra my_array <<< "$ignoregrouplist"
    for i in "${my_array[@]}"
    do
            excludepath="${excludepath:+$excludepath }resourceGroup!='$i' && "
    done

    IFS=',' read -ra includearray <<< "$includegrouplist"
    for i in "${includearray[@]}"
    do
        echo "goo $i"
            includepath="${includepath:+$includepath }resourceGroup=='$i' || "
    done
    echo "** exclude filter complete: jmespath= $excludepath"
    echo "** include  filter complete: jmespath= $includepath"

    if [[ -z $excludepath && ! -z $includepath ]]; then 
        echo 1: no exclude but with inlcude
        filter="[? ${includepath::-4}]"
    elif [[ ! -z $excludepath && -z $includepath ]]; then 
        
        echo 2: no include but with include  
        filter="[?${excludepath::-4}]"

    elif [[ -z $excludepath &&  -z $includepath ]]; then 

        echo 3: no filters
        filter="[]"
        
    else 

        echo " 4 both include and exclude  filters "
        filter="[]"
        filter="[?${excludepath::-4} && ( ${includepath::-4})]"
    fi
    #filter="[?${excludepath::-4} && ( ${includepath::-4})]"
    echo "Final filter to be applied = $filter"
}
if isempty "SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"; then 
            echo -e "      \e[33mWarn\e[0m: SUBSCRIPTION_ID not set."
            exit -1
fi
if isempty "INCLUDE_RG" "$INCLUDE_RG"; then 
            echo -e "      \e[33mWarn\e[0m: INCLUDE_RG not set. All Resource groups will be included "
            
fi
if isempty "EXCLUDE_RG" "$EXCLUDE_RG"; then 
            echo -e "      \e[33mWarn\e[0m: EXCLUDE_RG not set. No Resource Groups will be excludes"
fi

genFilter

if "$USE_MSI"; then 
    echo login in with msi
    az login --identity
fi
az account set --subscription=$SUBSCRIPTION_ID
mydate=`date '+%Y-%m-%d %H:%M:%S'`
#az vmss list --query "[].{Name:name,rg:resourceGroup}" -o tsv | while IFS= read -r line;  do echo fff "$line"; done
echo "--------------------------------------" | tee -a  shutdown.log
echo "shutdown time $mydate"
echo "--------------------------------------" | tee -a  shutdown.log
echo "stopping scale sets " | tee -a  shutdown.log

az vmss list --query "$filter.{Name:name,rg:resourceGroup}" -o tsv  | while IFS= read -r line;  do
    VMMS_NAME=$(echo $line| cut -d " " -f1)

    VMMS_RG=$(echo $line| cut -d " " -f2)
   echo Stopping vmss $VMMS_NAME in RG   $VMMS_RG | tee -a  shutdown.log
   az vmss deallocate -n $VMMS_NAME -g $VMMS_RG --no-wait

 done
echo --------------------------------------- |tee -a  shutdown.log
echo stopping vms >> shutdown.log
az vm list --query "$filter.{id:id,resourceGroup:resourceGroup,name:name}" -o tsv | while IFS= read -r line;  do
    vmid=$(echo $line| cut -d " " -f1)
    vm_name=$(echo $line| cut -d " " -f3)

    vm_rg=$(echo $line| cut -d " " -f2)
   echo Stopping vm $vm_name in RG $vm_rg | tee -a  shutdown.log
   az vm deallocate --id $vmid --no-wait
 done

az container list --query "$filter.{id:id,resourceGroup:resourceGroup,name:name}" -o tsv  | while IFS= read -r line;  do
    containerid=$(echo $line| cut -d " " -f1)
    container_name=$(echo $line| cut -d " " -f3)
    container_rg=$(echo $line| cut -d " " -f2)
   echo Stopping container  $container_name  in RG $container_rg | tee -a  shutdown.log
   az container stop --name $container_name --resource-group $container_rg    --no-wait
 done
 echo --------------------------------------- |tee -a  shutdown.log
echo stopping gws >> shutdown.log
az network application-gateway list --query "$filter.{id:id,resourceGroup:resourceGroup,name:name}" -o tsv  | while IFS= read -r line;  do
    appgw_id=$(echo $line| cut -d " " -f1)
    appgw_name=$(echo $line| cut -d " " -f3)
    appgw_rg=$(echo $line| cut -d " " -f2)
   echo Stopping appgw  $appgw_name  in RG $appgw_rg | tee -a  shutdown.log
  az network application-gateway stop -n $appgw_name  -g  $appgw_rg --no-wait
done

echo stopping AKS >> shutdown.log
az aks   list --query "$filter.{id:id,resourceGroup:resourceGroup,name:name}" -o tsv  | while IFS= read -r line;  do
echo $line
    aks_id=$(echo $line| cut -d " " -f1)
    aks_name=$(echo $line| cut -d " " -f3)
    aks_rg=$(echo $line| cut -d " " -f2)
   echo Stopping aks  $aks_name  in RG $aks_rg  $aks_id
   #az aks stop -n $aks_name  -g  $aks_rg --no-wait
   # Get the node pools of the AKS cluster
    node_pools=$(az aks nodepool list --cluster-name $aks_name --resource-group $aks_rg --query "[].name" -o tsv)

    # Iterate over the node pools
    for node_pool in $node_pools
    do
         echo "Stopping Node pool: $node_pool for AKS cluster: $aks_name in Resource Group: $aks_rg"

        az aks nodepool stop --resource-group $aks_rg --cluster-name $aks_name --nodepool-name $node_pool
    
    done
done
findate=`date '+%Y-%m-%d %H:%M:%S'`
echo "--------------------------------------" | tee -a  shutdown.log
echo " Finished shutdown $mydate @ $findate "  | tee -a  shutdown.log
echo "--------------------------------------" | tee -a  shutdown.log

#az vm deallocate --ids $(az vm list --query "[].id" -o tsv| tee -a logs/shutdown-$mydate.log) --no-wait 2>&1 &
#az vmss deallocate --instance-ids $(az vmss list --query "[].id" -o tsv| tee -a logs/shutdown-$mydate.log) --no-wait 2>&1 &