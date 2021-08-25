#!/bin/bash

while getopts "n:" opt
do
    case $opt in
        n ) clustername="$OPTARG";;
    esac
done

if [ -z "$clustername" ]
then
    printf "\n Error: No cluster name given. Exit..."
    exit 1
fi

printf "\n\nLooking for management cluster config at: ~/.tanzu/tkg/clusterconfigs/\n"
mgmtconfigfile=$(ls ~/.tanzu/tkg/clusterconfigs/ | awk -v i=1 -v j=1 'FNR == i {print $j}')
printf "\n\nRequired management cluster config file: $mgmtconfigfile\n"
if [[ ! -z "$mgmtconfigfile" ]]
then
    mgmtconfigfile=~/.tanzu/tkg/clusterconfigs/$mgmtconfigfile 
    echo "" > ~/workload-clusters/tmp.yaml
    chmod 777 ~/workload-clusters/tmp.yaml
    while IFS=: read -r key val
    do
        if [[ $key == *@("AZURE"|"CLUSTER_CIDR"|"SERVICE"|"TKG_HTTP_PROXY_ENABLED")* ]]
        then
            if [[ "$key" != @("AZURE_CONTROL_PLANE_MACHINE_TYPE"|"AZURE_NODE_MACHINE_TYPE") ]]
            then
                printf "$key: $(echo $val | sed 's,^ *,,; s, *$,,')\n" >> ~/workload-clusters/tmp.yaml
            fi
            
        fi
        
        if [[ $key == *"CLUSTER_PLAN"* ]]
        then
            CLUSTER_PLAN=$(echo $val | sed 's,^ *,,; s, *$,,')
        fi

        if [[ $key == *"AZURE_CONTROL_PLANE_MACHINE_TYPE"* ]]
        then
            AZURE_CONTROL_PLANE_MACHINE_TYPE=$(echo $val | sed 's,^ *,,; s, *$,,')
        fi

        if [[ $key == *"AZURE_NODE_MACHINE_TYPE"* ]]
        then
            AZURE_NODE_MACHINE_TYPE=$(echo $val | sed 's,^ *,,; s, *$,,')
        fi


        # echo "key=$key --- val=$(echo $val | sed 's,^ *,,; s, *$,,')"
    done < "$mgmtconfigfile"

    printf "\n\nFew additional input required\n\n"


    while true; do
        read -p "CLUSTER_NAME:(press enter to keep value extracted from parameter \"$clustername\") " inp
        if [ -z "$inp" ]
        then
            CLUSTER_NAME=$clustername
        else 
            CLUSTER_NAME=$inp
        fi
        if [ -z "$CLUSTER_NAME" ]
        then 
            printf "\nThis is a required field.\n"
        else
            printf "\ncluster name accepted: $CLUSTER_NAME"
            printf "CLUSTER_NAME: $CLUSTER_NAME\n" >> ~/workload-clusters/tmp.yaml
            break
        fi
    done
    

    printf "\n\n"

    read -p "CLUSTER_PLAN:(press enter to keep extracted default \"$CLUSTER_PLAN\") " inp
    if [ -z "$inp" ]
    then
        inp=$CLUSTER_PLAN
    else 
        CLUSTER_PLAN=$inp
    fi
    printf "CLUSTER_PLAN: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "AZURE_CONTROL_PLANE_MACHINE_TYPE:(press enter to keep extracted default \"$AZURE_CONTROL_PLANE_MACHINE_TYPE\") " inp
    if [ -z "$inp" ]
    then
        inp=$AZURE_CONTROL_PLANE_MACHINE_TYPE
    fi
    printf "AZURE_CONTROL_PLANE_MACHINE_TYPE: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "AZURE_NODE_MACHINE_TYPE:(press enter to keep extracted default \"$AZURE_NODE_MACHINE_TYPE\") " inp
    if [ -z "$inp" ]
    then
        inp=$AZURE_NODE_MACHINE_TYPE
    fi
    printf "AZURE_NODE_MACHINE_TYPE: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "CONTROL_PLANE_MACHINE_COUNT:(press enter to keep extracted default \"$(if [ $CLUSTER_PLAN == "dev" ] ; then echo "1"; else echo "3"; fi)\") " inp
    if [ -z "$inp" ]
    then
        if [ $CLUSTER_PLAN == "dev" ] ; then inp=1; else inp=3; fi
    fi
    printf "CONTROL_PLANE_MACHINE_COUNT: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "WORKER_MACHINE_COUNT:(press enter to keep extracted default \"$(if [ $CLUSTER_PLAN == "dev" ] ; then echo "1"; else echo "3"; fi)\") " inp
    if [ -z "$inp" ]
    then
        if [ $CLUSTER_PLAN == "dev" ] ; then inp=1; else inp=3; fi
    fi
    printf "WORKER_MACHINE_COUNT: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"


    read -p "TMC_ATTACH_URL or TMC_CLUSTER_GROUP:(press enter to leave it empty and not attach to tmc OR provide a TMC attach url or Cluster Group Name) " inp
    if [[ ! -z "$inp" ]]
    then
        if [[ $inp == *"https:"* ]]
        then
            printf "TMC_ATTACH_URL: $inp\n" >> ~/workload-clusters/tmp.yaml
        else
            printf "TMC_CLUSTER_GROUP: $inp\n" >> ~/workload-clusters/tmp.yaml
        fi
    fi
    
    
    printf "\n\n======================\n\n"


    printf "ENABLE_CEIP_PARTICIPATION: \"true\"\n" >> ~/workload-clusters/tmp.yaml
    printf "INFRASTRUCTURE_PROVIDER: azure\n" >> ~/workload-clusters/tmp.yaml
    printf "AZURE_ENVIRONMENT: \"AzurePublicCloud\"\n" >> ~/workload-clusters/tmp.yaml
    printf "CNI: antrea\n" >> ~/workload-clusters/tmp.yaml
    printf "NAMESPACE: default\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_AUDIT_LOGGING: true\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_DEFAULT_STORAGE_CLASS: true\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_MHC: \"true\"\n" >> ~/workload-clusters/tmp.yaml
    printf "MHC_UNKNOWN_STATUS_TIMEOUT: 5m\n" >> ~/workload-clusters/tmp.yaml
    printf "MHC_FALSE_STATUS_TIMEOUT: 12m\n" >> ~/workload-clusters/tmp.yaml

    mv ~/workload-clusters/tmp.yaml ~/workload-clusters/$CLUSTER_NAME.yaml;

    while true; do
        read -p "Review generated file ~/workload-clusters/$CLUSTER_NAME.yaml and confirm or modify in the file and confirm to proceed further? [y/n] " yn
        case $yn in
            [Yy]* ) export configfile=$(echo "~/workload-clusters/$CLUSTER_NAME.yaml"); printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
else
    printf "\n\nNo management cluster config file found.\n\nGENERATION OF TKG WORKLOAD CLUSTER CONFIG FILE FAILED\n\n"
fi