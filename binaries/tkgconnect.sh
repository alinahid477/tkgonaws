#!/bin/bash
export $(cat /root/.env | xargs)
returned='n'
returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        returned='y'
        return
    else
        exit
    fi
}


helpFunction()
{
    printf "\nYou must provide required parameter -n\n\n"
    echo "Usage: $0"
    echo -e "\t-n name of cluster to connect"
    exit 1 # Exit script after printing help
}



function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

unset clustername
while getopts "n:" opt
do
    case $opt in
        n ) clustername="$OPTARG";;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done


if [[ -z $clustername ]]
then
    printf "\nError: no clustername given. Please use the -n to pass the clustername.\n"
    exit
fi

function bastion_host_tunnel {
    # $1=endpoint url or kubeconfig file
    if [[ -n $BASTION_HOST ]]
    then
        printf "\nBastion host detected."
        printf "\nExtracting cluster endpoint for $clustername from .env file...\n"
        sleep 1
        clusterendpoint=$(cat ~/.env | awk -F= '$1=="'$clustername'_CLUSTER_ENDPOINT"{print $2}' | xargs)
        
        if [[ -z $clusterendpoint ]]
        then
            printf "\nError: ${clustername}_CLUSTER_ENDPOINT not found in .env file. Ensure that ${clustername}_CLUSTER_ENDPOINT value exists.\n"
            printf "\nError: Unable to create tunnel.\n"
            exit
        fi
        
        isurl=$(echo $clusterendpoint | grep -io 'http[s]*://[^"]*')
        if [[ -z $isurl ]]
        then
            kubeconfigfile=~/.kube/config
            proto="$(echo $clusterendpoint | grep :// | sed -e's,^\(.*://\).*,\1,g')"
            serverurl="$(echo ${clusterendpoint/$proto/} | cut -d/ -f1)"
            port="$(echo $serverurl | awk -F: '{print $2}')"
            serverurl="$(echo $serverurl | awk -F: '{print $1}')"
            if [[ $serverurl == 'kubernetes' ]]
            then
                printf "\nERROR: found ${clustername}_CLUSTER_ENDPOINT=$clusterendpoint. $serverurl is not allowed here.exiting...\n"
                exit
            fi
            if [[ -z $port ]]
            then
                if [[ -z $proto || $proto == 'http://' ]]
                then
                    port=80
                else 
                    port=443
                fi                    
            fi
            if [[ -n $serverurl && -n $port ]]
            then
                printf "server url: $serverurl\nport: $port\n"
                fuser -k $port/tcp
                sleep 1
                printf "\nCreating endpoint Tunnel $port:$serverurl:$port through bastion $BASTION_USERNAME@$BASTION_HOST ...\n"
                sleep 1
                ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$serverurl:$port $BASTION_USERNAME@$BASTION_HOST
                # ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$serverurl:443 $BASTION_USERNAME@$BASTION_HOST
                sleep 1
                printf "\n=>Tunnel created.\n"
                isexist=$(cat ~/.kube/config | awk '/'$serverurl'/' | awk '/server:[ ]+http[s]*:/')
                if [[ -n $isexist ]]
                then
                    printf "\nAdjusting kubeconfig for tunneling...\n"
                    sed -i '0,/'$serverurl'/s//kubernetes/' $kubeconfigfile
                    sleep 1
                    printf "==>Done.\n"
                fi
            else
                printf "ERROR: Bastion host specified but error in extracting server and port. Exiting..."
                exit
            fi
        else
            if [[ $TUNNEL_AUTH_ENDPOINT_THROUGH_BASTION == 'YES' ]]
            then
                proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
                # remove the protocol
                url="$(echo ${1/$proto/})"
                host="$(echo ${url} | cut -d/ -f1)"
                port="$(echo $host | awk -F: '{print $2}')"
                host="$(echo $host | awk -F: '{print $1}')"
                if [[ -z $port ]]
                then
                    if [[ -z $proto || $proto == 'http://' ]]
                    then
                        port=80
                    else 
                        port=443
                    fi                    
                fi
                printf "\nendpoint url: \n\tproto: $proto\n\thost: $host\n\tport: $port\n"
                sleep 1
                printf "\nCreating endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...\n"
                sleep 1
                ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$host:$port $BASTION_USERNAME@$BASTION_HOST
                printf "\n==>Tunnel created.\n"
            fi
        fi
    fi
}

if [[ -n $BASTION_HOST ]]
then
    isexists=$(ls ~/.ssh/id_rsa)
    if [[ -z $isexists ]]
    then
        printf "\nERROR: Bastion host parameter supplied BUT no id_rsa file present in .ssh\n"
        sleep 1
        printf "\nPlease place a id_rsa file in ~/.ssh dir"
        printf "\nQuiting...\n\n"

        exit 3
    else
        chmod 600 /root/.ssh/id_rsa
        if [[ $COMPLETE == 'YES' || -n $MANAGEMENT_CLUSTER_ENDPOINT ]]
        then
            bastion_host_tunnel
        else
            printf "\nERROR: .env file does not have either COMPLETE or MANAGEMENT_CLUSTER_ENDPOINT\n"
            printf "\nERROR: This environment is not ready for tanzu connect\n"
            exit
        fi
    fi
fi

contextname=$(parse_yaml $kubeconfigfile | grep "^contexts_name=\"$clustername-" | awk -F= '$1=="contexts_name"{print $2}' | xargs)
if [[ -n $contextname ]]
then
    printf "\nSwitching context to $contextname...\n"
    kubectl config use-context $contextname
    printf "===>DONE.\n\n\n"
else
    printf "\nError: Could not find the right context\n"
    printf "If context is known then please perform 'kubectl config use-context {context-name}'\n\n\n\n"
fi