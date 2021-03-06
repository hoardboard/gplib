
###
# Reference taken from https://github.com/zeromq/zmqpp/blob/develop/Makefile
###

#
# Instance values, command line user specifiable
#

ifneq ($(CONFIG),travis)
	CONFIG = max
endif
CPPFLAGS =
CXXFLAGS =
LDFLAGS  =

PREFIX = /usr/local
BINDIR = $(DESTDIR)$(PREFIX)/bin
LIBDIR = $(DESTDIR)$(PREFIX)/lib
INCLUDEDIR = $(DESTDIR)$(PREFIX)/include

#
# Tools
#

# CXX      = g++
LD       = $(CXX)
AR       = ar

#
# Build values
#

LIBRARY_NAME     = gplib
VERSION_MAJOR    = 0
VERSION_MINOR    = 1
VERSION_REVISION = 1

#
# Paths
#

LIBRARY_DIR  = $(LIBRARY_NAME)
TESTS_DIR    = tests

SRC_PATH     = ./src
LIBRARY_PATH = $(SRC_PATH)/$(LIBRARY_DIR)
TESTS_PATH   = $(SRC_PATH)/$(TESTS_DIR)

BUILD_PATH   = ./build/$(CONFIG)-$(CXX)
OBJECT_PATH  = $(BUILD_PATH)/obj

CUSTOM_INCLUDE_PATH =

#
# Core values
#

APP_VERSION    = $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_REVISION)
APP_DATESTAMP  = $(shell date '+"%Y-%m-%d %H:%M"')

LIBRARY_SHARED  = lib$(LIBRARY_NAME).so
LIBRARY_VERSION_SHARED = $(LIBRARY_SHARED).$(VERSION_MAJOR)
LIBRARY_FULL_VERSION_SHARED = $(LIBRARY_SHARED).$(APP_VERSION)
LIBRARY_ARCHIVE = lib$(LIBRARY_NAME).a
TESTS_TARGET    = $(LIBRARY_NAME)-tests


# OS Specific values

UNAME_S := $(shell uname -s)
LD_EXTRA =
AR_EXTRA =
ifeq ($(UNAME_S),Linux)
	LD_EXTRA += -Wl,-soname -Wl,$(LIBRARY_VERSION_SHARED)
	AR_EXTRA = crf
endif
ifeq ($(UNAME_S),Darwin)
	LIBRARY_SHARED = lib$(LIBRARY_NAME).dylib
	LIBRARY_VERSION_SHARED = lib$(LIBRARY_NAME).$(VERSION_MAJOR).dylib
	LIBRARY_FULL_VERSION_SHARED = lib$(LIBRARY_NAME).$(APP_VERSION).dylib
	AR_EXTRA = cr
endif


CONFIG_FLAGS =
ifeq ($(CONFIG),debug)
	CONFIG_FLAGS = -g -fno-inline -ftemplate-depth-1000
endif
ifeq ($(CONFIG),valgrind)
	CONFIG_FLAGS = -g -O1 -DNO_DEBUG_LOG -DNO_TRACE_LOG
endif
ifeq ($(CONFIG),max)
	CONFIG_FLAGS = -O3 -funroll-loops -ffast-math -fomit-frame-pointer -DNDEBUG
endif
ifneq (,$(findstring $(CONFIG),release loadtest))
	CONFIG_FLAGS = -O3 -funroll-loops -ffast-math -fomit-frame-pointer -DNO_DEBUG_LOG -DNO_TRACE_LOG -DNDEBUG
endif

COMMON_FLAGS = -MMD -std=c++11 -pipe -Wall -fPIC \
	-DBUILD_ENV=$(CONFIG) \
	-DBUILD_DATESTAMP='$(APP_DATESTAMP)' \
	-DBUILD_LIBRARY_NAME='"$(LIBRARY_NAME)"' \
	-I$(SRC_PATH) $(CUSTOM_INCLUDE_PATH)

COMMON_LIBS = -larmadillo -lnlopt

LIBRARY_LIBS =

TEST_LIBS = -L$(BUILD_PATH) \
	-l$(LIBRARY_NAME) \
	-lboost_unit_test_framework
#	-lsodium \
#	-lpthread

ifeq ($(CONFIG),loadtest)
	CONFIG_FLAGS := $(CONFIG_FLAGS) -DLOADTEST
	TEST_LIBS := $(TEST_LIBS) -lboost_thread -lboost_system
endif

ALL_LIBRARY_OBJECTS := $(patsubst $(SRC_PATH)/%.cc, $(OBJECT_PATH)/%.o, $(shell find $(LIBRARY_PATH) -iname '*.cc'))

