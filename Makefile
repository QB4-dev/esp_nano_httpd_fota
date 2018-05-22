# Output directors to store intermediate compiled files
# relative to the project directory
BUILD_BASE	= build
FW_BASE		= firmware

# base directory for the compiler
XTENSA_TOOLS_ROOT ?= /opt/esp-open-sdk/xtensa-lx106-elf/bin

# base directory of the ESP8266 SDK package, absolute
SDK_BASE	?= /opt/esp-open-sdk/sdk

#Esptool.py path and port
ESPTOOL		?= esptool.py
ESPPORT		?= /dev/ttyUSB0
#ESPDELAY indicates seconds to wait between flashing the two binary images
ESPDELAY	?= 3
ESPBAUD		?= 921600

# name for the target project
TARGET		= app

# which modules (subdirectories) of the project to include in compiling
MODULES			= user esp_nano_httpd esp_nano_httpd/util
EXTRA_INCDIR	= include driver/include

# libraries used in this project, mainly provided by the SDK
LIBS	= c gcc hal pp phy net80211 lwip wpa main driver json

# compiler flags using during compilation of source files
CFLAGS	= -Os -g -O2 -Wpointer-arith -Wundef -Werror -Wl,-EL -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals  -D__ets__ -DICACHE_FLASH

# linker flags used to generate the main object file
LDFLAGS		= -nostdlib -Wl,--no-check-sections -u call_user_start -Wl,-static

# various paths from the SDK used in this project
SDK_LIBDIR	= lib
SDK_LDDIR	= ld
SDK_INCDIR	= include include/json driver_lib/include

#SPI flash size, in K
ESP_SPI_FLASH_SIZE_K=4096
#0: QIO, 1: QOUT, 2: DIO, 3: DOUT
ESP_FLASH_MODE=0
#0: 40MHz, 1: 26MHz, 2: 20MHz, 15: 80MHz
ESP_FLASH_FREQ_DIV=0

# select which tools to use as compiler, librarian and linker
CC		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-gcc
AR		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-ar
LD		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-gcc
OBJCOPY	:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-objcopy

#Appgen path and name
APPGEN		?= $(SDK_BASE)/tools/gen_appbin.py

####
#### no user configurable options below here
####
SRC_DIR		:= $(MODULES)
BUILD_DIR	:= $(addprefix $(BUILD_BASE)/,$(MODULES))

SDK_LIBDIR	:= $(addprefix $(SDK_BASE)/,$(SDK_LIBDIR))
SDK_INCDIR	:= $(addprefix -I$(SDK_BASE)/,$(SDK_INCDIR))

SRC		:= $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.c))
ASMSRC	 = $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.S))
OBJ		 = $(patsubst %.c,$(BUILD_BASE)/%.o,$(SRC))
OBJ		+= $(patsubst %.S,$(BUILD_BASE)/%.o,$(ASMSRC))
APP_AR	:= $(addprefix $(BUILD_BASE)/,$(TARGET)_app.a)

FW_FILE_1	:= $(addprefix $(FW_BASE)/,$(TARGET).user1.bin)
FW_FILE_2	:= $(addprefix $(FW_BASE)/,$(TARGET).user2.bin)

V ?= $(VERBOSE)
ifeq ("$(V)","1")
Q :=
vecho := @true
else
Q := @
vecho := @echo
endif


#Define default target. If not defined here the one in the included Makefile is used as the default one.
default-tgt: all

define maplookup
$(patsubst $(strip $(1)):%,%,$(filter $(strip $(1)):%,$(2)))
endef

# linker script used for the linker step

LD_MAP_1:=512:eagle.app.v6.new.512.app1.ld 1024:eagle.app.v6.new.1024.app1.ld 2048:eagle.app.v6.new.2048.ld 4096:eagle.app.v6.new.2048.ld
LD_MAP_2:=512:eagle.app.v6.new.512.app2.ld 1024:eagle.app.v6.new.1024.app2.ld 2048:eagle.app.v6.new.2048.ld 4096:eagle.app.v6.new.2048.ld
LD_SCRIPT_USR1	:= $(call maplookup,$(ESP_SPI_FLASH_SIZE_K),$(LD_MAP_1))
LD_SCRIPT_USR2	:= $(call maplookup,$(ESP_SPI_FLASH_SIZE_K),$(LD_MAP_2))

