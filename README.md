# debian micro container
## Overview
dmc is a bash script that build micro container images based on debian.
Features :
- Multi-architectures support
- Multi-templates designs, "built your owns"
- debian/ubuntu mirrors support
- Build Micro containers by default
- Able to build "Small" containers too
- Able to build images from sources or from debian packages
- Able to upload the images to a private docker repository
- Kubernetes deployment support

## Why
Using Dockerfile to build container images have many drawbacks.

### Use single layer images
Per nature, a docker image is a multi-layered overlayfs image. Each "RUN" command in a dockerfile create a new layer. Each layer add to the size of the final image. That's the reason why a "RUN apt-get clean" line do NOT reduce the size of the image.
But the larger an image is, the longer docker will take to fetch an image. So the idea is to keep to number of layers in your image as low as possible. 
This script generate single layer images.

### Dont use images from docker hub
Most images from the docker hub are multi-layered, and many images come from untrustable sources. 
Each fecth from your (private) infrastructure can be logged by Docker offering this company many insight on your infrastructure.
Currently docker hub offer a central point to compromise every single private cloud infrastructure. If hackers manage to hack that and compromise the images stored there, your infrastructure will be compromised too.
Finally, hosting your own private docker repository allow you to not use any internet bandwith and thus speed up the docker fetches.

### Why basing on debian
For image size reason, lately the usage have been to base the image on alpine. This trend have been largely suggested by Docker to reduce the stress on the docker hub.
Alpine, have it's roots as a distribution targetting single floppy linux installation. To reach that goal many compromise have been made, one of these have been to use musl-libc which have lower compatibility.
Beside, unlike debian, the alpine projet dont have the work force to maintain up-to-date and patched package for everything.
Debian have a dedicated "security" team which make sure there's no breach in the debian packages.

### Why micro containers
Using debootstrap, we can create rather small image (~60M), but these images containt many tools (systemd, netutils...) that wont be used. Beside adding cluter to the image size, theses tools may offer some attack vector to some hackers. The less an image contain, the less attack surface it offer.
So just like the chroots we were building years ago, the idea is to only include the needed binaries, libraries and datafiles in the images. Nothing more.
The images this script create doesnt even include 'ls' or 'ps'. These tools can be included (using the -T flag) in an image for image debuging purpose. But that should'nt be used for productions image.

### Reproductible builds


## Help 
```
dmc: Debian Micro Container images creator
dmc [-A|--archs ARCHS] [-D|--dist DIST] [-M|--mirror MIRROR] [-H|--host DOCKERHOST] [-T|--tools] [-X|--delete] [-t|--templates TMPTS] [-g|--groups GROUP] [-a|--activity ACT] [-l|--list] [-b|--begin MIN] [-e|--end MAX] [-o|--only ONLY] [-h|--help]
./dmc [ACT]
-A|--archs ARCHS         : Architectures to build for   (DEFAULT: amd64,arm64)
-D|--dist DIST           : Debian disribution           (DEFAULT: buster)
-M|--mirror MIRROR       : Debian mirror                (DEFAULT: http://ftp.fr.debian.org/debian)
-H|--host DOCKERHOST     : Docker hostname              (DEFAULT: )
-T|--tools               : Add some debuging tools to the image (not for production)
-X|--delete              : Remove from kubernetes
-t|--templates TMPTS     : A coma-separated list of templates
-g|--groups GROUP        : A coma-separated list of template groups
-a|--activity ACT        : Select the activity to run
-l|--list                : List all available tasks
-b|--begin MIN           : Begin at that task
-e|--end MAX             : End at that task
-o|--only ONLY           : Only run this step
-h|--help                : Show this help text

Available values for TMPTS (A coma-separated list of templates):
adminer                  : adminer
mariadb                  : mariadb
nginx                    : nginx
php                      : php

Available values for GROUP (A coma-separated list of template groups):
app                      : app
base                     : base
core                     : core

Available values for ACT (Select the activity to run):
update                   : Update the rootfs
setup                    : Setup the builds environnements
create                   : Create the container
load                     : Load a container
```

## Usage instruction
Beside evrything is done by root...

### initial setup
Edit the conf/dmc.conf file to your linking, then :
```
    dmc -a setup
```
to install all the requiered packages and bootstrap the rootfs.

### On using dmc
To build the mariadb container use :
```
    dmc -t mariadb 
```
You can see what is going to be done using the "-l" flag : 
```
    dmc -t mariadb -l
```

## Keeping your images up-to-date
Bellow would be a good batch script to keep your images up to date :
```
    export LOG_level=ALL OUT_level=NONE LOG_dir=/some/path/to/write/logs
    dmc -a update
    dmc -g core,base,app
```

