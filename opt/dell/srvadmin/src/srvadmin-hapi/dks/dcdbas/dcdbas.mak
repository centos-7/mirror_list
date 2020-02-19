######################################################################
# Begin Makefile
######################################################################

MOD_NAME := dcdbas
MOD_BINNAME_O := $(MOD_NAME).o
MOD_OBJS_VARNAME := $(MOD_NAME)-objs

MOD_OBJS := \
	dcdbas.o

EXTRA_CFLAGS += -I $(SUBDIRS)

ifeq ($(KERNEL_IS_GT_2_4), 0)

M_OBJS := $(MOD_OBJS)

dkslink:

else

obj-m := $(MOD_BINNAME_O)

dkslink:

endif

sinclude $(TOPDIR)/Rules.make

######################################################################
# End Makefile
######################################################################

