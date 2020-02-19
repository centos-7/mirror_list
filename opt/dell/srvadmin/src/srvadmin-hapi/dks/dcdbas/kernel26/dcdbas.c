/*
 *  dcdbas.c: Dell Systems Management Base Driver
 *
 *  The Dell Systems Management Base Driver provides a sysfs interface for
 *  systems management software to perform System Management Interrupts (SMIs)
 *  and Host Control Actions (power cycle or power off after OS shutdown) on
 *  Dell systems.
 *
 *  See Documentation/dcdbas.txt for more information.
 *
 *  Copyright (C) 1995-2006 Dell Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License v2.0 as published by
 *  the Free Software Foundation.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 */

#include <linux/device.h>
#include <linux/errno.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/mc146818rtc.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/reboot.h>
#include <linux/sched.h>
#include <linux/smp.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <linux/types.h>
#include <linux/version.h>
#include <asm/io.h>
#include <asm/scatterlist.h>
#include <asm/semaphore.h>
#include <linux/dma-mapping.h>
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,15)
#include <linux/platform_device.h>
#endif

#include "dcdbas.h"

#define DRIVER_NAME		"dcdbas"
#define DRIVER_VERSION		"5.6.0-2.2"
#define DRIVER_DESCRIPTION	"Dell Systems Management Base Driver"

static struct platform_device *dcdbas_pdev;

static u8 *smi_data_buf;
static dma_addr_t smi_data_buf_handle;
static unsigned long smi_data_buf_size;
static u32 smi_data_buf_phys_addr;
static DECLARE_MUTEX(smi_data_lock);

static unsigned int host_control_action;
static unsigned int host_control_smi_type;
static unsigned int host_control_on_shutdown;

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,9)
/**
 * dcdbas_alloc_32bit - allocate 32-bit addressable memory
 */
static void *dcdbas_alloc_32bit(size_t size, dma_addr_t *handle,
				unsigned int flags)
{
	void *mem;
	u64 mask = 0xffffffff;
	unsigned int order = get_order(size);

	while ((mem = (void *)__get_free_pages(flags, order)) != NULL) {
		if (((u64)virt_to_phys(mem) & ~mask) == 0) {
			memset(mem, 0, size);
			*handle = virt_to_phys(mem);
			break;
		}
		free_pages((unsigned long)mem, order);
		mem = NULL;
		if (flags & GFP_DMA)
			break;
		flags |= GFP_DMA;
	}
	return mem;
}

/**
 * dcdbas_free_32bit - free 32-bit addressable memory
 */
static void dcdbas_free_32bit(void *mem, size_t size)
{
	free_pages((unsigned long)mem, get_order(size));
}
#endif

/**
 * smi_data_buf_free: free SMI data buffer
 */
static void smi_data_buf_free(void)
{
	if (!smi_data_buf)
		return;

	pr_debug("%s: phys: %x size: %lu\n",
		 __FUNCTION__, smi_data_buf_phys_addr, smi_data_buf_size);

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,9)
	dma_free_coherent(&dcdbas_pdev->dev, smi_data_buf_size, smi_data_buf,
			  smi_data_buf_handle);
#else
	dcdbas_free_32bit(smi_data_buf, smi_data_buf_size);
#endif
	smi_data_buf = NULL;
	smi_data_buf_handle = 0;
	smi_data_buf_phys_addr = 0;
	smi_data_buf_size = 0;
}

/**
 * smi_data_buf_realloc: grow SMI data buffer if needed
 * 
 * BIOS SMI calls require physical buffer addresses be in 32-bit address space
 */
static int smi_data_buf_realloc(unsigned long size)
{
	void *buf;
	dma_addr_t handle;

	if (smi_data_buf_size >= size)
		return 0;

	if (size > MAX_SMI_DATA_BUF_SIZE)
		return -EINVAL;

	/* new buffer is needed */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,9)
	buf = dma_alloc_coherent(&dcdbas_pdev->dev, size, &handle, GFP_KERNEL);
#else
	buf = dcdbas_alloc_32bit(size, &handle, GFP_KERNEL);
