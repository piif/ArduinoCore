
# calling project dir must be defined
ifeq (,${PROJECT_DIR})
  $(error *** PROJECT_DIR must be defined by caller)
endif

# we are in .../ArduinoCore/etc/MakefileCommon
# deduce absolute path of .../ArduinoCore
CORE_DIR ?= $(abspath $(realpath $(dir $(lastword ${MAKEFILE_LIST}))/..))/
##$(info *** common.makefile => CORE_DIR=${CORE_DIR} ***)

# get per target config
${CORE_DIR}target/boards.config: ${CORE_DIR}etc/boardConfigs.sh $(wildcard ${CORE_DIR}src/boards/*) ${CORE_DIR}src/version.txt
	@echo "Generating config target file"
	mkdir -p ${CORE_DIR}target
	${CORE_DIR}etc/boardConfigs.sh > $@

-include ${CORE_DIR}target/boards.config

# set toolchain binaries
CC=${AVR_TOOLS}avr-gcc
CXX=${AVR_TOOLS}avr-g++
AR=${AVR_TOOLS}avr-ar
FLASH=${AVR_TOOLS}avr-objcopy
EEPROM=${AVR_TOOLS}avr-objcopy
OBJDUMP=${AVR_TOOLS}avr-objdump
SIZE=${AVR_TOOLS}avr-size
UPLOAD=${AVR_TOOLS}avrdude
UPLOAD_CONFFILE?=$(wildcard ${AVR_TOOLS}../etc/avrdude.conf)

ifeq (,${ARDDUDE_PATH})
	ARDDUDE_PATH := ${CORE_DIR}../arddude/
endif
CONSOLE=${ARDDUDE_PATH}etc/ad.sh

# deduce every target specific variable, in CamelCase, lowercase and UPPERCASE formats
## TARGET_CC = Uno / TARGET_LC = uno / TARGET_UC = UNO

TARGET_CC := ${TARGET}
TARGET_LC := $(shell echo ${TARGET} | tr 'A-Z' 'a-z')
TARGET_UC := $(shell echo ${TARGET} | tr 'a-z' 'A-Z')

TARGET_NAME := ${CONFIG_TARGET_${TARGET_UC}_NAME}
TARGET_UPLOAD_PROTOCOL := ${CONFIG_TARGET_${TARGET_UC}_UPLOAD_PROTOCOL}
TARGET_UPLOAD_MAXIMUM_SIZE := ${CONFIG_TARGET_${TARGET_UC}_UPLOAD_MAXIMUM_SIZE}
TARGET_UPLOAD_SPEED := ${CONFIG_TARGET_${TARGET_UC}_UPLOAD_SPEED}
TARGET_BUILD_MCU := ${CONFIG_TARGET_${TARGET_UC}_BUILD_MCU}
TARGET_BUILD_MCU_SHORT := ${TARGET_BUILD_MCU:atmega%=m%}
TARGET_BUILD_F_CPU := ${CONFIG_TARGET_${TARGET_UC}_BUILD_F_CPU}
TARGET_BUILD_VID := ${CONFIG_TARGET_${TARGET_UC}_BUILD_VID}
TARGET_BUILD_PID := ${CONFIG_TARGET_${TARGET_UC}_BUILD_PID}
TARGET_BUILD_CORE := ${CONFIG_TARGET_${TARGET_UC}_BUILD_CORE}
TARGET_BUILD_VARIANT := ${CONFIG_TARGET_${TARGET_UC}_BUILD_VARIANT}

##$(error TARGET = ${TARGET}, TARGET_BUILD_MCU = ${TARGET_BUILD_MCU})

# deduce flags
TARGET_CFLAGS := -mmcu=${TARGET_BUILD_MCU} -DF_CPU=${TARGET_BUILD_F_CPU} -DUSB_VID=${TARGET_BUILD_VID} -DUSB_PID=${TARGET_BUILD_PID}
TARGET_UPLOADFLAGS := -p${TARGET_BUILD_MCU_SHORT} -c${TARGET_UPLOAD_PROTOCOL} -b${TARGET_UPLOAD_SPEED} -D
ifeq (${CONFIG_TARGET_${TARGET_UC}_UPLOAD_WAIT_FOR_UPLOAD_PORT},true)
	CONSOLEFLAGS := -r
endif

CXXFLAGS := -DPIF_TOOL_CHAIN -DDEFAULT_BAUDRATE=${TARGET_UPLOAD_SPEED} \
	-I${PROJECT_DIR} \
	-I${CORE_DIR}src/cores/${TARGET_BUILD_CORE} \
	-I${CORE_DIR}src/variants/${TARGET_BUILD_VARIANT} \
	-Wall -Os -fpack-struct -fshort-enums -ffunction-sections -fdata-sections \
	-funsigned-char -funsigned-bitfields \
	$(foreach dep,${DEPENDENCIES},-I${dep}) \
	-DARDUINO=${CORE_VERSION} -DNO_ARDUINO_IDE \
	${TARGET_CFLAGS}

CFLAGS := -std=gnu99 ${CXXFLAGS}

LDFLAGS := ${LD_FLAGS} -mmcu=${TARGET_BUILD_MCU} \
	$(foreach dep,${DEPENDENCIES} ${CORE_DIR},-L${dep}/target/${TARGET_CC} -l$(shell basename ${dep}))
DEP_LIBS := $(foreach dep,${DEPENDENCIES} ${CORE_DIR},${dep}/target/${TARGET_CC}/lib$(shell basename ${dep}).a)

# -h = dump headers
# -S = dump assembly code
# -C = demangle function names
OBJDUMPFLAGS := -h -S -C
SIZEFLAGS := --format=avr --mcu=${TARGET_BUILD_MCU}
UPLOADFLAGS := ${TARGET_UPLOADFLAGS} -P${UPLOAD_DEVICE}
ifneq (${UPLOAD_CONFFILE},)
	UPLOADFLAGS := ${UPLOADFLAGS} -C${UPLOAD_CONFFILE}
endif
FLASHFLAGS := -R .eeprom -R .fuse -R .lock -R .signature -O ihex
EEPROMFLAGS := -j .eeprom --no-change-warnings --change-section-lma .eeprom=0 -O ihex

# find intermediate files
TARGET_DIR := ${PROJECT_DIR}/target/${TARGET_CC}/
DEPS := $(foreach src,${ALL_SOURCES},${TARGET_DIR}$(basename ${src}).d)
OBJS := $(foreach src,${ALL_SOURCES},${TARGET_DIR}$(basename ${src}).o)

-include ${DEPS}

config:
ifeq (${TARGET},)
	$(error *** TARGET=... is mandatory ***)
endif
ifeq (${BOARD_CONFIG},OK)
	ifeq (,$(findstring ${TARGET_LC},${TARGETS}))
		$(error *** Unknown target ${TARGET} ***)
	endif
endif

dep: config ${DEPENDENCIES} ${DEPS}

${DEPENDENCIES}: __FORCE__
	@echo "*** Making dependency $@ ***"
	${MAKE} -C $@ PROJECT_DIR=$@ TARGET=${TARGET_CC}

__FORCE__:

${TARGET_DIR}%.d: %.c
	@mkdir -p $(dir $@)
	${CC} ${CFLAGS} -MM -MP -MF $@ -MT ${@:%.d=%.o} $<

${TARGET_DIR}%.d: %.cpp
	@mkdir -p $(dir $@)
	${CXX} ${CXXFLAGS} -MM -MP -MF $@ -MT ${@:%.d=%.o} $<

${TARGET_DIR}%.d: %.ino
	@mkdir -p $(dir $@)
	${CXX} ${CXXFLAGS} -x c++ -MM -MP -MF $@ -MT ${@:%.d=%.o} $<

lib: config ${BIN_PATH}

%.a: ${OBJS}
	${AR} -r $@ ${OBJS}

bin: config ${BIN_PATH}
 
# TODO : ${DEP_LIBS} fails because confuse %.a rule with lib rules ...
%.elf: ${OBJS}
	${CXX} -Wl,-Map,${@:%.elf=%.map},--cref -mrelax -Wl,--gc-sections -o $@ ${OBJS} ${LDFLAGS}

${TARGET_DIR}%.o: %.c
	@mkdir -p $(dir $@)
	${CC} ${CFLAGS} -o $@ -c $<

${TARGET_DIR}%.o: %.S
	Which cmd line for assembler sources ???
	@mkdir -p $(dir $@)
	${CC} ${CFLAGS} -o $@ -c $<

${TARGET_DIR}%.o: %.cpp
	@mkdir -p $(dir $@)
	${CXX} ${CXXFLAGS} -o $@ -c $<

${TARGET_DIR}%.o: %.ino
	@mkdir -p $(dir $@)
	${CXX} ${CXXFLAGS} -x c++ -o $@ -c $<

assembly: $(basename ${BIN_PATH}).lss

%.lss: %.elf
ifeq (${WITH_ASSEMBLY},yes)
	${OBJDUMP} ${OBJDUMPFLAGS} $< > $@
endif

%.lss: %.a
ifeq (${WITH_ASSEMBLY},yes)
	${OBJDUMP} ${OBJDUMPFLAGS} $< > $@
endif

size: ${BIN_PATH}
ifeq (${WITH_PRINT_SIZE},yes)
	${SIZE} ${SIZEFLAGS} $<
endif

%.hex: %.elf
	${FLASH} ${FLASHFLAGS} $< $@
	$(eval CONSOLEFLAGS := ${CONSOLEFLAGS} -f)

%.eep: %.elf
ifeq (${WITH_EEPROM},yes)
	${EEPROM} ${EEPROMFLAGS} $< $@
endif

hex: ${BIN_PATH:%.elf=%.hex}

upload: hex
	${UPLOAD} ${UPLOADFLAGS} -Uflash:w:$<:a

console: ${BIN_PATH:%.elf=%.hex}
	${CONSOLE} ${CONSOLEFLAGS} ${UPLOAD} ${UPLOADFLAGS} -Uflash:w:$<:a

clean:
	rm -rf ${TARGET_DIR}

cleanall:
	rm -rf ${PROJECT_DIR}target/*

.PHONY: clean cleanall config dep bin lib hex assembly size upload
