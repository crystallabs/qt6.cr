# QT_DISABLE_DEPRECATED_BEFORE must match the parser flags in `qt.yml`.  Qt is
# built with RTTI, which the `#to?` downcasts of the wrappers need.
CXXFLAGS := -std=c++17 -DQT_DISABLE_DEPRECATED_BEFORE=0x060800 -Wall -Wno-unused-function -fPIC -I$(QT_INCLUDE_DIR) -I.

# The wrappers are called for every Qt call: optimize them.  Override with
# `OPTFLAGS=-O0` for a faster build.
OPTFLAGS ?= -O2
CXXFLAGS += $(OPTFLAGS)
CPPFILES := qt_binding_$(BINDING_PLATFORM).cpp
OBJFILES := $(CPPFILES:.cpp=.o)
LIBFILE  := binding_$(BINDING_PLATFORM).a

# Qt built as macOS frameworks (like Homebrew's) keeps its headers in the
# frameworks.  Must match the parser flags in `qt.yml`.
ifneq ($(wildcard $(QT_LIBS_DIR)/QtCore.framework),)
CXXFLAGS += -F$(QT_LIBS_DIR)
endif

AR ?= ar
RM ?= rm

all: $(LIBFILE)

clean:
	$(RM) -f $(OBJFILES)
	$(RM) -f $(LIBFILE)

$(LIBFILE): $(OBJFILES)
	$(AR) rcs $@ $^

# The wrappers include every header here.
$(OBJFILES): $(wildcard *.hpp)

%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<

.PHONY: clean
