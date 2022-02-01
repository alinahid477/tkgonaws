#!/bin/bash


unset CLUSTER_NAME
unset CLUSTER_PLAN
unset AWS_VPC_CIDR
unset sharedvpc
unset AWS_PRIVATE_NODE_CIDR
unset AWS_PRIVATE_SUBNET_ID
unset AWS_PRIVATE_SUBNET_ID_1
unset AWS_PRIVATE_SUBNET_ID_2
unset AWS_PUBLIC_SUBNET_ID
unset AWS_PUBLIC_NODE_CIDR
unset AWS_PUBLIC_SUBNET_ID_1
unset AWS_PUBLIC_NODE_CIDR_1
unset AWS_PUBLIC_SUBNET_ID_2
unset AWS_PUBLIC_NODE_CIDR_2

unset AWS_NODE_AZ
unset AWS_NODE_AZ_1
unset AWS_NODE_AZ_2

unset CONTROL_PLANE_MACHINE_TYPE
unset NODE_MACHINE_TYPE


while getopts "n:s:" opt
do
    case $opt in
        n ) clustername="$OPTARG";;
        s ) sharedvpc="$OPTARG"
    esac
done

if [[ -z $clustername ]]
then
    printf "\n Error: No cluster name given. Exit...\n"
    exit 1
fi

# if sharedvpc=y then it is sharedvpc else it is a newvpc
# if sharedvpc is empty then ask the value

if [[ -z $sharedvpc ]]
then
    while true; do
        read -p "Would you like to Deploy a Cluster that Shares a VPC and NAT Gateway(s) with the Management Cluster? [y/n] " yn
        case $yn in
            [Yy]* ) sharedvpc="y"; printf "\nYou confirmed yes\n"; break;;
            [Nn]* ) sharedvpc="n"; printf "\n\nYou confirmed new vpc to be created.\n"; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi
if [[ $sharedvpc != "y" && $sharedvpc != "n" ]]
then
    printf "\n Error: Invalid value for whether to use sharedvpc or not. Please supply s=y or s=n. Exit...\n"
    exit 1
fi


printf "\n\nLooking for management cluster config at: ~/.config/tanzu/tkg/clusterconfigs/\n"
mgmtconfigfile=$(ls ~/.config/tanzu/tkg/clusterconfigs/ | awk -v i=1 -v j=1 'FNR == i {print $j}')
if [[ -z $mgmtconfigfile ]]
then
    printf "\n Error: No management cluster config file found in ~/.tanzu/tkg/clusterconfigs/.\nGENERATION OF WORKLOAD CLUSTER CONFIG FAILED.\nExit...\n"
    exit 1
fi

printf "\n\nUsing management cluster config file: $mgmtconfigfile\n"

mgmtconfigfile=~/.config/tanzu/tkg/clusterconfigs/$mgmtconfigfile 
printf "Extracting values from file: $mgmtconfigfile\n"

vpccidr=$(cat $mgmtconfigfile | grep 'AWS_VPC_CIDR' | awk '{print $2}')
if [[ -n $vpccidr ]]
then
    printf "Extracted vpccidr: $vpccidr\n"
    printf "\nRetrieving VPC ID for CIDR:$vpccidr..\n"
    AWS_VPC_ID=$(aws ec2 --output text --query 'Vpcs[*].{VpcId:VpcId}'  describe-vpcs --filters Name=cidr,Values=$vpccidr)
    printf "\nVPC ID for CIRD for $vpccidr is $AWS_VPC_ID\n"

    printf "\n\nRetrieving Subnet IDs...\n"
    allsubnets=$(aws ec2 --output json --query 'Subnets[*].{SubnetId:SubnetId CidrBlock:CidrBlock Name:Tags[?Key==`Name`].Value|[0]}'  describe-subnets --filters Name=vpc-id,Values=$AWS_VPC_ID)
    printf "\nSubnents associated to the VPC $AWS_VPC_ID are \n$allsubnets\n\n"


    while true; do
        read -p "Is this correct? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi



