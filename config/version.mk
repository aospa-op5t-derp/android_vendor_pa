#
# Copyright (C) 2019 Paranoid Android
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

ifndef PA_VERSION_FLAVOR
PA_VERSION_FLAVOR := Quartz
endif

ifndef PA_VERSION_CODE
PA_VERSION_CODE := -
endif

ifndef PA_BUILDTYPE
PA_BUILD_VARIANT := Extended
else
ifeq ($(PA_BUILDTYPE), ALPHA)
PA_BUILD_VARIANT := Alpha
else ifeq ($(PA_BUILDTYPE), BETA)
PA_BUILD_VARIANT := Beta
else ifeq ($(PA_BUILDTYPE), RELEASE)
PA_BUILD_VARIANT := Release
endif
endif

ifeq ($(PA_VERSION_APPEND_TIME_OF_DAY),true)
BUILD_DATE := $(shell date -u +%Y%m%d_%H%M%S)
else
BUILD_DATE := $(shell date -u +%Y%m%d)
endif

ifneq ($(filter Release,$(PA_BUILD_VARIANT)),)
PA_VERSION := $(shell echo $(PA_VERSION_FLAVOR) | tr A-Z a-z)-$(PA_VERSION_CODE)-$(PA_BUILD)-$(BUILD_DATE)
else ifneq ($(filter Alpha Beta,$(PA_BUILD_VARIANT)),)
PA_VERSION := $(shell echo $(PA_VERSION_FLAVOR) | tr A-Z a-z)-$(shell echo $(PA_BUILD_VARIANT) | tr A-Z a-z)-$(PA_VERSION_CODE)-$(PA_BUILD)-$(BUILD_DATE)
else
PA_VERSION := $(shell echo $(PA_VERSION_FLAVOR) | tr A-Z a-z)-$(PA_VERSION_CODE)-$(PA_BUILD)-$(BUILD_DATE)-$(shell echo $(PA_BUILD_VARIANT) | tr A-Z a-z)
endif

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.pa.version=$(PA_VERSION)

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.pa.version.flavor=$(PA_VERSION_FLAVOR) \
    ro.pa.version.code=$(PA_VERSION_CODE) \
    ro.pa.build.variant=$(PA_BUILD_VARIANT)
