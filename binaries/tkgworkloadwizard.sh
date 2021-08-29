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
    printf "\n below information were extracted from the file supplied:\n"
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
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
        source $SCRIPT_DIR/attach_to_tmc.sh -g $TMC_CLUSTER_GROUP -n $CLUSTER_NAME
    fi
    
    

    printf "\n\n\n"
    printf "*******************\n"
    printf "***COMPLETE.....***\n"
    printf "*******************\n"
    printf "\n\n\n"
fi