#!/bin/bash


install_tanzu_plugin()
{
    tanzubundlename=''
    printf "\nChecking tanzu bundle...\n\n"
    cd /tmp
    sleep 1
    numberoftarfound=$(find ./*tar* -type f -printf "." | wc -c)
    if [[ $numberoftarfound == 1 ]]
    then
        tanzubundlename=$(find ./*tar* -printf "%f\n")
    fi
    if [[ $numberoftarfound -gt 1 ]]
    then
        printf "\nfound more than 1 bundles..\n"
        find ./*tar* -printf "%f\n"
        printf "Error: only 1 tar file is allowed in ~/binaries dir.\n"
        printf "\n\n"
        exit 1
    fi

    if [[ $numberoftarfound -lt 1 ]]
    then
        printf "\nNo tanzu bundle found. Please place the tanzu bindle in ~/binaries and rebuild again. Exiting...\n"
        exit 1
    fi
    printf "\nTanzu Bundle: $tanzubundlename. Installing..."
    # sleep 1
    # mkdir tanzu
    # tar -xvf $tanzubundlename -C tanzu/

    if [[ $tanzubundlename == "tce"* ]]
    then
        cd /tmp/tanzu/
        tcefolder=$(ls | grep tce)
        cd $tcefolder
        export ALLOW_INSTALL_AS_ROOT=true
        ./install.sh
    else
        cd /tmp/tanzu/cli/core
        versionfolder=$(ls | grep v)
        cd $versionfolder
        install /tmp/tanzu/cli/core/$versionfolder/tanzu-core-linux_amd64 /usr/local/bin/tanzu
        chmod +x /usr/local/bin/tanzu
        tanzu plugin install --local /tmp/tanzu/cli all
    fi

    cd ~
}


printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x


printf "\n\nChecking TMC ... \n\n"
ISTMCEXISTS=$(tmc --help)
sleep 1
if [[ -z $ISTMCEXISTS ]]
then
    printf "\n\ntmc command does not exist.\n\n"
    printf "\n\nChecking for binary presence...\n\n"
    IS_TMC_BINARY_EXISTS=$(ls ~/binaries/ | grep tmc)
    sleep 2
    if [[ -z $IS_TMC_BINARY_EXISTS ]]
    then
        printf "\n\nBinary does not exist in ~/binaries directory.\n"
        printf "\nIf you could like to attach the newly created TKG clusters to TMC then please download tmc binary from https://{orgname}.tmc.cloud.vmware.com/clidownload and place in the ~/binaries directory.\n"
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

cd ~
printf "\nChecking Tanzu if plugins are installed ...\n"
ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep management-cluster)
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin management-cluster not found. installing...\n\n"
    install_tanzu_plugin
    printf "\n\n"
fi


ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "tanzu-plugin-cluster$")
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin cluster not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "login$")
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin login not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "kubernetes-release$")
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin kubernetes-release not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "pinniped-auth$")
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* || -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin pinniped-auth not found. installing...\n"
    install_tanzu_plugin
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


rm /tmp/TANZU_CONNECT >> /dev/null

cd ~
source ~/binaries/tanzu_connect_management.sh


export $(cat /root/.env | xargs)
printf "\n\n\nChecking AWS access using aws cli...\n"
test=$(aws ec2 describe-key-pairs)
echo $test
if [ -z "$test" ]
then
    printf "\n\n\nFailed access check.\nFix .env variables and try again.\nExit...\n"
    exit 1
fi


printf "\nYour available wizards are:\n"
echo -e "\t~/binaries/tkginstall.sh"
echo -e "\t~/binaries/tkgworkloadwizard.sh --help"
echo -e "\t~/binaries/attach_to_tmc.sh --help"
echo -e "\t~/binaries/tkgconnect.sh --help"

cd ~

/bin/bash