CORE_DIR := $(dir $(firstword ${MAKEFILE_LIST}))/../

ifeq (${MAIN_NAME},)
	MAIN_NAME := $(shell basename ${PROJECT_DIR})
endif
# "=" instead of ":=" because TARGET_DIR will be defined later
# => must not expand variable now
BIN_PATH = ${TARGET_DIR}${MAIN_NAME}.elf

ifeq (${MAIN_SOURCE},)
	MAIN_SOURCE := $(wildcard ${MAIN_NAME}.ino ${MAIN_NAME}.c ${MAIN_NAME}.cpp \
		main.cpp main.c)
endif
ifeq (${MAIN_SOURCE},)
  $(error Can't find main program file. Caller must specify which one to use)
endif
ifneq ($(words ${MAIN_SOURCE}),1)
  $(error Several files may be main program. Caller must specify which one to use)
endif

ifeq (${ALL_SOURCES},)
	ALL_SOURCES := ${MAIN_SOURCE}
endif

all: dep bin assembly size upload

include ${CORE_DIR}etc/common.makefile
