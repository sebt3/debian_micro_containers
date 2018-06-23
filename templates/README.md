# Howto write your own template
## Overview

A container template is a single shell file containing a number of functions that describe how to build an image of that template.

## Image creation process
Creating an image mean going throw a number of steps. Each step consist of one (or more) function to execute. Each step function have to be declared using the corresponding step.add.* call. A minimum template only declare one install step. But more complex templates can declare many functions for each step.

All but the Sources steps have these valiables set :

| Name  | Description  |
| ------------ | ------------ |
|  TMPLT | The name of the current template (ex: mariadb) |
|  ARCH  | The current architecture (ex: amd64)  |
|  DIR_SOURCE | The directory where the source for this template are saved |
|  DIR_BUILD | The dirctory to store any intermediate files |
|  DIR_DEST | The Container image root directory |


### Sources

Unlike the next steps, this step doesnt belong to a given architecture and is done once for all architectures. A source step is registered using the `step.add.source` function.

Available variables :

| Name  | Description  |
| ------------ | ------------ |
|  TMPLT | The name of the current template (ex: mariadb) |
|  DIR_SOURCE | The directory where the source for this template are saved |

A typical source function may look like :
```bash
test.source() {
	mkdir -p "$DIR_SOURCE/test"
	curl -sL "http://some.host/some/path/file">"$DIR_SOURCE/test/file"
}
step.add.source test.source "Downloading the source of test"
```

### Build
Build steps are dedicated to build the sources to the currently selected architecture. A template can declare none to many build step using the `step.add.build` function.

Example of a template build steps :
```bash
test.prepare() {
	build.copy.source "test"
}
test.build() {
	set.env
	build.make "test"
}
step.add.build test.prepare "prepare to build test"
step.add.build test.build "build the source of test"
```
`set.env` and `build.make` are cross-compilation aware helper functions that help to create "from sources" templates. There are more. See bellow.

### Install
Install step are dedicated to install the requiered files in the final container root directory for the current architecture. Each template have to provide at least one install step function to be valid using the `step.add.install` function.

```bash
nginx.install() {
	install.init
	install.packages
}
step.add.install nginx.install "Install nginx packages"
```
`install.init` and `install.packages` are helper functions. There's more available. See bellow.

### Clean
The cleanup step aim at removing the cluter after a "make install" command. If no cleanup function is set using `step.add.clean` then the default `clean.install` helper function is used.

### Finish
The finish step aim at making sure there's nothing missing (especially libraries). If no finish step are set up for a template using `step.add.finish`, then the default `finish.default` helper function is used.

## Examples

### Typical package base template
```bash
#@DESC@  nginx from package example
#@GROUP@ core
nginx.prepare.verify() { task.verify.permissive; }
nginx.prepare() {
	prepare.dir "$TMPLT"
	prepare.get.packages libnginx-mod-http-upstream-fair libnginx-mod-http-xslt-filter libnginx-mod-http-image-filter libnginx-mod-http-subs-filter libnginx-mod-http-geoip libnginx-mod-http-echo libnginx-mod-http-dav-ext libnginx-mod-http-auth-pam libnginx-mod-mail libnginx-mod-stream nginx-common nginx-full
}

nginx.install() {
	install.init
	install.packages
}
nginx.config() {
	rm -f "$DIR_DEST/etc/nginx/sites-enabled/default"
	cat >"$DIR_DEST/start.d/nginx" <<ENDF
exec /usr/sbin/nginx -g 'daemon off; master_process on;'
ENDF
}
step.add.build   nginx.prepare		"Prepare the nginx install"
step.add.install nginx.install		"Install nginx"
step.add.install nginx.config		"Configure nginx"
```

### Typical source base template
```bash
#@DESC@  nginx from sources example
#@GROUP@ core
nginx.source() {
	source.apt nginx
}
nginx.prepare() {
	rootfs.build-dep "$ARCH" nginx
}
nginx.configure() {
	build.copy.source nginx
	configure.autoconf nginx --prefix=/usr --with-threads --with-poll_module --with-file-aio
}
nginx.build() {
	build.make nginx
}
nginx.install() {
	install.make nginx
}
nginx.config() {
	rm -f "$DIR_DEST/etc/nginx/sites-enabled/default"
	cat >"$DIR_DEST/start.d/nginx" <<ENDF
exec /usr/sbin/nginx -g 'daemon off; master_process on;'
ENDF
}
step.add.source  nginx.source		"Get the nginx sources from apt"
step.add.build   nginx.prepare		"Install the build dependencies of nginx in the rootfs"
step.add.build   nginx.configure	"Configure the nginx sources"
step.add.build   nginx.build		"Build the nginx sources"
step.add.install nginx.install		"Install nginx"
step.add.install nginx.config		"Configure nginx"
```
### Typical bootstraped image template
Warning this type of template do not generate micro container, but small images. It offer a larger attack surface and should be avoided as much as possible for production image. It can serve as a starting point to build a micro image later though.