#endif
	if (!buf) {
		pr_debug("%s: failed to allocate memory size %lu\n",
			 __FUNCTION__, size);
		return -ENOMEM;
	}
	/* memory zeroed by dma_alloc_coherent */

	if (smi_data_buf)
		memcpy(buf, smi_data_buf, smi_data_buf_size);

	/* free any existing buffer */
	smi_data_buf_free();

	/* set up new buffer for use */
	smi_data_buf = buf;
	smi_data_buf_handle = handle;
	smi_data_buf_phys_addr = (u32) virt_to_phys(buf);
	smi_data_buf_size = size;

	pr_debug("%s: phys: %x size: %lu\n",
		 __FUNCTION__, smi_data_buf_phys_addr, smi_data_buf_size);

	return 0;
}

static ssize_t smi_data_buf_phys_addr_show(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
					   struct device_attribute *attr,
#endif
					   char *buf)
{
	return sprintf(buf, "%x\n", smi_data_buf_phys_addr);
}

static ssize_t smi_data_buf_size_show(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
				      struct device_attribute *attr,
#endif
				      char *buf)
{
	return sprintf(buf, "%lu\n", smi_data_buf_size);
}

static ssize_t smi_data_buf_size_store(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
				       struct device_attribute *attr,
#endif
				       const char *buf, size_t count)
{
	unsigned long buf_size;
	ssize_t ret;

	buf_size = simple_strtoul(buf, NULL, 10);

	/* make sure SMI data buffer is at least buf_size */
	down(&smi_data_lock);
	ret = smi_data_buf_realloc(buf_size);
	up(&smi_data_lock);
	if (ret)
		return ret;

	return count;
}

static ssize_t smi_data_read(struct kobject *kobj, char *buf, loff_t pos,
			     size_t count)
{
	size_t max_read;
	ssize_t ret;

	down(&smi_data_lock);

	if (pos >= smi_data_buf_size) {
		ret = 0;
		goto out;
	}

	max_read = smi_data_buf_size - pos;
	ret = min(max_read, count);
	memcpy(buf, smi_data_buf + pos, ret);
out:
	up(&smi_data_lock);
	return ret;
}

static ssize_t smi_data_write(struct kobject *kobj, char *buf, loff_t pos,
			      size_t count)
{
	ssize_t ret;

	if ((pos + count) > MAX_SMI_DATA_BUF_SIZE)
		return -EINVAL;

	down(&smi_data_lock);

	ret = smi_data_buf_realloc(pos + count);
	if (ret)
		goto out;

	memcpy(smi_data_buf + pos, buf, count);
	ret = count;
out:
	up(&smi_data_lock);
	return ret;
}

static ssize_t host_control_action_show(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
					struct device_attribute *attr,
#endif
					char *buf)
{
	return sprintf(buf, "%u\n", host_control_action);
}

static ssize_t host_control_action_store(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
					 struct device_attribute *attr,
#endif
					 const char *buf, size_t count)
{
	ssize_t ret;

	/* make sure buffer is available for host control command */
	down(&smi_data_lock);
	ret = smi_data_buf_realloc(sizeof(struct apm_cmd));
	up(&smi_data_lock);
	if (ret)
		return ret;

	host_control_action = simple_strtoul(buf, NULL, 10);
	return count;
}

static ssize_t host_control_smi_type_show(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
					  struct device_attribute *attr,
#endif
					  char *buf)
{
	return sprintf(buf, "%u\n", host_control_smi_type);
}

static ssize_t host_control_smi_type_store(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
					   struct device_attribute *attr,
#endif
					   const char *buf, size_t count)
{
	host_control_smi_type = simple_strtoul(buf, NULL, 10);
	return count;
}

static ssize_t host_control_on_shutdown_show(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
					     struct device_attribute *attr,
#endif
					     char *buf)
{
	return sprintf(buf, "%u\n", host_control_on_shutdown);
}

static ssize_t host_control_on_shutdown_store(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
					      struct device_attribute *attr,
#endif
					      const char *buf, size_t count)
{
	host_control_on_shutdown = simple_strtoul(buf, NULL, 10);
	return count;
}

/**
 * smi_request: generate SMI request
 * 
 * Called with smi_data_lock.
 */
