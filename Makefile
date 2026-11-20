CC ?= cc
PKG_CONFIG ?= pkg-config
CFLAGS ?= -O2
NODE ?= node

.PHONY: all test clean
all: build/vizamp-analyzer

build:
	mkdir -p $@

build/vizamp-analyzer: spectrum.c analysis.c analysis.h Makefile | build
	@$(PKG_CONFIG) --exists libpulse-simple fftw3 || { echo "Install libpulse, fftw and pkgconf before building Vizamp." >&2; exit 1; }
	@set -e; tmp=$$(mktemp "$@.XXXXXX"); trap 'rm -f "$$tmp"' EXIT; \
		$(CC) $(CPPFLAGS) $(CFLAGS) -Wall -Wextra $$($(PKG_CONFIG) --cflags libpulse-simple fftw3) \
			$(LDFLAGS) spectrum.c analysis.c -o "$$tmp" $$($(PKG_CONFIG) --libs libpulse-simple fftw3) -lm; \
		chmod 755 "$$tmp"; mv -f "$$tmp" "$@"

build/test-analysis: tests/test_analysis.c analysis.c analysis.h Makefile | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -Wall -Wextra -UNDEBUG -I. $$($(PKG_CONFIG) --cflags fftw3) \
		$(LDFLAGS) tests/test_analysis.c analysis.c -o $@ $$($(PKG_CONFIG) --libs fftw3) -lm

test: all build/test-analysis
	./build/test-analysis
	@set -e; for test in tests/test_*.js; do $(NODE) "$$test"; done

clean:
	rm -rf build
