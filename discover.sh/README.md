
```sh
ifconfig en0 | grep inet | awk '$1=="inet" {print $2}'
xhost+
docker run  --net=host -it --privileged --rm --name discover -e DISPLAY=192.168.29.176:0 -v /tmp/.X11-unix:/tmp/.X11-unix discover.sh
```

- https://blog.wenhaolee.com/browser-gui-in-docker-for-mac/
- http://fabiorehm.com/blog/2014/09/11/running-gui-apps-with-docker/