static int smi_request(struct smi_cmd *smi_cmd)
{
	cpumask_t old_mask;
	int ret = 0;

	if (smi_cmd->magic != SMI_CMD_MAGIC) {
		printk(KERN_INFO "%s: %s: invalid magic value\n",
		       DRIVER_NAME, __FUNCTION__);
		return -EBADR;
	}

	/* SMI requires CPU 0 */
	old_mask = current->cpus_allowed;
	set_cpus_allowed(current, cpumask_of_cpu(0));
	if (smp_processor_id() != 0) {
		pr_debug("%s: failed to get CPU 0\n",
			 __FUNCTION__);
		ret = -EBUSY;
		goto out;
	}

	/* generate SMI */
	asm volatile (
		"outb %b0,%w1"
		: /* no output args */
		: "a" (smi_cmd->command_code), 
		  "d" (smi_cmd->command_address), 
		  "b" (smi_cmd->ebx), 
		  "c" (smi_cmd->ecx)  
		: "memory"
	);

out:
	set_cpus_allowed(current, old_mask);
	return ret;
}

/**
 * smi_request_store:
 * 
 * The valid values are:
 * 0: zero SMI data buffer
 * 1: generate calling interface SMI
 * 2: generate raw SMI
 * 
 * User application writes smi_cmd to smi_data before telling driver
 * to generate SMI.
 */
static ssize_t smi_request_store(struct device *dev,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,13)
				 struct device_attribute *attr,
#endif
				 const char *buf, size_t count)
{
	struct smi_cmd *smi_cmd;
	unsigned long val = simple_strtoul(buf, NULL, 10);
	ssize_t ret;

	down(&smi_data_lock);

	if (smi_data_buf_size < sizeof(struct smi_cmd)) {
		ret = -ENODEV;
		goto out;
	}
	smi_cmd = (struct smi_cmd *)smi_data_buf;

	switch (val) {
	case 2:
		/* Raw SMI */
		ret = smi_request(smi_cmd);
		if (!ret)
			ret = count;
		break;
	case 1:
		/* Calling Interface SMI */
		smi_cmd->ebx = (u32) virt_to_phys(smi_cmd->command_buffer);
		ret = smi_request(smi_cmd);
		if (!ret)
			ret = count;
		break;
	case 0:
		memset(smi_data_buf, 0, smi_data_buf_size);
		ret = count;
		break;
	default:
		ret = -EINVAL;
		break;
	}

out:
	up(&smi_data_lock);
	return ret;
}

/**
 * host_control_smi: generate host control SMI
 *
 * Caller must set up the host control command in smi_data_buf.
 */
static int host_control_smi(void)
{
	struct apm_cmd *apm_cmd;
	u8 *data;
	unsigned long flags;
	u32 num_ticks;
	s8 cmd_status;
	u8 index;

	apm_cmd = (struct apm_cmd *)smi_data_buf;
	apm_cmd->status = ESM_STATUS_CMD_UNSUCCESSFUL;

	switch (host_control_smi_type) {
	case HC_SMITYPE_TYPE1:
		spin_lock_irqsave(&rtc_lock, flags);
		/* write SMI data buffer physical address */
		data = (u8 *)&smi_data_buf_phys_addr;
		for (index = PE1300_CMOS_CMD_STRUCT_PTR;
		     index < (PE1300_CMOS_CMD_STRUCT_PTR + 4);
		     index++, data++) {
			outb(index,
			     (CMOS_BASE_PORT + CMOS_PAGE2_INDEX_PORT_PIIX4));
			outb(*data,
			     (CMOS_BASE_PORT + CMOS_PAGE2_DATA_PORT_PIIX4));
		}

		/* first set status to -1 as called by spec */
		cmd_status = ESM_STATUS_CMD_UNSUCCESSFUL;
		outb((u8) cmd_status, PCAT_APM_STATUS_PORT);

		/* generate SMM call */
		outb(ESM_APM_CMD, PCAT_APM_CONTROL_PORT);
		spin_unlock_irqrestore(&rtc_lock, flags);

		/* wait a few to see if it executed */
		num_ticks = TIMEOUT_USEC_SHORT_SEMA_BLOCKING;
		while ((cmd_status = inb(PCAT_APM_STATUS_PORT))
		       == ESM_STATUS_CMD_UNSUCCESSFUL) {
			num_ticks--;
			if (num_ticks == EXPIRED_TIMER)
				return -ETIME;
		}
		break;

	case HC_SMITYPE_TYPE2:
	case HC_SMITYPE_TYPE3:
		spin_lock_irqsave(&rtc_lock, flags);
		/* write SMI data buffer physical address */
		data = (u8 *)&smi_data_buf_phys_addr;
		for (index = PE1400_CMOS_CMD_STRUCT_PTR;
		     index < (PE1400_CMOS_CMD_STRUCT_PTR + 4);
		     index++, data++) {
			outb(index, (CMOS_BASE_PORT + CMOS_PAGE1_INDEX_PORT));
			outb(*data, (CMOS_BASE_PORT + CMOS_PAGE1_DATA_PORT));
		}

		/* generate SMM call */
		if (host_control_smi_type == HC_SMITYPE_TYPE3)
			outb(ESM_APM_CMD, PCAT_APM_CONTROL_PORT);
		else
			outb(ESM_APM_CMD, PE1400_APM_CONTROL_PORT);

		/* restore RTC index pointer since it was written to above */
		CMOS_READ(RTC_REG_C);
		spin_unlock_irqrestore(&rtc_lock, flags);

		/* read control port back to serialize write */
		cmd_status = inb(PE1400_APM_CONTROL_PORT);

		/* wait a few to see if it executed */
		num_ticks = TIMEOUT_USEC_SHORT_SEMA_BLOCKING;
		while (apm_cmd->status == ESM_STATUS_CMD_UNSUCCESSFUL) {
			num_ticks--;
			if (num_ticks == EXPIRED_TIMER)
				return -ETIME;
		}
		break;

	default:
		pr_debug("%s: invalid SMI type %u\n",
			 __FUNCTION__, host_control_smi_type);
		return -ENOSYS;
	}

	return 0;
}

