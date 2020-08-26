#
# Copyright (c) 2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

BUILD_TOP := $(shell pwd)

TARGET_AUTO_KDIR := $(shell echo $(TARGET_DEVICE_DIR) | sed -e 's/^device/kernel/g')
TARGET_KERNEL_SOURCE ?= $(TARGET_AUTO_KDIR)
ifneq ($(TARGET_PREBUILT_KERNEL),)
TARGET_KERNEL_SOURCE :=
endif

TARGET_KERNEL_ARCH := $(strip $(TARGET_KERNEL_ARCH))
ifeq ($(TARGET_KERNEL_ARCH),)
KERNEL_ARCH := $(TARGET_ARCH)
else
KERNEL_ARCH := $(TARGET_KERNEL_ARCH)
endif

GCC_PREBUILTS := $(BUILD_TOP)/prebuilts/gcc/$(HOST_OS)-x86

ifeq ($(TARGET_KERNEL_NEW_GCC_COMPILE),true)
    ifeq ($(TARGET_KERNEL_CLANG_COMPILE),true)
        $(error TARGET_KERNEL_NEW_GCC_COMPILE cannot be used with TARGET_KERNEL_CLANG_COMPILE!)
    endif

    KERNEL_TOOLCHAIN_arm64 := $(GCC_PREBUILTS)/aarch64/aarch64-elf/bin
    KERNEL_TOOLCHAIN_PREFIX_arm64 := aarch64-elf-

    KERNEL_TOOLCHAIN_arm := $(GCC_PREBUILTS)/arm/arm-eabi/bin
    KERNEL_TOOLCHAIN_PREFIX_arm := arm-eabi-
else
    KERNEL_TOOLCHAIN_arm64 := $(GCC_PREBUILTS)/aarch64/aarch64-linux-android-4.9/bin
    KERNEL_TOOLCHAIN_PREFIX_arm64 := aarch64-linux-android-

    KERNEL_TOOLCHAIN_arm := $(GCC_PREBUILTS)/arm/arm-linux-androideabi-4.9/bin
    KERNEL_TOOLCHAIN_PREFIX_arm := arm-linux-androidkernel-
endif

TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(strip $(TARGET_KERNEL_CROSS_COMPILE_PREFIX))
ifneq ($(TARGET_KERNEL_CROSS_COMPILE_PREFIX),)
KERNEL_TOOLCHAIN_PREFIX ?= $(TARGET_KERNEL_CROSS_COMPILE_PREFIX)
else
KERNEL_TOOLCHAIN ?= $(KERNEL_TOOLCHAIN_$(KERNEL_ARCH))
KERNEL_TOOLCHAIN_PREFIX ?= $(KERNEL_TOOLCHAIN_PREFIX_$(KERNEL_ARCH))
endif

ifeq ($(KERNEL_TOOLCHAIN),)
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN_PREFIX)
else
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN)/$(KERNEL_TOOLCHAIN_PREFIX)
endif

KERNEL_TOOLCHAIN_PATH_gcc := $(KERNEL_TOOLCHAIN_$(KERNEL_ARCH))/$(KERNEL_TOOLCHAIN_PREFIX_$(KERNEL_ARCH))

ifneq ($(USE_CCACHE),)
    ifneq ($(CCACHE_EXEC),)
        CCACHE_BIN := $(CCACHE_EXEC)
    endif
endif

ifeq ($(TARGET_KERNEL_CLANG_COMPILE),true)
    KERNEL_CROSS_COMPILE := CROSS_COMPILE="$(KERNEL_TOOLCHAIN_PATH)"
else
    KERNEL_CROSS_COMPILE := CROSS_COMPILE="$(CCACHE_BIN) $(KERNEL_TOOLCHAIN_PATH)"
endif

ifeq ($(KERNEL_ARCH),arm64)
   KERNEL_CROSS_COMPILE += CROSS_COMPILE_ARM32="$(KERNEL_TOOLCHAIN_arm)/$(KERNEL_TOOLCHAIN_PREFIX_arm)"
endif

KERNEL_MAKE_FLAGS :=

KERNEL_MAKE_FLAGS += -j$(shell nproc --all)

