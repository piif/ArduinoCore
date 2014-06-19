
# calling project dir must be defined
ifeq (,${PROJECT_DIR})
  $(error *** PROJECT_DIR must be defined by caller)
endif

# we are in .../ArduinoCore/etc/MakefileCommon
# deduce absolute path of .../ArduinoCore
CORE_DIR := $(abspath $(realpath $(dir $(lastword ${MAKEFILE_LIST}))/..))/

# get per target config
${CORE_DIR}target/boards.config: ${CORE_DIR}src/boards.txt ${CORE_DIR}src/version.txt
	@echo "Generating config target file"
	${CORE_DIR}etc/boardConfigs.sh > $@

-include ${CORE_DIR}target/boards.config

# set toolchain binaries
CC=avr-gcc
CXX=avr-g++
AR=avr-ar
FLASH=avr-objcopy
EEPROM=avr-objcopy
OBJDUMP=avr-objdump
SIZE=avr-size
UPLOAD=avrdude

ifeq (,${ARDDUDE_PATH})
	ARDDUDE_PATH := ${CORE_DIR}../arddude/
endif
CONSOLE=${ARDDUDE_PATH}etc/ad.sh

# deduce every target specific variable
## Target = Uno / target = uno / TARGET = UNO

Target := ${TARGET}
target := $(shell echo ${TARGET} | tr 'A-Z' 'a-z')
override TARGET := $(shell echo ${TARGET} | tr 'a-z' 'A-Z')

TARGET_NAME := ${CONFIG_TARGET_${TARGET}_NAME}
TARGET_UPLOAD_PROTOCOL := ${CONFIG_TARGET_${TARGET}_UPLOAD_PROTOCOL}
TARGET_UPLOAD_MAXIMUM_SIZE := ${CONFIG_TARGET_${TARGET}_UPLOAD_MAXIMUM_SIZE}
TARGET_UPLOAD_SPEED := ${CONFIG_TARGET_${TARGET}_UPLOAD_SPEED}
TARGET_BUILD_MCU := ${CONFIG_TARGET_${TARGET}_BUILD_MCU}
TARGET_BUILD_MCU_SHORT := ${TARGET_BUILD_MCU:atmega%=m%}
TARGET_BUILD_F_CPU := ${CONFIG_TARGET_${TARGET}_BUILD_F_CPU}
TARGET_BUILD_VID := ${CONFIG_TARGET_${TARGET}_BUILD_VID}
TARGET_BUILD_PID := ${CONFIG_TARGET_${TARGET}_BUILD_PID}
TARGET_BUILD_CORE := ${CONFIG_TARGET_${TARGET}_BUILD_CORE}
TARGET_BUILD_VARIANT := ${CONFIG_TARGET_${TARGET}_BUILD_VARIANT}

##$(error TARGET = ${TARGET}, TARGET_BUILD_MCU = ${TARGET_BUILD_MCU})

# deduce flags
TARGET_CFLAGS := -mmcu=${TARGET_BUILD_MCU} -DF_CPU=${TARGET_BUILD_F_CPU} -DUSB_VID=${TARGET_BUILD_VID} -DUSB_PID=${TARGET_BUILD_PID}
TARGET_UPLOADFLAGS := -p${TARGET_BUILD_MCU_SHORT} -c${TARGET_UPLOAD_PROTOCOL} -b${TARGET_UPLOAD_SPEED}

CXXFLAGS := -I${PROJECT_DIR} \
	-I${CORE_DIR}src/cores/${TARGET_BUILD_CORE} \
	-I${CORE_DIR}src/variants/${TARGET_BUILD_VARIANT} \
	-Wall -Os -fpack-struct -fshort-enums -ffunction-sections -fdata-sections \
	-funsigned-char -funsigned-bitfields \
	$(foreach dep,${DEPENDENCIES},-I ${dep}) \
	-DARDUINO=${CORE_VERSION} -DNO_ARDUINO_IDE \
	${TARGET_CFLAGS}

CFLAGS := -std=gnu99 ${CXXFLAGS}

LDFLAGS := ${LD_FLAGS} -mmcu=${TARGET_BUILD_MCU} \
	$(foreach dep,${DEPENDENCIES},-L${dep}/target/${Target} -l$(shell basename ${dep}))

# -h = dump headers
# -S = dump assembly code
# -C = demangle function names
OBJDUMPFLAGS := -h -S -C
SIZEFLAGS := --format=avr --mcu=${TARGET_BUILD_MCU}
UPLOADFLAGS := ${TARGET_UPLOADFLAGS} -P${UPLOAD_DEVICE}
FLASHFLAGS := -R .eeprom -R .fuse -R .lock -R .signature -O ihex
EEPROMFLAGS := -j .eeprom --no-change-warnings --change-section-lma .eeprom=0 -O ihex

# find intermediate files
TARGET_DIR := ${PROJECT_DIR}/target/${Target}/
DEPS := $(foreach src,${ALL_SOURCES},${TARGET_DIR}$(basename ${src}).d)
OBJS := $(foreach src,${ALL_SOURCES},${TARGET_DIR}$(basename ${src}).o)

-include ${DEPS}

config:
ifeq (${TARGET},)
	$(error *** TARGET=... is mandatory ***)
endif
ifeq (,$(findstring ${target},${TARGETS}))
    $(error *** Unknown target ${TARGET} ***)
endif

dep: config ${DEPENDENCIES} ${DEPS}

${DEPENDENCIES}: __FORCE__
	@echo "*** Making dependency $@ ***"
	${MAKE} -C $@ TARGET=${Target}

__FORCE__:

${TARGET_DIR}%.d: %.c
	@mkdir -p $(dir $@)
	${CC} ${CFLAGS} -MM -MP -MF $@ -MT ${@:%.d=%.o} $<

${TARGET_DIR}%.d: %.cpp
	@mkdir -p $(dir $@)
	${CXX} ${CXXFLAGS} -MM -MP -MF $@ -MT ${@:%.d=%.o} $<

${TARGET_DIR}%.d: %.ino
	@mkdir -p $(dir $@)
	${CXX} ${CXXFLAGS} -MM -MP -MF $@ -MT ${@:%.d=%.o} $<

lib: config ${BIN_PATH}

%.a: ${OBJS}
	${AR} -r $@ ${OBJS}

bin: config ${BIN_PATH}

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

size: ${BIN_PATH}
ifeq (${WITH_PRINT_SIZE},yes)
	${SIZE} ${SIZEFLAGS} $<
endif

%.hex: %.elf
	${FLASH} ${FLASHFLAGS} $< $@
	$(eval CONSOLEFLAGS := -f)

%.eep: %.elf
ifeq (${WITH_EEPROM},yes)
	${EEPROM} ${EEPROMFLAGS} $< $@
endif

upload: ${BIN_PATH:%.elf=%.hex}
ifeq (${WITH_UPLOAD},yes)
	${UPLOAD} ${UPLOADFLAGS} -Uflash:w:$<:a
endif

console: ${BIN_PATH:%.elf=%.hex}
	${CONSOLE} ${CONSOLEFLAGS} ${UPLOAD} ${UPLOADFLAGS} -Uflash:w:$<:a

clean:
	rm -rf ${TARGET_DIR}

cleanall:
	rm -rf ${PROJECT_DIR}target/*

.PHONY: clean cleanall config dep bin lib assembly size upload