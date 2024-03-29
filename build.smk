#________________________________________
#      BUILD SCRIPT (don't change)      |
#_______________________________________|
ifeq ($(mode),)
	mode = debug
endif
ifeq ($(mode),debug)
	CFLAGS := -O0 -g -DDEBUG -std=c99 -pedantic -Wextra -Wconversion $(CFLAGS)
	LDFLAGS := $(LDFLAGS)
endif
ifeq ($(mode),profile)
	CFLAGS := -O0 -g -DDEBUG -std=c99 -p -ftest-coverage -Wcoverage-mismatch $(CFLAGS)
	LDFLAGS := -g -p $(LDFLAGS)
endif
ifeq ($(mode),develop)
	CFLAGS := -O2 -g -DDEBUG -std=c99 $(CFLAGS)
	LDFLAGS := -O1 $(LDFLAGS)
endif
ifeq ($(mode),release)
	CFLAGS := -O2 -std=c99 $(CFLAGS)
	LDFLAGS := -O1 $(LDFLAGS)
endif

CFLAGS += -Wall $(INCLUDES)
LDFLAGS += -Wall

all:
	@make change_make_options &>/dev/null
	+make $(TARGETS)

ifneq ($(mode),debug)
ifneq ($(mode),profile)
ifneq ($(mode),develop)
ifneq ($(mode),release)
	@echo "Invalid build mode."
	@echo "Please use 'make mode=release', 'make mode=develop', 'make mode=profile' or 'make mode=debug'"
	@exit 1
endif
endif
endif
endif
	@echo ".........................."
	@echo "Building on "$(mode)" mode "
	@echo "CFLAGS=$(CFLAGS)"
	@echo "LDFLAGS=$(LDFLAGS)"
	@echo ".........................."

OLD_BUILD_MODE=$(shell grep ^MODE make_options.out 2>/dev/null | sed 's~^MODE=~~')
OLD_BUILD_CFLAGS=$(shell grep ^CFLAGS make_options.out 2>/dev/null | sed 's~^CFLAGS=~~')
OLD_BUILD_LDFLAGS=$(shell grep ^LDFLAGS make_options.out 2>/dev/null | sed 's~^LDFLAGS=~~')
change_make_options:
ifneq ($(mode)|$(CFLAGS)|$(LDFLAGS), $(OLD_BUILD_MODE)|$(OLD_BUILD_CFLAGS)|$(OLD_BUILD_LDFLAGS))
	@echo CLEANING...
	@make clean
	@echo "MODE=$(mode)" > make_options.out
	@echo "CFLAGS=$(CFLAGS)" >> make_options.out
	@echo "LDFLAGS=$(LDFLAGS)" >> make_options.out
endif

%.o :
	$(CC) -c $(CFLAGS) $(SRC) -o $@ $<

clean:
	$(RM) *.o *.out callgrind.out.* *.gcno $(TARGETS)

.PHONY: all change_make_options clean