/**
 * dcdbas_host_control: initiate host control
 * 
 * This function is called by the driver after the system has
 * finished shutting down if the user application specified a
 * host control action to perform on shutdown.  It is safe to
 * use smi_data_buf at this point because the system has finished
 * shutting down and no userspace apps are running.
 */
static void dcdbas_host_control(void)
{
	struct apm_cmd *apm_cmd;
	u8 action;

	if (host_control_action == HC_ACTION_NONE)
		return;

	action = host_control_action;
	host_control_action = HC_ACTION_NONE;

	if (!smi_data_buf) {
		pr_debug("%s: no SMI buffer\n", __FUNCTION__);
		return;
	}

	if (smi_data_buf_size < sizeof(struct apm_cmd)) {
		pr_debug("%s: SMI buffer too small\n",
			 __FUNCTION__);
		return;
	}

	apm_cmd = (struct apm_cmd *)smi_data_buf;

	/* power off takes precedence */
	if (action & HC_ACTION_HOST_CONTROL_POWEROFF) {
		apm_cmd->command = ESM_APM_POWER_CYCLE;
		apm_cmd->reserved = 0;
		*((s16 *)&apm_cmd->parameters.shortreq.parm[0]) = (s16) 0;
		host_control_smi();
	} else if (action & HC_ACTION_HOST_CONTROL_POWERCYCLE) {
		apm_cmd->command = ESM_APM_POWER_CYCLE;
		apm_cmd->reserved = 0;
		*((s16 *)&apm_cmd->parameters.shortreq.parm[0]) = (s16) 20;
		host_control_smi();
	}
}

/**
 * dcdbas_reboot_notify: handle reboot notification for host control
 */
static int dcdbas_reboot_notify(struct notifier_block *nb, unsigned long code,
				void *unused)
{
	static unsigned int notify_cnt = 0;

	switch (code) {
	case SYS_DOWN:
	case SYS_HALT:
	case SYS_POWER_OFF:
		if (host_control_on_shutdown) {
			/* firmware is going to perform host control action */
			if (++notify_cnt == 2) {
				printk(KERN_WARNING
				       "Please wait for shutdown "
				       "action to complete...\n");
				dcdbas_host_control();
			}
			/*
			 * register again and initiate the host control
			 * action on the second notification to allow
			 * everyone that registered to be notified
			 */
			register_reboot_notifier(nb);
		}
		break;
	}

	return NOTIFY_DONE;
}

static struct notifier_block dcdbas_reboot_nb = {
	.notifier_call = dcdbas_reboot_notify,
	.next = NULL,
	.priority = 0
};

static DCDBAS_BIN_ATTR_RW(smi_data);

static struct bin_attribute *dcdbas_bin_attrs[] = {
	&bin_attr_smi_data,
	NULL
};

