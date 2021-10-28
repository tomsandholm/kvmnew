##MAKEFLAGS += --silent
SHELL = /bin/bash

.PHONEY:	help

check_defined = \
  $(strip $(foreach 1,$1, \
      $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

help:
	echo ">>> key variables are:"
	echo "     DISTRO:  (xenial|bionic|focal)"
	echo "     SWAPSIZE: (GB)"
	echo "     DATASIZE: (GB)"
	echo "     RAM: (MB)"
	echo "     VCPUS: (COUNT)"
	echo "     NAME:  fqdn (REQUIRED)"
	echo "     NAME:  fqdn (REQUIRED)"
	echo ""
	echo ">>> Targets"
	make targets
	echo ""
	echo ">>> Current nodes ares:"
	make list

list:
	ls $(IMGDIR)
	
targets:
	sed -n 's/^\([a-Z][a-Z]*\):.*/\1/gp' Makefile

## the distro to build
#DISTRO := xenial
#DISTRO := centos-7
#DISTRO := bionic
DISTRO := focal
#DISTRO := centos-8

## set package type
ifeq ($(DISTRO),xenial)
	PTYPE := DEB
endif
ifeq ($(DISTRO),bionic)
	PTYPE := DEB
endif
ifeq ($(DISTRO),centos-7)
	PTYPE := RPM
endif
ifeq ($(DISTRO),centos-8)
	ROOTSIZE := 20
	PTYPE := RPM
endif

## set machine defaults
ifeq ($(ROLE),jenkins)
	RAM := 8G
	VCPUS := 4
endif
	

## graphics
GRAPHICS := none

## derived from NAME, a required env variable
SNAME = $(shell echo $(NAME) | cut -d'.' -f1)

## get the domain part
DNAME = $(shell echo $(NAME) | cut -d'.' -f2-)

## the URL of where to get THIS $DISTRO
URL := $(shell egrep "^$(DISTRO)" ./distro | cut -d';' -f3)

## the IMG name of THIS $DISTRO
SRC := $(shell egrep "^$(DISTRO)" ./distro | cut -d';' -f4)

## stuff
UUID := $(shell uuidgen)

## get ipaddress of supplied NAME->SNAME
IPADDRESS := $(shell getent hosts $(SNAME)|awk '{print $$1}')

## what role to give node, populates /etc/role
ROLE := general

## what env to give node, populates /etc/aenv
ENV := dev

## swapdisk size
## in GB
SWAPSIZE := 2

## datadisk size
## in GB
DATASIZE := 0

## rootdisk size
## in GB
ROOTSIZE := 16

## docroot disk size
## in GB
WEBSIZE := 0

## guest node ram size
RAM := 2048

## guest node cpu coount
VCPUS := 2

## guest node os type
OS-VARIANT := ubuntu16.04

## where the etc directory lives
ETCDIR := /etc/kvmbld

## where we store virtual nodes stuff 
VARDIR := /var/lib/kvmbld

## where we store extra data
DATADIR := /data/virt

## base images directory, used as backing store for qcow2 images
BASEDIR := $(VARDIR)/base

## individual nodes disks
IMGDIR := $(VARDIR)/images

## where are the source images
SRCDIR := $(VARDIR)/sources

## either static or dhcp
NET := static
#NET := dhcp

## command to pass virt-install for swap disk allocation
SWAPDISK := --disk path=$(IMGDIR)/$(SNAME)/swap.qcow2,device=disk,bus=virtio

## command to pass virt-install for document root disk allocation
WEBDISK := --disk path=$(IMGDIR)/$(SNAME)/docroot.qcow2,device=disk,bus=virtio

## command to pass virt-install for data disk allocation
DATADISK := --disk path=$(DATADIR)/$(SNAME)/data.qcow2,device=disk,bus=virtio

## if SWAPSIZE is zero, then do not create SWAPDISK
ifeq ($(SWAPSIZE),0)
	SWAPDISK := 
endif

## if WEBSIZE is zero, then do not create WEBDISK
ifeq ($(WEBSIZE),0)
	WEBDISK :=
endif

## if DATASIZE is zero, then do not create DATADISK
ifeq ($(DATASIZE),0)
	DATADISK :=
endif

## if 

## target to list stuff
stats:
	$(info DISTRO:....$(DISTRO))
	$(info URL:.......$(URL))
	$(info SRC:.......$(SRC))
	$(info NAME:......$(NAME))
	$(info SNAME:.....$(SNAME))
	$(info IPADDRESS:.$(IPADDRESS))
	$(info UUID:......$(UUID))
	$(info ENV:.......$(ENV))
	$(info ROLE:......$(ROLE))
	$(info dirs:......$(dirs))
	$(info PTYPE:.....$(PTYPE))

## destructive!
clean:
	rm -rf $(SRCDIR)
	rm -rf $(BASEDIR)
	rm -rf $(IMGDIR)
	rm -rf *.tmp1
	rm -rf *.tmp2

## just remove a single image
clean-image:
	rm -rf $(IMGDIR)/$(SNAME)

## get our source images
sources:	$(SRCDIR)/$(DISTRO)

$(SRCDIR)/$(DISTRO):
	@:$(call check_defined,NAME)
	mkdir -p $(SRCDIR)/$(DISTRO)
	cd $(SRCDIR)/$(DISTRO) && wget $(URL)
	
## setup the base master qcow2 images
base:	sources $(BASEDIR)/$(DISTRO)

$(BASEDIR)/$(DISTRO):	$(BASEDIR)/$(DISTRO)/rootfs.qcow2

$(BASEDIR)/$(DISTRO)/rootfs.qcow2:
	mkdir -p $(BASEDIR)/$(DISTRO)
	cp -v $(SRCDIR)/$(DISTRO)/$(SRC) $(BASEDIR)/$(DISTRO)/rootfs.qcow2

## create a node image
image:	base $(IMGDIR)/$(SNAME)

$(IMGDIR)/$(SNAME): $(IMGDIR)/$(SNAME)/rootfs.qcow2

$(IMGDIR)/$(SNAME)/rootfs.qcow2:
	mkdir -p $(IMGDIR)/$(SNAME)
ifeq ($(ROOTSIZE),0)
	qemu-img create -f qcow2 -b $(BASEDIR)/$(DISTRO)/rootfs.qcow2 $(IMGDIR)/$(SNAME)/rootfs.qcow2
else
	qemu-img create -f qcow2 -b $(BASEDIR)/$(DISTRO)/rootfs.qcow2 $(IMGDIR)/$(SNAME)/rootfs.qcow2
	qemu-img resize $(IMGDIR)/$(SNAME)/rootfs.qcow2 $(ROOTSIZE)G
endif
	qemu-img info $(IMGDIR)/$(SNAME)/rootfs.qcow2

# configure the user-data PACKAGES base on ROLE setting
role:	$(IMGDIR)/$(SNAME)/user-data

# install packages-$(ROLE)
$(IMGDIR)/$(SNAME)/user-data:
	cp user-data-dir/$(DISTRO)/user-data.tmpl user-data.tmp1
	sed "/PACKAGES/r packages-dir/$(DISTRO)/packages-$(ROLE)" user-data.tmp1 > user-data.tmp2
	cp user-data.tmp2 user-data.tmp1
	sed "/BOOTCMD/r bootcmd-dir/$(DISTRO)/bootcmd-$(ROLE).tmpl" user-data.tmp1 > user-data.tmp2
	cp user-data.tmp2 user-data.tmp1
	sed "/MOUNTS/r mounts-dir/$(DISTRO)/mounts-$(ROLE).tmpl" user-data.tmp1 > user-data.tmp2
	cp user-data.tmp2 user-data.tmp1
	sed "/RUNCMD/r runcmd-dir/$(DISTRO)/runcmd-$(ROLE).tmpl" user-data.tmp1 > user-data.tmp2
	cp user-data.tmp2 user-data.tmp1
	sed "/APT/r apt-dir/$(DISTRO)/apt-$(ROLE).tmpl" user-data.tmp1 > user-data.tmp2
	cp user-data.tmp2 user-data
	rm user-data.tmp1 user-data.tmp2

## pull all the disk stuff together
disks:	rootfs swap data web

## create our node root disk
rootfs:	image 

## create our node swap disk
swap:	$(IMGDIR)/$(SNAME)/swap.qcow2

$(IMGDIR)/$(SNAME)/swap.qcow2:
	mkdir -p $(IMGDIR)/$(SNAME)
	if [ $(SWAPSIZE) -gt 0 ]; then \
		qemu-img create -f qcow2 $(IMGDIR)/$(SNAME)/swap.qcow2 $(SWAPSIZE)G; \
	fi

## create our node data disk
data:	$(DATADIR)/$(SNAME)/data.qcow2

$(DATADIR)/$(SNAME)/data.qcow2:
	mkdir -p $(DATADIR)/$(SNAME)
	if [ $(DATASIZE) -gt 0 ]; then \
		qemu-img create -f qcow2 $(DATADIR)/$(SNAME)/data.qcow2 $(DATASIZE)G; \
	fi

web:	$(IMGDIR)/$(SNAME)/docroot.qcow2

$(IMGDIR)/$(SNAME)/docroot.qcow2:
	mkdir -p $(IMGDIR)/$(SNAME)
	if [ $(WEBSIZE) -gt 0 ]; then \
		qemu-img create -f qcow2 $(IMGDIR)/$(SNAME)/docroot.qcow2 $(WEBSIZE)G; \
	fi


## create our installation cdrom
config.iso:	role disks network-config
	genisoimage -o $(IMGDIR)/$(SNAME)/config.iso -V cidata -r -J $(IMGDIR)/$(SNAME)/meta-data $(IMGDIR)/$(SNAME)/user-data $(IMGDIR)/$(SNAME)/network-config vendor-data

## create keys
rootkeys:
	mkdir -p $(IMGDIR)/$(SNAME)/keys
	cd $(IMGDIR)/$(SNAME)/keys && ssh-keygen -t rsa -N '' -f ./id_rsa
	cd $(IMGDIR)/$(SNAME)/keys && cat id_rsa.pub > ./authorized_keys


## create the network configuration
network-config:	meta-data $(IMGDIR)/$(SNAME)/network-config

$(IMGDIR)/$(SNAME)/network-config:
ifeq ($(NET),static)
ifeq ($(IPADDRESS),)
	$(error NET is static yet IPADDRESS is NULL)
endif
	cp network-config/$(DISTRO)/network-config-static.tmpl $(IMGDIR)/$(SNAME)/network-config
	sed -i "s/<IPADDRESS>/$(IPADDRESS)/g" $(IMGDIR)/$(SNAME)/network-config
endif
ifeq ($(NET),dhcp)
	cp network-config/$(DISTRO)/network-config-dhcp.tmpl $(IMGDIR)/$(SNAME)/network-config
endif

## create the cloud-init meta-data
meta-data:	$(IMGDIR)/$(SNAME)/meta-data

$(IMGDIR)/$(SNAME)/meta-data:
	echo "instance-id: $(UUID)" > $(IMGDIR)/$(SNAME)/meta-data
	echo "role: $(ROLE)" >> $(IMGDIR)/$(SNAME)/meta-data
	echo "aenv: $(ENV)" >> $(IMGDIR)/$(SNAME)/meta-data
	echo "local-hostname: $(NAME)" >> $(IMGDIR)/$(SNAME)/meta-data
	echo "public-keys: " >> $(IMGDIR)/$(SNAME)/meta-data
	echo "- `cat $(HOME)/.ssh/id_rsa.pub`" >> $(IMGDIR)/$(SNAME)/meta-data
ifeq ($(ROLE),mariadb)
	echo "remuser: $(REMUSER)" >> $(IMGDIR)/$(SNAME)/meta-data
	echo "remuserpsw: $(REMUSERPSW)" >> $(IMGDIR)/$(SNAME)/meta-data
	echo "id: $(INST_ID)" >> $(IMGDIR)/$(SNAME)/meta-data
	echo "host: $(SNAME)" >> $(IMGDIR)/$(SNAME)/meta-data
endif 
	cp user-data $(IMGDIR)/$(SNAME)/user-data
	rm user-data

## delete our node
Delete:
	@:$(call check_defined,NAME)
	virsh destroy $(SNAME) || echo "Node stop failed for $(SNAME)"
	virsh undefine $(SNAME) --remove-all-storage
	rm -rf $(IMGDIR)/$(SNAME)
	rm -rf $(DATADIR)/$(SNAME)
	sudo sed -i "/^$(NAME).*/d" /etc/ansible/hosts
	make -e NAME=$(NAME) clean-image

## create a jenkins cluster
jenkinscluster:	FORCE
	make -e NAME=jenkins.tsand.org ROLE=jenkins node
	virsh shutdown jenkins
	sleep 15
	#cd /var/lib/kvmbld/images/jenkins && ssh-keygen -t rsa -N '' -f id_rsa
	#virt-copy-in -a /var/lib/kvmbld/images/jenkins/rootfs.qcow2 /var/lib/kvmbld/images/jenkins/id_rsa /root/.ssh/
	virt-copy-in -a /var/lib/kvmbld/images/jenkins/rootfs.qcow2 /root/.ssh/id_rsa /root/.ssh/
	virt-copy-in -a /var/lib/kvmbld/images/jenkins/rootfs.qcow2 /root/.ssh/id_rsa /var/lib/jenkins/.ssh/
	#virt-copy-in -a /var/lib/kvmbld/images/jenkins/rootfs.qcow2 /var/lib/kvmbld/images/jenkins/id_rsa.pub /root/.ssh/
	virt-copy-in -a /var/lib/kvmbld/images/jenkins/rootfs.qcow2 /root/.ssh/id_rsa.pub /root/.ssh/
	virt-copy-in -a /var/lib/kvmbld/images/jenkins/rootfs.qcow2 /root/.ssh/id_rsa.pub /var/lib/jenkins/.ssh/
	virsh start jenkins
	cp /var/lib/kvmbld/images/jenkins/id_rsa.pub /var/lib/kvmbld/images/jenkins/authorized_keys
	make -e NAME=jenkins01.tsand.org ROLE=jenkinsslave node
	virsh shutdown jenkins01
	sleep 15
	#virt-copy-in -a /var/lib/kvmbld/images/jenkins01/rootfs.qcow2 /var/lib/kvmbld/images/jenkins/authorized_keys /root/.ssh
	virt-copy-in -a /var/lib/kvmbld/images/jenkins01/rootfs.qcow2 /root/.ssh/authorized_keys /root/.ssh
	virt-copy-in -a /var/lib/kvmbld/images/jenkins01/rootfs.qcow2 /root/.ssh/authorized_keys /var/lib/jenkins/.ssh/
	virsh start jenkins01	
	make -e NAME=jenkins02.tsand.org ROLE=jenkinsslave node
	virsh shutdown jenkins02
	sleep 15
	#virt-copy-in -a /var/lib/kvmbld/images/jenkins02/rootfs.qcow2 /var/lib/kvmbld/images/jenkins/authorized_keys /root/.ssh
	virt-copy-in -a /var/lib/kvmbld/images/jenkins02/rootfs.qcow2 /root/.ssh/authorized_keys /root/.ssh
	virt-copy-in -a /var/lib/kvmbld/images/jenkins02/rootfs.qcow2 /root/.ssh/authorized_keys /var/lib/jenkins/.ssh/
	virsh start jenkins02
	exit 0

FORCE:
	
## create a kubernetes cluster
k8: k8nodes
CNT := $(COUNT)
k8nodes:
	@:$(call check_defined,PREFIX)
	@:$(call check_defined,COUNT)
	@:$(call check_defined,DOM)
	@echo "create a kubernetes cluster of prefix $$PREFIX with count $$COUNT and $$CNT"
	> /tmp/$(PREFIX).list
	while [ $$COUNT -gt 0 ] ; do \
		cmd="`printf $(PREFIX)'%02d\n' $$COUNT`"; \
		(( COUNT-- )); \
		echo ">>>>> make -e NAME=$$cmd.$(DOM) SWAPSIZE=0 ROLE=k8 node"; \
		make -e NAME=$$cmd.$(DOM) SWAPSIZE=0 ROLE=k8 node; \
		echo "$$cmd.$(DOM)" >> /tmp/$(PREFIX).list; \
	done; \
	master=`head -1 /tmp/$(PREFIX).list` ; \
	echo ">>>>> ssh $$master" ; \

	exit 0

k8del:
	@:$(call check_defined,PREFIX)
	@:$(call check_defined,COUNT)
	@:$(call check_defined,DOM)

	while [ $$COUNT -gt 0 ] ; do \
		cmd="`printf $(PREFIX)'%02d\n' $$COUNT`"; \
		(( COUNT-- )); \
		echo ">>>>> make -e NAME=$$cmd.$(DOM) ROLE=k8 Delete"; \
		make -e NAME=$$cmd.$(DOM) ROLE=k8 Delete; \
	done;
	exit 0


## create a gluster cluster
gluster: glusternodes
CNT := $(COUNT)
glusternodes:
	@:$(call check_defined,PREFIX)
	@:$(call check_defined,COUNT)
	@:$(call check_defined,DATASIZE)
	@:$(call check_defined,DOM)
	@echo "create a gluster cluster of prefix $$PREFIX with count $$COUNT and $$CNT"
	> /tmp/$(PREFIX).list
	while [ $$COUNT -gt 0 ] ; do \
		cmd="`printf $(PREFIX)'%02d\n' $$COUNT`"; \
		(( COUNT-- )); \
		echo ">>>>> make -e NAME=$$cmd.$(DOM) ROLE=gluster DATASIZE=$(DATASIZE) node"; \
		make -e NAME=$$cmd.$(DOM) ROLE=gluster DATASIZE=$(DATASIZE) node; \
		echo "$$cmd.$(DOM)" >> /tmp/$(PREFIX).list; \
	done; \
	master=`head -1 /tmp/$(PREFIX).list` ; \
	echo ">>>>> ssh $$master" ; \
	for x in `cat /tmp/$(PREFIX).list` ; do \
		sleep 10 ; \
		if [ "$$x" != "$$master" ] ; then \
			echo ">>>>> gluster peer probe $$x" ; \
			ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" $$master gluster peer probe $$x ; \
		fi ; \
	done ; \
	nodelist=`sed 's/\(.*\)/\1:\/data\/gl00\/gv0/g' /tmp/gl.list` ; \
	echo ">>>>> nodelist is: $$nodelist" ; \
        cnt=`wc -l /tmp/gl.list | cut -d' ' -f1` ; \
	echo ">>>>> nodecount is: $$cnt" ; \
	ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" $$master gluster volume create mirror1 replica $$cnt transport tcp $$nodelist ; \
	ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" $$master gluster volume start mirror1 ; \
	ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" $$master gluster volume info mirror1 ; \

	exit 0

glusterdel:
	@:$(call check_defined,PREFIX)
	@:$(call check_defined,COUNT)
	@:$(call check_defined,DATASIZE)
	@:$(call check_defined,DOM)

	while [ $$COUNT -gt 0 ] ; do \
		cmd="`printf $(PREFIX)'%02d\n' $$COUNT`"; \
		(( COUNT-- )); \
		echo ">>>>> make -e NAME=$$cmd.$(DOM) ROLE=gluster Delete"; \
		make -e NAME=$$cmd.$(DOM) ROLE=gluster Delete; \
	done;
	exit 0

## create a node using virt-install
node:	rootkeys config.iso
	@:$(call check_defined,NAME)

	virt-install --connect=qemu:///system --name $(SNAME) --ram $(RAM) --vcpus=$(VCPUS) --os-type=linux --os-variant=ubuntu16.04 --disk path=$(IMGDIR)/$(SNAME)/rootfs.qcow2,device=disk,bus=virtio $(SWAPDISK) $(DATADISK) $(DBDISK) $(DBLOGDISK) $(WEBDISK) --disk path=$(IMGDIR)/$(SNAME)/config.iso,device=cdrom --graphics $(GRAPHICS) --import --wait=-1
	sudo echo "$(NAME) ansible_python_interpreter=\"/usr/bin/python3\"" >> /etc/ansible/hosts
	virsh start $(SNAME)

galera:
ifeq ($(GC),0)
	$(error called galera with zero GC)
endif
ifeq ($(GCPREFIX),)
	$(error called galera with no GCPREFIX)
endif
	current=1; while [[ $$current -le $(GC) ]] ; do \
	NAME=$(GCPREFIX)`printf "%03d\n"  $$current` ; \
	echo $$NAME ; \
	make -e NAME=$$NAME ROLE=mariadb node ; \
	((current = current + 1)) ; \
	done

coro:
	@:$(call check_defined,NAME)
	make -e NAME=$$NAME ROLE=coro node