ALL_LIBRARY_INCLUDES := $(shell find $(LIBRARY_PATH) -iname '*.hpp')

ALL_TEST_OBJECTS := $(patsubst $(SRC_PATH)/%.cc, $(OBJECT_PATH)/%.o, $(shell find $(TESTS_PATH) -iname '*.cc'))

TEST_SUITES := ${addprefix test-,${sort ${shell find ${TESTS_PATH} -iname *.cc | xargs grep BOOST_AUTO_TEST_SUITE\( | sed 's/.*BOOST_AUTO_TEST_SUITE( \(.*\) )/\1/' }}}

#
# BUILD Targets - Standardised
#

.PHONY: clean uninstall test $(TEST_SUITES)

main: $(LIBRARY_SHARED) $(LIBRARY_ARCHIVE)
	@echo "use make check to test the build"

all: $(LIBRARY_SHARED) $(LIBRARY_ARCHIVE)
	@echo "use make check to test the build"

check: $(LIBRARY_SHARED) $(LIBRARY_ARCHIVE) test

install:
	mkdir -p $(INCLUDEDIR)/$(LIBRARY_DIR)
	mkdir -p $(LIBDIR)
	install -m 644 $(ALL_LIBRARY_INCLUDES) $(INCLUDEDIR)/$(LIBRARY_DIR)
	install -m 755 $(BUILD_PATH)/$(LIBRARY_VERSION_SHARED) $(LIBDIR)/$(LIBRARY_FULL_VERSION_SHARED)
	install -m 755 $(BUILD_PATH)/$(LIBRARY_ARCHIVE) $(LIBDIR)/$(LIBRARY_ARCHIVE)
	ln -sf $(LIBRARY_FULL_VERSION_SHARED) $(LIBDIR)/$(LIBRARY_VERSION_SHARED)
	ln -sf $(LIBRARY_FULL_VERSION_SHARED) $(LIBDIR)/$(LIBRARY_SHARED)
	$(LDCONFIG)
	@echo "use make installcheck to test the install"

installcheck: $(TESTS_TARGET)
	$(BUILD_PATH)/$(TESTS_TARGET)

uninstall:
	rm -rf $(INCLUDEDIR)/$(LIBRARY_DIR)
	rm -f $(LIBDIR)/$(LIBRARY_FULL_VERSION_SHARED)
	rm -f $(LIBDIR)/$(LIBRARY_VERSION_SHARED)
	rm -f $(LIBDIR)/$(LIBRARY_SHARED)
	rm -f $(LIBDIR)/$(LIBRARY_ARCHIVE)

clean:
	rm -rf build/*
	rm -rf docs


library: $(LIBRARY_SHARED) $(LIBRARY_ARCHIVE)

#
# BUILD Targets
#

$(LIBRARY_SHARED): $(ALL_LIBRARY_OBJECTS)
	$(LD) $(LDFLAGS) -shared -rdynamic $(LD_EXTRA) -o $(BUILD_PATH)/$(LIBRARY_VERSION_SHARED) $^ $(LIBRARY_LIBS) $(COMMON_LIBS)

$(LIBRARY_ARCHIVE): $(ALL_LIBRARY_OBJECTS)
	$(AR) $(AR_EXTRA) $(BUILD_PATH)/$@ $^

$(TESTS_TARGET): $(LIBRARY_SHARED) $(LIBRARY_ARCHIVE) $(ALL_TEST_OBJECTS)
	$(LD) $(LDFLAGS) -o $(BUILD_PATH)/$@ $(ALL_TEST_OBJECTS) $(TEST_LIBS) $(COMMON_LIBS)

$(TEST_SUITES): $(TESTS_TARGET)
	LD_LIBRARY_PATH=$(BUILD_PATH):$(LD_LIBRARY_PATH) $(BUILD_PATH)/$(TESTS_TARGET) --log_level=message --run_test=$(patsubst test-%,%,$@)

test: $(TESTS_TARGET)
	@echo "running all test targets ($(TEST_SUITES))"
	LD_LIBRARY_PATH=$(BUILD_PATH):$(LD_LIBRARY_PATH) $(BUILD_PATH)/$(TESTS_TARGET)

#
# Dependencies
# We don't care if they don't exist as the object won't have been built
#

-include $(patsubst %.o,%.d,$(ALL_LIBRARY_OBJECTS) $(ALL_TEST_OBJECTS))

#
# Object file generation
#

$(OBJECT_PATH)/%.o: $(SRC_PATH)/%.cc
	-mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(COMMON_FLAGS) $(CONFIG_FLAGS) -c -o $@ $<