```bash
#@DESC@  nginx full container example
#@GROUP@ full
nginx.bootstrap.verify() { task.verify.permissive; }
nginx.bootstrap() {
	install.init
	install.bootstrap "sid"
}

nginx.install.verify() { task.verify.permissive; }
nginx.install() {
	install.install nginx
}
nginx.config() {
	rm -f "$DIR_DEST/etc/nginx/sites-enabled/default"
	cat >"$DIR_DEST/start.d/nginx" <<ENDF
exec /usr/sbin/nginx -g 'daemon off; master_process on;'
ENDF
}
nginx.finish() {
	install.entrypoint
}
step.add.build   nginx.bootstrap	"Bootstrap a full container for nginx"
step.add.install nginx.install		"Install nginx"
step.add.install nginx.config		"Configure nginx"
step.add.finish  nginx.finish		"Install the entrypoint script"
```

## Available helper functions

### rootfs
The rootfs serve as source to copy files from and as target for cross-compilations. Some templates may need that the rootfs contain more stuff

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `rootfs.install` | "$ARCH" *packages*...  | Install *packages* in the $ARCH rootfs |
| `rootfs.build-dep`  | "$ARCH" *package*...  | Install all the build dependencies of a *package* |
| `rootfs.update`  | "$ARCH"  | Update the packages definition  |
| `rootfs.upgrade`  | "$ARCH"  | Keep the rootfs up-to-date |

### Source

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `source.apt`  | package  | take the source from an apt-get source command  |
| `source.git`  | **name** giturl | Clone a git repository for the **name** sub-project |
| `source.file` | **name** url  | Download a tarball and extract it as **name** sub-project |
| `source.github` | **name** reponame  | Get the lastest release from a github project  |

### Build

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `build.copy.source` | **name** | Copy the source of **name** in the build directory |
| `prepare.dir`  | **name** | Create an empty build directory for **name** |
| `set.env`  |   | Setup the environnement variables used for cross-compilation (should be used before any ./configure, cmake or make command) |
| `configure.autoconf` | **name** configure options | Start the ./configure script of the **name** sub-project with the given options in a cross-compilation friendly way |
| `configure.cmake` | **name** cmake options | Start the cmake for the **name** sub-project with the given options in a cross-compilation friendly way |
| `build.make`  | **name** | run "make" in the directory of **name** |

### Install

the Install helper functions split in 5 groups

#### Common install functions

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `install.init` |   | Create the image directory with the bare minimum files |
| `install.lib.missing` |   | Install all the missing lib in the image. (part of the default finish step)  |
| `install.binaries` | commands | Copy commands from the rootfs to the image directory |
| `install.su` |   | Install the "su" command and related configuration |
| `install.sslcerts` |   | Install the SSL root certs |

#### Install from sources

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `install.make` | *name* | run the "make install" command in the *name* sub-project |

#### Install from packages

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `prepare.get.packages` | packages | Download all the package given as agument in the build directory  |
| `install.packages`  |   | Extract all previously downloaded packages to image directory |

#### Install to a bootstraped image

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `install.bootstrap` | dist | use debootstrap to create the base of the container image |
| `install.install`  | packages | Use apt-get install "packages" in the image directory |
| `install.update`  |   | run "apt-get update" in the image dir |
| `install.upgrade`  |   | run "apt-get upgrade" in the image dir |

#### Merging containers

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `install.container` | **other** | the name of the **other** template to install into this image |

### Clean and finish

| Function  | Arguments  | Description  |
| ------------ | ------------ | ------------ |
| `clean.install` |   |  Default step function for the cleanup step (flush the docs) |
| `finish.default` |   | Default finish step. Install missing libs and the entrypoint script  |

