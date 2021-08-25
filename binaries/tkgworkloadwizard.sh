#!/bin/bash
export $(cat /root/.env | xargs)

helpFunction()
{
    printf "\nYou must provide at least one parameter. (-n parameter recommended)\n\n"
    echo "Usage: $0"
    echo -e "\t-n name of cluster to start wizard OR"
    echo -e "\t-f /path/to/configfile"
    exit 1 # Exit script after printing help
}
unset configfile
unset clustername
while getopts "f:n:" opt
do
    case $opt in
        f ) configfile="$OPTARG" ;;
        n ) clustername="$OPTARG";;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

if [ -z "$configfile" ] 
then
    printf "no config file path.\n"
    if [ -z "$clustername" ] 
    then
        printf "no clustername given.\n"
        helpFunction
    else 
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
        source $SCRIPT_DIR/generate_workload_cluster_config.sh -n $clustername
    fi
fi

if [[ ! -z "$clustername" ]]
then
    ISCONFIGEXIST=$(ls ~/workload-clusters/ | grep $clustername)
    if [[ ! -z "$ISCONFIGEXIST" ]]
    then
        configfile=~/workload-clusters/$(echo "$clustername").yaml
    fi    
else 
    ISCONFIGEXIST=$(ls ~/workload-clusters/$configfile)
fi


# echo "is ... $ISCONFIGEXIST"
if [ -z "$ISCONFIGEXIST" ]
then
    printf "\nhere $configfile\n"
    unset configfile    
fi

if [ -z "$configfile" ]
then
    printf "\n\nNo configfile found.\n\n";
    exit;
else
    printf "\n\nconfigfile: $configfile"

    AZURE_RESOURCE_GROUP=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="AZURE_RESOURCE_GROUP"{print $2}' | xargs)
    CLUSTER_NAME=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="CLUSTER_NAME"{print $2}' | xargs)
    TMC_CLUSTER_GROUP=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="TMC_CLUSTER_GROUP"{print $2}' | xargs)
    if [ -z "$TMC_CLUSTER_GROUP" ]
    then
        TMC_ATTACH_URL=$(cat $configfile | grep -o 'https://[^"]*' | xargs)
        if [[ ! -z $TMC_ATTACH_URL ]]
        then
            TMC_ATTACH_URL=$(echo "\"$TMC_ATTACH_URL\"")
        fi
    fi    
    AZ_NSG_NAME=$(echo "$CLUSTER_NAME-node-nsg")
    printf "\n below information were extracted from the file supplied:\n"
    printf "\nAZURE_RESOURCE_GROUP=$AZURE_RESOURCE_GROUP"
    printf "\nAZ_NSG_NAME=$AZ_NSG_NAME (derived from cluster name)"
    printf "\nCLUSTER_NAME=$CLUSTER_NAME"
    if [[ ! -z $TMC_ATTACH_URL ]]
    then
        printf "\nTMC_ATTACH_URL=$TMC_ATTACH_URL"
    fi
    if [[ ! -z $TMC_CLUSTER_GROUP ]]
    then
        printf "\nTMC_CLUSTER_GROUP=$TMC_CLUSTER_GROUP"
    fi
    printf "\n\n\n"
    while true; do
        read -p "Confirm if the information is correct? [y/n] " yn
        case $yn in
            [Yy]* ) confirmation='yes'; printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ ! -z "$confirmation" ]]
then
    printf "\n\n\n"
    printf "*********************************************\n"
    printf "*** starting tkg k8s cluster provision...****\n"
    printf "*********************************************\n"
    printf "\n\n\n"

    sed -i '$ d' $configfile

    printf "Accept vm image azure sku $TKG_PLAN\n\n"
    az vm image terms accept --publisher vmware-inc --offer tkg-capi --plan $TKG_PLAN --subscription $AZ_SUBSCRIPTION_ID
    printf "\n\nDONE.\n\n\n"

    printf "Creating NSG in azure\n\n"
    az network nsg create -g $AZURE_RESOURCE_GROUP -n $AZ_NSG_NAME --tags tkg $CLUSTER_NAME
    printf "\n\nDONE.\n\n\n"

    

    printf "Creating k8s cluster from yaml called ~/workload-clusters/$CLUSTER_NAME.yaml\n\n"
    tanzu cluster create  --file $configfile -v 9 --tkr $TKR_VERSION # --dry-run > ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    printf "\n\nDONE.\n\n\n"

    # printf "applying ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml\n\n"
    # kubectl apply -f ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    # printf "\n\nDONE.\n\n\n"

    printf "\nWaiting 1 mins to complete cluster create\n"
    sleep 1m
    printf "\n\nDONE.\n\n\n"

    printf "\nGetting cluster info\n"
    tanzu cluster kubeconfig get $CLUSTER_NAME --admin
    printf "\n\nDONE.\n\n\n"

    if [[ ! -z "$TMC_ATTACH_URL" ]]
    then
        printf "\nAttaching cluster to TMC\n"
        printf "\nSwitching context\n"
        kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME    
        kubectl create -f $TMC_ATTACH_URL
        printf "\n\nDONE.\n\n\n"
        printf "\nWaiting 1 mins to complete cluster attach\n"
        sleep 1m
        printf "\n\nDONE.\n\n\n"
    else
        ISTMCEXISTS=$(tmc --help)
        if [[ ! -z $ISTMCEXISTS && ! -z $TMC_CLUSTER_GROUP ]]
        then
            printf "\nAttaching cluster to TMC\n"
            printf "\nChecking existing TMC context..."
            EXISTING_CONTEXT=$(tmc system context list | awk -v i=2 -v j=1 'FNR == i {print $j}')
            if [ -z "$EXISTING_CONTEXT" ]
            then
                if [ -z "$TMC_CONTEXT" ]
                then
                    TMC_CONTEXT=tkgonazure
                fi
                printf "\nNo existing context found. TMC Login using context \'$TMC_CONTEXT\'...\n"
                tmc login --name $TMC_CONTEXT --no-configure
            else
                printf "\nContext $EXISTING_CONTEXT found. Using the context...\n"
                tmc system context use $EXISTING_CONTEXT
            fi
            
            printf "\nTMC Attach..\n"
            epoc=$(date +%s) 
            tmc cluster attach --name $CLUSTER_NAME --cluster-group $TMC_CLUSTER_GROUP --output /tmp/attach-file-$epoc.yaml 
            kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME
            kubectl apply -f /tmp/attach-file-$epoc.yaml
            printf "\nWaiting 1 mins to complete cluster attach\n"
            sleep 1m
            printf "\n\nDONE.\n\n\n"
        fi
    fi
    
    

    printf "\n\n\n"
    printf "*******************\n"
    printf "***COMPLETE.....***\n"
    printf "*******************\n"
    printf "\n\n\n"
fi