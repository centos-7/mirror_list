# Use the same directory (esm) for all drivers
LOCALSUBDIRS=esm
KERNEL_SUB_DIRS= $(shell echo $(TARGET_KERNEL))

kernel_i686=       $(shell grep "define __MODULE_KERNEL_i686" /boot/kernel.h | awk '{print $$3}')
kernel_ia32e=      $(shell grep "define __MODULE_KERNEL_ia32e" /boot/kernel.h | awk '{print $$3}')
kernel_ia64=       $(shell grep "define __MODULE_KERNEL_ia64" /boot/kernel.h | awk '{print $$3}')
kernel_x86_64=     $(shell grep "define __MODULE_KERNEL_x86_64" /boot/kernel.h | awk '{print $$3}')

kernel_bigmem=     $(shell grep "define __BOOT_KERNEL_BIGMEM" /boot/kernel.h | awk '{print $$3}')
kernel_boot=       $(shell grep "define __BOOT_KERNEL_BOOT" /boot/kernel.h | awk '{print $$3}')
kernel_enterprise= $(shell grep "define __BOOT_KERNEL_ENTERPRISE" /boot/kernel.h | awk '{print $$3}')
kernel_hugemem=    $(shell grep "define __BOOT_KERNEL_HUGEMEM" /boot/kernel.h | awk '{print $$3}')
kernel_smp=        $(shell grep "define __BOOT_KERNEL_SMP" /boot/kernel.h | awk '{print $$3}')
kernel_up=         $(shell grep "define __BOOT_KERNEL_UP" /boot/kernel.h | awk '{print $$3}')

# Older kernels don't have the flag __MODULE_KERNEL_i686 set,
# so set the default here in order to support these older kernels.
config_file= $${KDIR}/kernel-$${KVER}-i686.config

ifeq ("$(kernel_smp)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i686-smp.config
endif
ifeq ("$(kernel_up)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i686.config
endif

ifeq ("$(kernel_i686)", "1")
ifeq ("$(kernel_bigmem)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i686-bigmem.config
endif
ifeq ("$(kernel_boot)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i386-BOOT.config
endif
ifeq ("$(kernel_enterprise)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i686-enterprise.config
endif
ifeq ("$(kernel_hugemem)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i686-hugemem.config
endif
ifeq ("$(kernel_smp)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i686-smp.config
endif
ifeq ("$(kernel_up)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-i686.config
endif
endif

ifeq ("$(kernel_ia32e)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-ia32e.config
endif

ifeq ("$(kernel_ia64)", "1")
ifeq ("$(kernel_boot)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-ia64-BOOT.config
endif
ifeq ("$(kernel_smp)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-ia64-smp.config
endif
ifeq ("$(kernel_up)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-ia64.config
endif
endif

ifeq ("$(kernel_x86_64)", "1")
ifeq ("$(kernel_boot)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-x86_64-BOOT.config
endif
ifeq ("$(kernel_smp)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-x86_64-smp.config
endif
ifeq ("$(kernel_up)", "1")
	config_file= $${KDIR}/kernel-$${KVER}-x86_64.config
endif
endif

all: $(patsubst %, _mod_%, $(KERNEL_SUB_DIRS)) 


$(patsubst %, _mod_%, $(KERNEL_SUB_DIRS)):
ifeq ("$(kernel_ia64)", "1")

		KDIR=`echo $(patsubst _mod_%, %, $@)`; \
		KVER=`echo $(patsubst _mod_%, %, $@) | cut -f 1 -d '-' -`; \
		BVER=`echo $(patsubst _mod_%, %, $@) | cut -f 2 -d '-' -`; \
		mkdir -p $${KDIR}/modules; \
		ln -sf ../$${KVER}-generic/Makefile $${KDIR}/Makefile; \
		ln -sf ../$${KVER}-generic/Rules.make $${KDIR}/Rules.make; \
		ln -sf ../$${KVER}-generic/arch $${KDIR}/arch; \
		ln -sf ../$${KVER}-generic/scripts $${KDIR}/scripts; \
		for i in ${LOCALSUBDIRS}; do \
			ln -s ../$$i $${KDIR}/$$i ; \
		done; \
		if [ ! -e $${KDIR}/.config ]; then  \
			cp $(config_file) $${KDIR}/.config; \
		fi; \
		make -C $${KDIR} SUBDIRS="${LOCALSUBDIRS}" COMPILE_VERSION="-DSYSTEM_TYPE_LINUX" EXTRAVERSION=-$${BVER} INSTALL_MOD_PATH=`pwd`/$${KDIR} modules; \
		make -C $${KDIR} SUBDIRS="${LOCALSUBDIRS}" COMPILE_VERSION="-DSYSTEM_TYPE_LINUX" EXTRAVERSION=-$${BVER} INSTALL_MOD_PATH=`pwd`/$${KDIR} modules_install; \
		for i in ${LOCALSUBDIRS}; do \
			rm $${KDIR}/$$i ; \
		done; \
		rm $${KDIR}/modules/*; \
		rmdir $${KDIR}/modules; \
	
else

		KDIR=`echo $(patsubst _mod_%, %, $@)`; \
		KVER=`echo $(patsubst _mod_%, %, $@) | cut -f 1 -d '-' -`; \
		BVER=`echo $(patsubst _mod_%, %, $@) | cut -f 2 -d '-' -`; \
		mkdir -p $${KDIR}/modules; \
		ln -sf ../$${KVER}-generic/Makefile $${KDIR}/Makefile; \
		ln -sf ../$${KVER}-generic/Rules.make $${KDIR}/Rules.make; \
		ln -sf ../$${KVER}-generic/arch $${KDIR}/arch; \
		ln -sf ../$${KVER}-generic/scripts $${KDIR}/scripts; \
		for i in ${LOCALSUBDIRS}; do \
			ln -s ../$$i $${KDIR}/$$i ; \
		done; \
		if [ ! -e $${KDIR}/.config ]; then  \
			cp $(config_file) $${KDIR}/.config; \
		fi; \
		make -C $${KDIR} SUBDIRS="${LOCALSUBDIRS}" COMPILE_VERSION="-DSYSTEM_TYPE_LINUX" EXTRAVERSION=-$${BVER} INSTALL_MOD_PATH=`pwd`/$${KDIR} modules; \
		make -C $${KDIR} SUBDIRS="${LOCALSUBDIRS}" COMPILE_VERSION="-DSYSTEM_TYPE_LINUX" EXTRAVERSION=-$${BVER} INSTALL_MOD_PATH=`pwd`/$${KDIR} modules_install; \
		for i in ${LOCALSUBDIRS}; do \
			rm $${KDIR}/$$i ; \
		done; \
		rm $${KDIR}/modules/*; \
		rmdir $${KDIR}/modules; \

endif

