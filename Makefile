# the directory this project is in
# must be defined for generic makefile to work
export PROJECT_DIR := $(dir $(realpath ${MAKEFILE_LIST}))
##$(info *** Makefile => PROJECT_DIR=${PROJECT_DIR} ***)

# other arduino librairies project pathes this project depends on
export DEPENDENCIES :=

# generate assembler source code also
export WITH_ASSEMBLY := yes

# generate eeprom image
export WITH_EEPROM := no

# print size of geretated segments 
export WITH_PRINT_SIZE := no

# only for programs : launch upload
export WITH_UPLOAD := no
# where to upload
# TODO : try to auto detect with lsusb + /proc exploration
#export UPLOAD_DEVICE := /dev/ttyACM0

# if different of containing dir
export LIB_NAME := 
# TODO : add a "if" on TARGET to launch on this target, or for each known one

# to define to ArduinoCore root directory 
CORE_DIR := ${PROJECT_DIR}

# call MakefileLib for a utilities library or MakefileBin for a program
all:
	${MAKE} -f ${CORE_DIR}etc/lib.makefile