if [[ -n $mgmtconfigfile ]]
then

    echo "" > ~/workload-clusters/tmp.yaml
    chmod 777 ~/workload-clusters/tmp.yaml
    while IFS=: read -r key val
    do
        if [[ $key == *@("AWS"|"CLUSTER_CIDR"|"SERVICE"|"TKG_HTTP_PROXY_ENABLED"|"IDENTITY_MANAGEMENT_TYPE"|"BASTION_HOST_ENABLED")* ]]
        then
            if [[ "$key" != @("CONTROL_PLANE_MACHINE_TYPE"|"NODE_MACHINE_TYPE") && 
                "$key" != *@("AWS_ACCESS_KEY_ID"|"AWS_SECRET_ACCESS_KEY"|"AWS_SESSION_TOKEN"|"AWS_AMI_ID"|"AWS_B64ENCODED_CREDENTIALS")* &&
                "$key" != *@("AWS_PRIVATE_NODE_CIDR"|"AWS_PUBLIC_NODE_CIDR"|"AWS_PRIVATE_SUBNET_ID"|"AWS_PUBLIC_SUBNET_ID"|"AWS_VPC_CIDR"|"AWS_VPC_ID"|"AWS_NODE_AZ")* ]]
            then
                printf "$key: $(echo $val | sed 's,^ *,,; s, *$,,')\n" >> ~/workload-clusters/tmp.yaml
            fi            
        fi
        


        if [[ $key == *"CLUSTER_PLAN"* ]]
        then
            CLUSTER_PLAN=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
        fi


        if [[ $key == *"AWS_VPC_CIDR"* && $sharedvpc == "y" ]]
        then
            AWS_VPC_CIDR=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
            if [[ -z $AWS_VPC_ID ]]
            then
                printf "\n Error: No VPC ID for $AWS_VPC_CIDR. Exit...\n"
                exit 1
            fi
        fi

        if [[ $key == "AWS_PRIVATE_NODE_CIDR" && $sharedvpc == "y" ]]
        then
            AWS_PRIVATE_NODE_CIDR=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
            # printf "\n\nDEBUG: AWS_PRIVATE_NODE_CIDR=====>$AWS_PRIVATE_NODE_CIDR\n\n"
            AWS_PRIVATE_SUBNET_ID=$(echo $allsubnets | jq -c '.[] | select(.CidrBlock == "'$AWS_PRIVATE_NODE_CIDR'") | .SubnetId')
            # printf "\n\nDEBUG: AWS_PRIVATE_SUBNET_ID=====>$AWS_PRIVATE_SUBNET_ID\n\n"
            # sleep 5
        fi
        if [[ $key == "AWS_PRIVATE_NODE_CIDR_1" && $sharedvpc == "y" ]]
        then
            AWS_PRIVATE_NODE_CIDR_1=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
            if [[ -n  $AWS_PRIVATE_NODE_CIDR_1 ]]
            then
                printf "DEBUG: AWS_PRIVATE_NODE_CIDR_1=====>$AWS_PRIVATE_NODE_CIDR_1"
                sleep 5
                AWS_PRIVATE_SUBNET_ID_1=$(echo $allsubnets | jq -c '.[] | select(.CidrBlock == "'$AWS_PRIVATE_NODE_CIDR_1'") | .SubnetId')
            fi
        fi
        if [[ $key == "AWS_PRIVATE_NODE_CIDR_2" && $sharedvpc == "y" ]]
        then
            AWS_PRIVATE_NODE_CIDR_2=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
            if [[ -n  $AWS_PRIVATE_NODE_CIDR_2 ]]
            then
                AWS_PRIVATE_SUBNET_ID_2=$(echo $allsubnets | jq -c '.[] | select(.CidrBlock == "'$AWS_PRIVATE_NODE_CIDR_2'") | .SubnetId')
            fi
        fi


        if [[ $key == "AWS_PUBLIC_NODE_CIDR" && $sharedvpc == "y" ]]
        then
            AWS_PUBLIC_NODE_CIDR=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
            if [[ -n  $AWS_PUBLIC_NODE_CIDR ]]
            then
                AWS_PUBLIC_SUBNET_ID=$(echo $allsubnets | jq -c '.[] | select(.CidrBlock == "'$AWS_PUBLIC_NODE_CIDR'") | .SubnetId')
            fi
        fi
        if [[ $key == "AWS_PUBLIC_NODE_CIDR_1" && $sharedvpc == "y" ]]
        then
            AWS_PUBLIC_NODE_CIDR_1=$(echo $val | sed 's,^ *,,; s, *$,,')
            if [[ -n  $AWS_PUBLIC_NODE_CIDR_1 ]]
            then
                AWS_PUBLIC_SUBNET_ID_1=$(echo $allsubnets | jq -c '.[] | select(.CidrBlock == "'$AWS_PUBLIC_NODE_CIDR_1'") | .SubnetId')
            fi
        fi
        if [[ $key == "AWS_PUBLIC_NODE_CIDR_2" && $sharedvpc == "y" ]]
        then
            AWS_PUBLIC_NODE_CIDR_2=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
            if [[ -n  $AWS_PUBLIC_NODE_CIDR_2 ]]
            then
                AWS_PUBLIC_SUBNET_ID_2=$(echo $allsubnets | jq -c '.[] | select(.CidrBlock == "'$AWS_PUBLIC_NODE_CIDR_2'") | .SubnetId')
            fi
        fi





        if [[ $key == "AWS_NODE_AZ" ]]
        then
            AWS_NODE_AZ=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
        fi
        if [[ $key == "AWS_NODE_AZ_1" ]]
        then
            AWS_NODE_AZ_1=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
        fi
        if [[ $key == "AWS_NODE_AZ_2" ]]
        then
            AWS_NODE_AZ_2=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
        fi


        if [[ $key == *"CONTROL_PLANE_MACHINE_TYPE"* ]]
        then
            CONTROL_PLANE_MACHINE_TYPE=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
        fi

        if [[ $key == *"NODE_MACHINE_TYPE"* ]]
        then
            NODE_MACHINE_TYPE=$(echo $val | sed 's,^ *,,; s, *$,,' | xargs)
        fi


        # echo "key=$key --- val=$(echo $val | sed 's,^ *,,; s, *$,,')"
    done < "$mgmtconfigfile"

    printf "\n\nFew more additional input required...\n\n"


    while true; do
        read -p "CLUSTER_NAME:(press enter to keep value extracted from parameter \"$clustername\") " inp
        if [[ -z $inp ]]
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
    if [[ -z $inp ]]
    then
        inp=$CLUSTER_PLAN
    else 
        CLUSTER_PLAN=$inp
    fi
    printf "CLUSTER_PLAN: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "AWS_NODE_AZ:(press enter to keep extracted default \"$AWS_NODE_AZ\") " inp
    if [[ -z $inp ]]
    then
        inp=$AWS_NODE_AZ
    else 
        AWS_NODE_AZ=$inp
    fi
    printf "AWS_NODE_AZ: $inp\n" >> ~/workload-clusters/tmp.yaml
    
    printf "\n\n"

    if [[ -z $AWS_NODE_AZ_1 && $CLUSTER_PLAN == "prod" ]]
    then
        while true; do
            read -p "type the value for AWS_NODE_AZ_1: " inp
            if [[ -z $inp ]]
            then
                printf "\nThis is a required field. You must provide a value."
            else
                printf "AWS_NODE_AZ_1: $inp\n" >> ~/workload-clusters/tmp.yaml
                break
            fi                
        done
    else
        if [[ -n $AWS_NODE_AZ_1 ]]
        then
            read -p "AWS_NODE_AZ_1:(press enter to keep extracted default \"$AWS_NODE_AZ_1\") " inp
            if [[ -z $inp ]]
            then
                inp=$AWS_NODE_AZ_1
            else 
                AWS_NODE_AZ_1=$inp
            fi
            printf "AWS_NODE_AZ_1: $inp\n" >> ~/workload-clusters/tmp.yaml
        fi        
    fi
    printf "\n\n"

    if [[ -z $AWS_NODE_AZ_2 && $CLUSTER_PLAN == "prod" ]]
    then
        while true; do
            read -p "type the value for AWS_NODE_AZ_2: " inp
            if [[ -z $inp ]]
            then
                printf "\nThis is a required field. You must provide a value."
            else
                printf "AWS_NODE_AZ_2: $inp\n" >> ~/workload-clusters/tmp.yaml
                break
            fi                
        done
    else
        if [[ -n $AWS_NODE_AZ_2 ]]
        then
            read -p "AWS_NODE_AZ_2:(press enter to keep extracted default \"$AWS_NODE_AZ_2\") " inp
            if [[ -z $inp ]]
            then
                inp=$AWS_NODE_AZ_2
            else 
                AWS_NODE_AZ_2=$inp
            fi
            printf "AWS_NODE_AZ_2: $inp\n" >> ~/workload-clusters/tmp.yaml
        fi
    fi
    printf "\n\n"

    if [[ $sharedvpc == "y" ]]
    then
        # THIS IS USING SHARE VPC AND SUBNET (this is the recommended approach in my openion because of 
            # https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-aws.html#aws-resources 
            # && 
            # https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html)
        read -p "AWS_VPC_ID:(press enter to keep extracted default \"$AWS_VPC_ID\") " inp
        if [[ -z $inp ]]
        then
            inp=$AWS_VPC_ID
        else 
            AWS_VPC_ID=$inp
        fi
        printf "AWS_VPC_ID: $AWS_VPC_ID\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"

        read -p "AWS_PRIVATE_SUBNET_ID:(press enter to keep extracted default \"$AWS_PRIVATE_SUBNET_ID\") " inp
        if [[ -z $inp ]]
        then
            inp=$AWS_PRIVATE_SUBNET_ID
        else 
            AWS_PRIVATE_SUBNET_ID=$AWS_PRIVATE_SUBNET_ID
        fi
        printf "AWS_PRIVATE_SUBNET_ID: $AWS_PRIVATE_SUBNET_ID\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"


        if [[ -z $AWS_PRIVATE_NODE_CIDR_1 && $CLUSTER_PLAN == "prod" ]]
        then
            # --> This condition means -- User created DEV management but trying to create PROD workload
            # WHEN PROD YOU MUST PROVIDE 1
            while true; do
                read -p "type the value for AWS_PRIVATE_NODE_CIDR_1 or AWS_PRIVATE_SUBNET_ID_1: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    if [[ "$inp" == *\/* ]]
                    then
                        printf "AWS_PRIVATE_NODE_CIDR_1: $inp\n" >> ~/workload-clusters/tmp.yaml
                    else
                        printf "AWS_PRIVATE_SUBNET_ID_1: $inp\n" >> ~/workload-clusters/tmp.yaml
                    fi
                    
                    break
                fi                
            done
        else
            read -p "AWS_PRIVATE_SUBNET_ID_1:(press enter to keep extracted default \"$AWS_PRIVATE_SUBNET_ID_1\") " inp
            if [[ -z $inp ]]
            then
                inp=$AWS_PRIVATE_SUBNET_ID_1
            else 
                AWS_PRIVATE_SUBNET_ID_1=$inp
            fi
            printf "AWS_PRIVATE_SUBNET_ID_1: $AWS_PRIVATE_SUBNET_ID_1\n" >> ~/workload-clusters/tmp.yaml
        fi
        printf "\n\n"
        if [[ -z $AWS_PRIVATE_NODE_CIDR_2 && $CLUSTER_PLAN == "prod" ]]
        then
            # --> This condition means -- User created DEV management but trying to create PROD workload
            # WHEN PROD YOU MUST PROVIDE 2
            while true; do
                read -p "type the value for AWS_PRIVATE_NODE_CIDR_2 or AWS_PRIVATE_SUBNET_ID_2: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    if [[ "$inp" == *\/* ]]
                    then
                        printf "AWS_PRIVATE_NODE_CIDR_2: $inp\n" >> ~/workload-clusters/tmp.yaml
                    else
                        printf "AWS_PRIVATE_SUBNET_ID_2: $inp\n" >> ~/workload-clusters/tmp.yaml
                    fi
                    
                    break
                fi                
            done
        else
            read -p "AWS_PRIVATE_SUBNET_ID_2:(press enter to keep extracted default \"$AWS_PRIVATE_SUBNET_ID_2\") " inp
            if [[ -z $inp ]]
            then
                inp=$AWS_PRIVATE_SUBNET_ID_2
            else 
                AWS_PRIVATE_SUBNET_ID_2=$inp
            fi
            printf "AWS_PRIVATE_SUBNET_ID_2: $AWS_PRIVATE_SUBNET_ID_2\n" >> ~/workload-clusters/tmp.yaml
        fi
        printf "\n\n"


        read -p "AWS_PUBLIC_SUBNET_ID:(press enter to keep extracted default \"$AWS_PUBLIC_SUBNET_ID\") " inp
        if [[ -z $inp ]]
        then
            inp=$AWS_PUBLIC_SUBNET_ID
        else 
            AWS_PUBLIC_SUBNET_ID=$inp
        fi
        printf "AWS_PUBLIC_SUBNET_ID: $AWS_PUBLIC_SUBNET_ID\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"

        if [[ -z $AWS_PUBLIC_NODE_CIDR_1 && $CLUSTER_PLAN == "prod" ]]
        then
            # --> This condition means -- User created DEV management but trying to create PROD workload
            # WHEN PROD YOU MUST PROVIDE 1
            while true; do
                read -p "type the value for AWS_PUBLIC_NODE_CIDR_1 or AWS_PUBLIC_SUBNET_ID_1: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    if [[ "$inp" == *\/* ]]
                    then
                        printf "AWS_PUBLIC_NODE_CIDR_1: $inp\n" >> ~/workload-clusters/tmp.yaml
                    else
                        printf "AWS_PUBLIC_SUBNET_ID_1: $inp\n" >> ~/workload-clusters/tmp.yaml
                    fi
                    
                    break
                fi                
            done
        else
            read -p "AWS_PUBLIC_SUBNET_ID_1:(press enter to keep extracted default \"$AWS_PUBLIC_SUBNET_ID_1\") " inp
            if [[ -z $inp ]]
            then
                inp=$AWS_PUBLIC_SUBNET_ID_1
            else 
                AWS_PUBLIC_SUBNET_ID_1=$inp
            fi
            printf "AWS_PUBLIC_SUBNET_ID_1: $AWS_PUBLIC_SUBNET_ID_1\n" >> ~/workload-clusters/tmp.yaml
        fi
        printf "\n\n"
        if [[ -z $AWS_PUBLIC_NODE_CIDR_2 && $CLUSTER_PLAN == "prod" ]]
        then
            # --> This condition means -- User created DEV management but trying to create PROD workload
            # WHEN PROD YOU MUST PROVIDE 2
            while true; do
                read -p "type the value for AWS_PUBLIC_NODE_CIDR_2 or AWS_PUBLIC_SUBNET_ID_2: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    if [[ "$inp" == *\/* ]]
                    then
                        printf "AWS_PUBLIC_NODE_CIDR_2: $inp\n" >> ~/workload-clusters/tmp.yaml
                    else
                        printf "AWS_PUBLIC_SUBNET_ID_2: $inp\n" >> ~/workload-clusters/tmp.yaml
                    fi
                    
                    break
                fi                
            done
        else
            read -p "AWS_PUBLIC_SUBNET_ID_2:(press enter to keep extracted default \"$AWS_PUBLIC_SUBNET_ID_2\") " inp
            if [[ -z $inp ]]
            then
                inp=$AWS_PUBLIC_SUBNET_ID_2
            else 
                AWS_PUBLIC_SUBNET_ID_2=$inp
            fi
            printf "AWS_PUBLIC_SUBNET_ID_2: $AWS_PUBLIC_SUBNET_ID_2\n" >> ~/workload-clusters/tmp.yaml
        fi
        printf "\n\n"
    else
    # THIS IS CREATING NEW VPC AND SUBNET
        while true; do
            read -p "type the value for AWS_VPC_CIDR: " inp
            if [[ -z $inp ]]
            then
                printf "\nThis is a required field. You must provide a value.\n"
            else
                printf "AWS_VPC_CIDR: $inp\n" >> ~/workload-clusters/tmp.yaml
                break
            fi                
        done
        printf "\n\n"
        while true; do
            read -p "type the value for AWS_PRIVATE_NODE_CIDR: " inp
            if [[ -z $inp ]]
            then
                printf "\nThis is a required field. You must provide a value.\n"
            else
                printf "AWS_PRIVATE_NODE_CIDR: $inp\n" >> ~/workload-clusters/tmp.yaml
                break
            fi                
        done
        printf "\n\n"
        if [[ $CLUSTER_PLAN == "prod" ]] 
        then
        # WHEN PROD YOU MUST PROVIDE 1 & 2
            while true; do
                read -p "type the value for AWS_PRIVATE_NODE_CIDR_1: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    printf "AWS_PRIVATE_NODE_CIDR_1: $inp\n" >> ~/workload-clusters/tmp.yaml
                    break
                fi                
            done
            printf "\n\n"
            while true; do
                read -p "type the value for AWS_PRIVATE_NODE_CIDR_2: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    printf "AWS_PRIVATE_NODE_CIDR_2: $inp\n" >> ~/workload-clusters/tmp.yaml
                    break
                fi                
            done
            printf "\n\n"
        fi


        while true; do
            read -p "type the value for AWS_PUBLIC_NODE_CIDR: " inp
            if [[ -z $inp ]]
            then
                printf "\nThis is a required field. You must provide a value.\n"
            else
                printf "AWS_PUBLIC_NODE_CIDR: $inp\n" >> ~/workload-clusters/tmp.yaml
                break
            fi                
        done
        printf "\n\n"
        if [[ $CLUSTER_PLAN == "prod" ]] 
        then
        # WHEN PROD YOU MUST PROVIDE 1 & 2
            while true; do
                read -p "type the value for AWS_PUBLIC_NODE_CIDR_1: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    printf "AWS_PUBLIC_NODE_CIDR_1: $inp\n" >> ~/workload-clusters/tmp.yaml
                    break
                fi                
            done
            printf "\n\n"
            while true; do
                read -p "type the value for AWS_PUBLIC_NODE_CIDR_2: " inp
                if [[ -z $inp ]]
                then
                    printf "\nThis is a required field. You must provide a value.\n"
                else
                    printf "AWS_PUBLIC_NODE_CIDR_2: $inp\n" >> ~/workload-clusters/tmp.yaml
                    break
                fi                
            done
            printf "\n\n"
        fi
    fi



    printf "\n\n"

    read -p "CONTROL_PLANE_MACHINE_TYPE:(press enter to keep extracted default \"$CONTROL_PLANE_MACHINE_TYPE\") " inp
    if [[ -z $inp ]]
    then
        inp=$CONTROL_PLANE_MACHINE_TYPE
    fi
    printf "CONTROL_PLANE_MACHINE_TYPE: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "NODE_MACHINE_TYPE:(press enter to keep extracted default \"$NODE_MACHINE_TYPE\") " inp
    if [[ -z $inp ]]
    then
        inp=$NODE_MACHINE_TYPE
    fi
    printf "NODE_MACHINE_TYPE: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "CONTROL_PLANE_MACHINE_COUNT:(press enter to keep extracted default \"$(if [ $CLUSTER_PLAN == "dev" ] ; then echo "1"; else echo "3"; fi)\") " inp
    if [[ -z $inp ]]
    then
        if [ $CLUSTER_PLAN == "dev" ] ; then inp=1; else inp=3; fi
    fi
    printf "CONTROL_PLANE_MACHINE_COUNT: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"

    read -p "WORKER_MACHINE_COUNT:(press enter to keep extracted default \"$(if [ $CLUSTER_PLAN == "dev" ] ; then echo "1"; else echo "3"; fi)\") " inp
    if [[ -z $inp ]]
    then
        if [ $CLUSTER_PLAN == "dev" ] ; then inp=1; else inp=3; fi
    fi
    printf "WORKER_MACHINE_COUNT: $inp\n" >> ~/workload-clusters/tmp.yaml

    printf "\n\n"


    read -p "TMC_ATTACH_URL or TMC_CLUSTER_GROUP:(press enter to leave it empty and not attach to tmc OR provide a TMC attach url or Cluster Group Name) " inp
    if [[ ! -z $inp ]]
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
    printf "INFRASTRUCTURE_PROVIDER: aws\n" >> ~/workload-clusters/tmp.yaml
    printf "CNI: antrea\n" >> ~/workload-clusters/tmp.yaml
    printf "NAMESPACE: default\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_AUDIT_LOGGING: true\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_DEFAULT_STORAGE_CLASS: true\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_MHC: \"true\"\n" >> ~/workload-clusters/tmp.yaml
    printf "MHC_UNKNOWN_STATUS_TIMEOUT: 5m\n" >> ~/workload-clusters/tmp.yaml
    printf "MHC_FALSE_STATUS_TIMEOUT: 12m\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_AUTOSCALER: \"false\"\n" >> ~/workload-clusters/tmp.yaml

    printf "AWS_SESSION_TOKEN: $AWS_SESSION_TOKEN\n" >> ~/workload-clusters/tmp.yaml
    printf "AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID\n" >> ~/workload-clusters/tmp.yaml
    printf "AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY\n" >> ~/workload-clusters/tmp.yaml
    # printf "AWS_ACCESS_KEY_ID: <encoded:$(echo $AWS_ACCESS_KEY_ID | base64)>\n" >> ~/workload-clusters/tmp.yaml
    # printf "AWS_SECRET_ACCESS_KEY: <encoded:$(echo $AWS_SECRET_ACCESS_KEY | base64)>\n" >> ~/workload-clusters/tmp.yaml
    

    sleep 2

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