TARGET_OUT_USR1 := $(addprefix $(BUILD_BASE)/,$(TARGET).user1.out)
TARGET_OUT_USR2 := $(addprefix $(BUILD_BASE)/,$(TARGET).user2.out)
TARGET_OUT	:=  $(TARGET_OUT_USR1) $(TARGET_OUT_USR2)

TARGET_BIN_USR1 := $(addprefix $(BUILD_BASE)/,$(TARGET).user1.bin)
TARGET_BIN_USR2 := $(addprefix $(BUILD_BASE)/,$(TARGET).user2.bin)
TARGET_BIN	:=  $(TARGET_BIN_USR1) $(TARGET_BIN_USR2)

#erase info
BLANK_MAP:=512:0x7E000 1024:0xFE000 2048: 0x1FE000 4096:0x3FE000
INITDATA_MAP:=512:0x7C000 1024:0xFC000 2048:0x1FC000 4096:0x3FC000

BLANKPOS=$(call maplookup,$(ESP_SPI_FLASH_SIZE_K),$(BLANK_MAP))
INITDATAPOS=$(call maplookup,$(ESP_SPI_FLASH_SIZE_K),$(INITDATA_MAP))

#Convert SPI size into arg for appgen. Format: no=size
FLASH_MAP_CONV:=0:512 2:1024 5:2048 6:4096
ESP_FLASH_SIZE_IX:=$(maplookup $(ESP_SPI_FLASH_SIZE_K),,$(FLASH_MAP_CONV))
	
#Add all prefixes to paths
LIBS			:= $(addprefix -l,$(LIBS))
LD_SCRIPT_USR1	:= $(addprefix -T$(SDK_BASE)/$(SDK_LDDIR)/,$(LD_SCRIPT_USR1))
LD_SCRIPT_USR2	:= $(addprefix -T$(SDK_BASE)/$(SDK_LDDIR)/,$(LD_SCRIPT_USR2))
INCDIR			:= $(addprefix -I,$(SRC_DIR))
EXTRA_INCDIR	:= $(addprefix -I,$(EXTRA_INCDIR))
MODULE_INCDIR	:= $(addsuffix /include,$(INCDIR))

ESP_FLASH_SIZE_IX=$(call maplookup,$(ESP_SPI_FLASH_SIZE_K),512:0 1024:2 2048:5 4096:6)
ESPTOOL_FREQ=$(call maplookup,$(ESP_FLASH_FREQ_DIV),0:40m 1:26m 2:20m 0xf:80m 15:80m)
ESPTOOL_MODE=$(call maplookup,$(ESP_FLASH_MODE),0:qio 1:qout 2:dio 3:dout)
ESPTOOL_SIZE=$(call maplookup,$(ESP_SPI_FLASH_SIZE_K),512:4m 256:2m 1024:8m 2048:16m 4096:32m-c1)

ESPTOOL_OPTS=--port $(ESPPORT) --baud $(ESPBAUD)
ESPTOOL_FLASHDEF=--flash_freq $(ESPTOOL_FREQ) --flash_mode $(ESPTOOL_MODE) --flash_size $(ESPTOOL_SIZE)

vpath %.c $(SRC_DIR)
vpath %.S $(SRC_DIR)

define compile-objects
$1/%.o: %.c
	$(vecho) "CC $$<"
	$(Q) $(CC) $(INCDIR) $(MODULE_INCDIR) $(EXTRA_INCDIR) $(SDK_INCDIR) $(CFLAGS)  -c $$< -o $$@

$1/%.o: %.S
	$(vecho) "CC $$<"
	$(Q) $(CC) $(INCDIR) $(MODULE_INCDIR) $(EXTRA_INCDIR) $(SDK_INCDIR) $(CFLAGS)  -c $$< -o $$@
endef

define genappbin
$(1): $$(APP_AR)
	$$(vecho) LD $$@
	$$(Q) $$(LD) -L$$(SDK_LIBDIR) $(2) $$(LDFLAGS) -Wl,--start-group $$(LIBS) $$(APP_AR) -Wl,--end-group -o $$@

