# Paging specification

## Introduction

This specificiation is to show how PowerNex should handle its paging.

This includes everything from after getting control from the bootloader.

## Bootup

When we have gotten control from grub we setup a temporary page table.
This page table is used to be able to setup long mode and to make the kernel run in the higher half of memory.

### Early page table structure

This structure is only go get the kernel booted.
The LOW part is only for when the processor is still in protected mode.
The HIGH part is switched to directly after the CPU has been switched into long mode.

    Kernel code LOW : 0x0000             - 0x400000           is mapped to 0x0000 - 0x400000
    Kernel code HIGH: 0xFFFFFFFF80000000 - 0xFFFFFFFF80400000 is mapped to 0x0000 - 0x400000

## Paging classes requirements

Now when the CPU is in long mode and is running the D code, we want to setup our final kernel paging.
This will require a FrameAllocator. Its job is to allocate 4KiB blocks of memory to be mainly used in the paging tables and malloc.
It will also support freeing blocks of memory.

The FrameAllocator contains a dynamic array. The size depends on the amount of ram the computer has.
It gets this memory from the RawAllocator.
The RawAllocator just return a pointer from the end of the kernel.

### Things to remember

The memory that the RawAllocator returns needs to be mapped in the Early page table.
This can be done statically, that we specify that the RawAllocator can only return X amount of memory.
It would be better thou if we could map it dynamically. This would require a early table handling functions or
a well defined Paging class which can handle this.

The Frame allocator can't try and allocate any memory before the end of the RawAllocators memory region,
so this will also depend on how the RawAllocator is implemented.

Maybe dump the RawAllocator and put it directly into the FrameAllocator?

Frames will start at this address:

    KERNEL_END

Frames bitmap will be of the size:

    ((maxMemoryKiB / 0x1000) / 64 + 1) * 8

Free physical memory starts at:

    KERNEL_END + ((maxMemoryKiB / 0x1000) / 64 + 1) * 8

## Functionallity for paging class

aka Paging

    Table!4 * root;

* this(const ref Paging paging);
* InitKernelPaging();

* ~this() - Free page tables

* void Install() - Switch to this page tables

* VirtAddress Map(VirtAddress virt, PhysAddress phys, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) - Map physical addresses to virtual addresses.

* void Unmap(VirtAddress virt) - Unmap preciously mapped memory

* void MapFreeMemory(VirtAddress virt, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) - Maps and return freely available memory, to be used in memory manager. Lazily  Will allocate the page when first accessed.

## Functionallity for page table class

aka Table!(Level)

    alias ChildType = TablePtr!(Table!(Level-1));

aka Table!(1)

    alias ChildType = TablePtr!(void);


    ChildType[512] entries;

* ChildType * Get(ushort idx)
* ChildType * GetOrCreate(ushort idx, MapMode mode)


## Functionallity for table pointer class

aka TablePtr!(Type) = Bitmap

* @property Type * Data;

* @property MapMode Mode;
