#!/bin/bash
export $(cat /root/.env | xargs)

printf "\n***************************************************"
printf "\n********** Starting *******************************"
printf "\n***************************************************"



if [ -z "$COMPLETE" ]
then

    printf "\n\n\n"
    read -p "AWS_REGION:(Type in a new value or press enter to keep it as \"$AWS_REGION\") " inp
    if [[ ! -z $inp ]]
    then
        AWS_REGION=$inp
    fi

    if [ -z "$AWS_REGION" ]
    then
        printf "\n\n\nYou must provide a valid value of AWS_REGION\n"
    fi

    KPNAME=$(aws ec2 describe-key-pairs --key-name $AWS_REGION-keypair --output text | awk '{print $3}')
    KPFILENAME=$(ls -l ~/.ssh/$AWS_REGION-keypair.pem)

    if [[ ! -z $KPNAME && ! -z $KPFILENAME ]]
    then
        printf "\n\n\nKey Pair already exists, no need to create a new one...\n"    
    else
        if [[ ! -z $KPNAME ]]
        then
            printf "\n\n\nDeleting exisitng key pair...\n"    
            aws ec2 delete-key-pair --key-name $KPNAME --region $AWS_REGION 
        fi
        if [[ ! -z $KPFILENAME ]]
        then
            printf "\n\n\nKey pair file exists.\nImporting to Your AWS Account...\n"    
            aws ec2 import-key-pair --key-name  $AWS_REGION-keypair --public-key-material file:///root/.ssh/$AWS_REGION-keypair.pem
        else
            printf "\n\n\nRegistering an SSH Public Key with Your AWS Account...\n"
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
    

    tanzu management-cluster create --ui -y -v 8 --browser none



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