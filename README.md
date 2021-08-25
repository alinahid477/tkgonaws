# tkgonaws


```
docker build . -t tkgonaws
docker run -it --rm --net=host -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name tkgonaws tkgonaws /bin/bash
```