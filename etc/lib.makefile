CORE_DIR := $(dir $(firstword ${MAKEFILE_LIST}))/../

# if undefined by caller, destination lib name = parent directory name
ifeq (${LIB_NAME},)
	LIB_NAME := $(shell basename ${PROJECT_DIR})
endif
# "=" instead of ":=" because TARGET_DIR will be defined later
# => must not expand variable now
BIN_PATH = ${TARGET_DIR}lib${LIB_NAME}.a

EXCLUDES := $(foreach d,${EXCLUDE_DIRS},-name $d -prune \, )

C_SOURCES := $(shell find . ${EXCLUDES} -name examples -prune , -name "*.c")
CPP_SOURCES := $(shell find . ${EXCLUDES} -name examples -prune , -name "*.cpp")
ASM_SOURCES := $(shell find . ${EXCLUDES} -name examples -prune , -name "*.S")
ALL_SOURCES := ${C_SOURCES} ${CPP_SOURCES} ${ASM_SOURCES}

OBJS := ${C_SOURCES:%.c=%.o} ${CPP_SOURCES:%.cpp=%.o} ${ASM_SOURCES:%.S=%.o}

all: dep lib assembly size

include ${CORE_DIR}etc/common.makefile