static DCDBAS_DEV_ATTR_RW(smi_data_buf_size);
static DCDBAS_DEV_ATTR_RO(smi_data_buf_phys_addr);
static DCDBAS_DEV_ATTR_WO(smi_request);
static DCDBAS_DEV_ATTR_RW(host_control_action);
static DCDBAS_DEV_ATTR_RW(host_control_smi_type);
static DCDBAS_DEV_ATTR_RW(host_control_on_shutdown);

static struct device_attribute *dcdbas_dev_attrs[] = {
	&dev_attr_smi_data_buf_size,
	&dev_attr_smi_data_buf_phys_addr,
	&dev_attr_smi_request,
	&dev_attr_host_control_action,
	&dev_attr_host_control_smi_type,
	&dev_attr_host_control_on_shutdown,
	NULL
};

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,9)
static void dcdbas_platform_device_release(struct device *dev)
{
	struct platform_device *pdev = to_platform_device(dev);

	kfree(pdev);
}
#endif

static int dcdbas_platform_device_register(void)
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,9)
	dcdbas_pdev = platform_device_register_simple(DRIVER_NAME, -1, NULL, 0);
	if (IS_ERR(dcdbas_pdev))
		return PTR_ERR(dcdbas_pdev);

	return 0;
#else
	int retval;

	dcdbas_pdev = kmalloc(sizeof(struct platform_device), GFP_KERNEL);
	if (!dcdbas_pdev) {
		retval = -ENOMEM;
		goto error1;
	}

	memset(dcdbas_pdev, 0, sizeof(struct platform_device));
	dcdbas_pdev->name = DRIVER_NAME;
	dcdbas_pdev->id = -1;
	dcdbas_pdev->dev.parent = &platform_bus;
	dcdbas_pdev->dev.bus = &platform_bus_type;
	dcdbas_pdev->dev.release = dcdbas_platform_device_release;
	strlcpy(dcdbas_pdev->dev.bus_id, DRIVER_NAME, BUS_ID_SIZE);

	retval = device_register(&dcdbas_pdev->dev);
	if (retval)
		goto error2;

	return 0;

error2:
	kfree(dcdbas_pdev);
error1:
	return retval;
#endif
}

void dcdbas_platform_device_unregister(void)
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,9)
	platform_device_unregister(dcdbas_pdev);
#else
	device_unregister(&dcdbas_pdev->dev);
#endif
}

/**
 * dcdbas_init: initialize driver
 */
static int __init dcdbas_init(void)
{
	int retval;
	int i;

	host_control_action = HC_ACTION_NONE;
	host_control_smi_type = HC_SMITYPE_NONE;

	retval = dcdbas_platform_device_register();
	if (retval)
		return retval;

	/*
	 * BIOS SMI calls require buffer addresses be in 32-bit address space.
	 * This is done by setting the DMA mask below.
	 */
	dcdbas_pdev->dev.coherent_dma_mask = DMA_32BIT_MASK;
	dcdbas_pdev->dev.dma_mask = &dcdbas_pdev->dev.coherent_dma_mask;

	register_reboot_notifier(&dcdbas_reboot_nb);

	for (i = 0; dcdbas_bin_attrs[i]; i++)
		sysfs_create_bin_file(&dcdbas_pdev->dev.kobj,
				      dcdbas_bin_attrs[i]);

	for (i = 0; dcdbas_dev_attrs[i]; i++)
		device_create_file(&dcdbas_pdev->dev, dcdbas_dev_attrs[i]);

	printk(KERN_INFO "%s: %s (version %s)\n",
	       DRIVER_NAME, DRIVER_DESCRIPTION, DRIVER_VERSION);

	return 0;
}

/**
 * dcdbas_exit: perform driver cleanup
 */
static void __exit dcdbas_exit(void)
{
	/*
	 * make sure functions that use dcdbas_pdev are called
	 * before dcdbas_platform_device_unregister
	 */
	unregister_reboot_notifier(&dcdbas_reboot_nb);
	smi_data_buf_free();
	dcdbas_platform_device_unregister();
}

module_init(dcdbas_init);
module_exit(dcdbas_exit);

MODULE_DESCRIPTION(DRIVER_DESCRIPTION " (version " DRIVER_VERSION ")");
MODULE_VERSION(DRIVER_VERSION);
MODULE_AUTHOR("Dell Inc.");
MODULE_LICENSE("GPL");