ifeq ($(KERNEL_ARCH),arm)
  KERNEL_MAKE_FLAGS += CFLAGS_MODULE="-fno-pic"
endif

ifeq ($(KERNEL_ARCH),arm64)
  KERNEL_MAKE_FLAGS += CFLAGS_MODULE="-fno-pic"
endif

ifeq ($(HOST_OS),darwin)
  KERNEL_MAKE_FLAGS += C_INCLUDE_PATH=$(BUILD_TOP)/external/elfutils/libelf:/usr/local/opt/openssl/include
  KERNEL_MAKE_FLAGS += LIBRARY_PATH=/usr/local/opt/openssl/lib
else
  KERNEL_MAKE_FLAGS += C_INCLUDE_PATH=$(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/include
  KERNEL_MAKE_FLAGS += LIBRARY_PATH=$(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/lib/x86_64-linux-gnu
  KERNEL_MAKE_FLAGS += HOSTCFLAGS="-L $(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/lib/x86_64-linux-gnu"
  KERNEL_MAKE_FLAGS += HOSTLDFLAGS="-L $(BUILD_TOP)/prebuilts/openssl/$(HOST_OS)-x86/1.1.1/lib/x86_64-linux-gnu"
endif

ifneq ($(TARGET_KERNEL_ADDITIONAL_FLAGS),)
  KERNEL_MAKE_FLAGS += $(TARGET_KERNEL_ADDITIONAL_FLAGS)
endif

TOOLS_PATH_OVERRIDE := \
    PATH=$(BUILD_TOP)/prebuilts/tools-pa/$(HOST_OS)-x86/bin:$$PATH \
    LD_LIBRARY_PATH=$(BUILD_TOP)/prebuilts/tools-pa/$(HOST_OS)-x86/lib:$$LD_LIBRARY_PATH \
    PERL5LIB=$(BUILD_TOP)/prebuilts/tools-pa/common/perl-base

ifeq ($(TARGET_NEEDS_DTBOIMAGE),true)
BOARD_PREBUILT_DTBOIMAGE ?= $(PRODUCT_OUT)/dtbo/arch/$(KERNEL_ARCH)/boot/dtbo.img
else ifeq ($(BOARD_KERNEL_SEPARATED_DTBO),true)
BOARD_PREBUILT_DTBOIMAGE ?= $(PRODUCT_OUT)/dtbo-pre.img
endif

KERNEL_DTC_CMD := $(BUILD_TOP)/prebuilts/build-tools/$(HOST_OS)-x86/bin/dtc

KERNEL_MAKE_CMD := $(BUILD_TOP)/prebuilts/build-tools/$(HOST_OS)-x86/bin/make

ifeq ($(HOST_OS),darwin)
KERNEL_HOST_TOOLCHAIN_ROOT := $(GCC_PREBUILTS)/host/i686-apple-darwin-4.2.1/bin/i686-apple-darwin11-
else
KERNEL_HOST_TOOLCHAIN_ROOT := $(GCC_PREBUILTS)/host/x86_64-linux-glibc2.17-4.8/bin/x86_64-linux-
endif
KERNEL_MAKE_FLAGS += HOSTCC=$(KERNEL_HOST_TOOLCHAIN_ROOT)gcc
KERNEL_MAKE_FLAGS += HOSTCXX=$(KERNEL_HOST_TOOLCHAIN_ROOT)g++

KERNEL_MAKE_FLAGS += LEX=$(BUILD_TOP)/prebuilts/build-tools/$(HOST_OS)-x86/bin/flex
KERNEL_MAKE_FLAGS += YACC=$(BUILD_TOP)/prebuilts/build-tools/$(HOST_OS)-x86/bin/bison
TOOLS_PATH_OVERRIDE += BISON_PKGDATADIR=$(BUILD_TOP)/prebuilts/build-tools/common/bison

OUT_DIR_PREFIX := $(shell echo $(OUT_DIR) | sed -e 's|/target/.*$$||g')
KERNEL_BUILD_OUT_PREFIX :=
ifeq ($(OUT_DIR_PREFIX),out)
KERNEL_BUILD_OUT_PREFIX := $(BUILD_TOP)/
endif
