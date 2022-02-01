name=$1
forcebuild=$2
if [[ $name == "forcebuild" ]]
then
    name=''
    forcebuild='forcebuild'
fi
if [[ -z $name ]]
then
    name='merlin-tkgonaws'
    printf "\nAssuming default container name: $name"
fi
isexists=$(docker images | grep "\<$name\>")
if [[ -z $isexists || $forcebuild == "forcebuild" ]]
then
    docker build . -t $name
fi

isexist=$(ls Dockerfile)
# isexist2=$(ls binaries/Dockerfile)
if [[ -z $isexist ]] #-z $isexist2 ]]
then
    numberoftarfound=$(find binaries/*tar* -type f -printf "." | wc -c)
    if [[ $numberoftarfound == 1 ]]
    then
        tanzubundlename=$(find binaries/*tar* -printf "%f\n")
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
        printf "\nNo tanzu bundle found. Please place the tanzu bindle in binaries dir and ./start.sh again. Exiting...\n"
        exit 1
    fi

    if [[ $tanzubundlename == "tce"* ]]
    then
        printf "\ntce detected..\n"
        cp Dockerfile.tce0.9.1 Dockerfile
    else
        printf "\ntkg detected..\n"
        cp Dockerfile.tkg1.4 Dockerfile
    fi
fi

docker run -it --rm --net=host --add-host kubernetes:127.0.0.1 -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name $name $name