$(3): $(1)
	$$(vecho) APPGEN $$@
	$$(Q) $$(OBJCOPY) --only-section .text -O binary $1 build/eagle.app.v6.text.bin
	$$(Q) $$(OBJCOPY) --only-section .data -O binary $1 build/eagle.app.v6.data.bin
	$$(Q) $$(OBJCOPY) --only-section .rodata -O binary $1 build/eagle.app.v6.rodata.bin
	$$(Q) $$(OBJCOPY) --only-section .irom0.text -O binary $1 build/eagle.app.v6.irom0text.bin
	$$(Q) cd build; COMPILE=gcc PATH=$$(XTENSA_TOOLS_ROOT):$$(PATH) python $$(APPGEN) $(1:build/%=%) 2 $$(ESP_FLASH_MODE) $$(ESP_FLASH_FREQ_DIV) $$(ESP_FLASH_SIZE_IX) $(4)
	$$(Q) rm -f build/eagle.app.v6.*.bin
	$$(Q) rm -f build/$(1)
	$$(Q) mv build/eagle.app.flash.bin $$@
	@echo "INFO: $(3) uses $$$$(stat -c '%s' $$@) flash bytes"
endef

$(eval $(call genappbin,$(TARGET_OUT_USR1),$$(LD_SCRIPT_USR1),$$(TARGET_BIN_USR1),1))
$(eval $(call genappbin,$(TARGET_OUT_USR2),$$(LD_SCRIPT_USR2),$$(TARGET_BIN_USR2),2))

.PHONY: all checkdirs clean default-tgt html

all: checkdirs  html $(TARGET_OUT) $(FW_FILE_1) $(FW_FILE_2)


checkdirs: $(BUILD_DIR) $(FW_BASE)

html:
	@echo "generating html includes..."
	$(Q) $(shell ./html/gen_includes.sh)

$(APP_AR): $(OBJ)
	$(vecho) "AR $@"
	$(Q) $(AR) cru $@ $(OBJ)

$(BUILD_DIR):
	$(Q) mkdir -p $@

$(FW_BASE):
	$(Q) mkdir -p $@
	
$(FW_FILE_1): $(FW_BASE) $(TARGET_BIN_USR1)
	$(vecho) "FW $(FW_BASE)/$@"
	$(Q) cp $(TARGET_BIN_USR1) $(FW_FILE_1)
	
 $(FW_FILE_2): $(FW_BASE) $(TARGET_BIN_USR2)
	$(vecho) "FW $(FW_BASE)/$@"
	$(Q) cp $(TARGET_BIN_USR2) $(FW_FILE_2)

flash: $(TARGET_OUT) $(FW_BASE)
	$(Q) $(ESPTOOL) $(ESPTOOL_OPTS) write_flash $(ESPTOOL_FLASHDEF) 0x00000 "$(SDK_BASE)/bin/boot_v1.6.bin" 0x01000 $(FW_FILE_1)
	
flash_ota: $(TARGET_OUT) $(FW_BASE)
	$(Q) $(ESPTOOL) $(ESPTOOL_OPTS) write_flash $(ESPTOOL_FLASHDEF) 0x101000 $(FW_FILE_2)

blankflash:
	$(Q) $(ESPTOOL) $(ESPTOOL_OPTS) write_flash $(ESPTOOL_FLASHDEF) $(BLANKPOS) $(SDK_BASE)/bin/blank.bin $(INITDATAPOS) $(SDK_BASE)/bin/esp_init_data_default.bin

#httpflash: $(FW_BASE)
#	$(Q) curl -X POST --data-binary '@build/httpd.ota' $(ESPIP)/flash/upload > /dev/null
#	$(Q) curl $(ESPIP)/flash/reboot
#	$(Q) echo -e '\nDone'
	
clean:
	$(Q) rm -f  $(APP_AR)
	$(Q) rm -f  $(TARGET_OUT)
	$(Q) rm -rf $(FW_BASE) 
	$(Q) rm -rf $(BUILD_BASE) 
	$(Q) rm -rf html/include

$(foreach bdir,$(BUILD_DIR),$(eval $(call compile-objects,$(bdir))))
