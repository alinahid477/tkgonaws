#!/bin/bash
printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x


export $(cat /root/.env | xargs)

printf "\n\n\nChecking access using aws cli...\n"
test=$(aws ec2 describe-key-pairs)
echo $test
if [ -z "$test" ]
then
    printf "\n\n\nFailed access check.\nFix .env variables and try again.\nExit...\n"
    exit 1
fi 

printf "\n\nChecking TMC ... \n\n"
ISTMCEXISTS=$(tmc --help)
sleep 1
if [ -z "$ISTMCEXISTS" ]
then
    printf "\n\ntmc command does not exist.\n\n"
    printf "\n\nChecking for binary presence...\n\n"
    IS_TMC_BINARY_EXISTS=$(ls ~/binaries/ | grep tmc)
    sleep 2
    if [ -z "$IS_TMC_BINARY_EXISTS" ]
    then
        printf "\n\nBinary does not exist in ~/binaries directory.\n"
        printf "\nIf you could like to attach the newly created TKG clusters to TMC then please download tmc binary from https://mapbuapj.tmc.cloud.vmware.com/clidownload and place in the ~/binaries directory.\n"
        printf "\nAfter you have placed the binary file you can, additionally, uncomment the tmc relevant in the Dockerfile.\n\n"
    else
        printf "\n\nTMC binary found...\n"
        printf "\n\nAdjusting Dockerfile\n"
        sed -i '/COPY binaries\/tmc \/usr\/local\/bin\//s/^# //' ~/Dockerfile
        sed -i '/RUN chmod +x \/usr\/local\/bin\/tmc/s/^# //' ~/Dockerfile
        sleep 2
        printf "\nDONE..\n"
        printf "\n\nPlease build this docker container again and run.\n"
        exit 1
    fi
else
    printf "\n\ntmc command found.\n\n"
fi

printf "\nChecking Tanzu plugin...\n"

ISINSTALLED=$(tanzu management-cluster --help)
if [[ $ISINSTALLED == *"unknown"* ]]
then
    printf "\n\ntanzu plugin management-cluster not found. installing...\n"
    tanzu plugin install management-cluster
    printf "\n\n"
fi

ISINSTALLED=$(tanzu cluster --help)
if [[ $ISINSTALLED == *"unknown"* ]]
then
    printf "\n\ntanzu plugin cluster not found. installing...\n"
    tanzu plugin install cluster
    printf "\n\n"
fi

ISINSTALLED=$(tanzu login --help)
if [[ $ISINSTALLED == *"unknown"* ]]
then
    printf "\n\ntanzu plugin login not found. installing...\n"
    tanzu plugin install login
    printf "\n\n"
fi

ISINSTALLED=$(tanzu kubernetes-release --help)
if [[ $ISINSTALLED == *"unknown"* ]]
then
    printf "\n\ntanzu plugin kubernetes-release not found. installing...\n"
    tanzu plugin install kubernetes-release
    printf "\n\n"
fi

ISINSTALLED=$(tanzu pinniped-auth --help)
if [[ $ISINSTALLED == *"unknown"* ]]
then
    printf "\n\ntanzu plugin pinniped-auth not found. installing...\n"
    tanzu plugin install pinniped-auth
    printf "\n\n"
fi

ISINSTALLED=$(tanzu alpha --help)
if [[ $ISINSTALLED == *"unknown"* ]]
then
    printf "\n\ntanzu optional plugin alpha not found. installing...\n"
    tanzu plugin install alpha
    printf "\n\n"
fi

tanzu plugin list

while true; do
    read -p "Confirm if plugins are installed? [y/n] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done




printf "\nYour available wizards are:\n"
echo -e "\t~/binaries/tkginstall.sh"
echo -e "\t~/binaries/tkgworkloadwizard.sh --help"
echo -e "\t~/binaries/attach_to_tmc.sh --help"

cd ~

/bin/bash