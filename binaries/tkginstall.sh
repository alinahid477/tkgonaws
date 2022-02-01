#!/bin/bash
export $(cat /root/.env | xargs)


returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}

helpFunction()
{
    printf "\nNo parameter to pass.\nThis is a wizard based installation.\n"
    printf "\tThe wizard will take care of few of the installation pre-requisites through asking for some basic input. Just follow the prompt.\n"
    printf "\tOnce the prerequisites conditions are staisfied the wizard will then proceed on launching tkg installation UI.\n"
    printf "\tWhen using bastion host the wizard will connect to bastion host and check for the below prequisites:\n"
    printf "\t\t- Bastion host must have docker engine (docker ce or docker ee) installed. (if you do not have it installed please do so now)\n"
    printf "\t\t- Bastion host must have php installed. (if you do not have it installed please do so now).\n"
    printf "\n\n"
    returnOrexit
}


while getopts "h:" opt
do
    case $opt in
        h ) helpFunction ;;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

printf "\n***************************************************"
printf "\n********** Starting *******************************"
printf "\n***************************************************"



if [ -z "$COMPLETE" ]
then

    printf "\n\nchecking pre-requisites..\n"
    if [[ -z $TKG_PLAN ]]
    then
        printf "\n\nERROR: No TKG_PLAN value found. Exiting...\n\n"
        returnOrexit
    fi

    printf "\n"
    read -p "AWS_REGION:(Type in a new value or press enter to keep it as \"$AWS_REGION\") " inp
    if [[ -n $inp ]]
    then
        AWS_REGION=$inp
    fi

    if [[ -z $AWS_REGION ]]
    then
        printf "\n\n\nYou must provide a valid value of AWS_REGION\n"
    fi


    printf "\n\nChecking Key pair validity with name $AWS_REGION-keypair in the region $AWS_REGION...\n"

    KPNAME=$(aws ec2 describe-key-pairs --key-name $AWS_REGION-keypair --output text | awk '{print $3}')
    KPFILENAME=$(ls -l ~/.ssh/$AWS_REGION-keypair.pem)

    if [[ -n $KPNAME && -n $KPFILENAME ]]
    then
        printf "\n\nKey Pair already exists, no need to create a new one...\n"    
    else
        createnew='n'
        if [[ -n $KPNAME ]]
        then
            printf "\n\nKeyPair exist in AWS but missing in local ~/.ssh/$AWS_REGION-keypair.pem.\nDeleting exisitng key pair $KPNAME from AWS $AWS_REGION...\n"
            aws ec2 delete-key-pair --key-name $KPNAME --region $AWS_REGION
            createnew='y'
        fi

        if [[ -n $KPFILENAME ]]
        then
            printf "\n\nKey pair file exists in local: ~/.ssh/$AWS_REGION-keypair.pem BUT is not associated with AWS region.\n"
            printf "Importing file:///root/.ssh/$AWS_REGION-keypair.pem to AWS Account for region $AWS_REGION with name: $AWS_REGION-keypair ...\n"    
            aws ec2 import-key-pair --key-name  $AWS_REGION-keypair --public-key-material file:///root/.ssh/$AWS_REGION-keypair.pem
        fi

        if [[ $createnew == 'y' ]]
        then
            printf "\n\nNo key pair found in local or in aws region: $AWS_REGION.\n"
            printf "Registering an SSH Public Key with Your AWS Account in region $AWS_REGION and creating localfile: ~/.ssh/$AWS_REGION-keypair.pem ...\n"
            aws ec2 create-key-pair --key-name $AWS_REGION-keypair --output json --region $AWS_REGION | jq .KeyMaterial -r > ~/.ssh/$AWS_REGION-keypair.pem
        fi        
    fi

    printf "\n\nKey-Pair created. To review visit https://$AWS_REGION.console.aws.amazon.com/ec2/v2/home?region=$AWS_REGION#KeyPairs:"
    while true; do
        read -p "Ok to continue? [y/n] " yn
        case $yn in
            [Yy]* ) printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    printf "\n\n\n Launching management cluster create UI.\n"
    

    tanzu management-cluster create --ui -y -v 9 --browser none



    ISPINNIPED=$(kubectl get svc -n pinniped-supervisor | grep pinniped-supervisor)

    if [[ ! -z "$ISPINNIPED" ]]
    then
        printf "\n\n\nBelow is details of the service for the auth callback url. Update your OIDC/LDAP callback accordingly.\n"
        kubectl get svc -n pinniped-supervisor
        printf "\nDocumentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-configure-id-mgmt.html\n"
    fi

    printf "\n\n\nDone. Marking as commplete.\n\n\n"
    printf "\nCOMPLETE=YES" >> /root/.env
else
    printf "\n\n\n Already marked as complete in the .env. If this is not desired then remove the 'COMPLETE=yes' from the .env file.\n"
fi

printf "\n\n\nRUN ~/binaries/tkgworkloadwizard.sh --help to start creating workload clusters.\n\n\n"