PREFIX ?= /usr/local/bin
ARCHS ?= x86_64 arm64

build:
	swift build -c release

build-universal: clean
	swift build -c release --arch x86_64
	cp .build/release/html2img .build/html2img-x86_64
	swift build -c release --arch arm64
	cp .build/release/html2img .build/html2img-arm64
	mkdir -p .build/universal
	lipo -create -output .build/universal/html2img .build/html2img-x86_64 .build/html2img-arm64

install: build
	install .build/release/html2img $(PREFIX)/html2img

install-universal: build-universal
	install .build/universal/html2img $(PREFIX)/html2img

uninstall:
	rm -f $(PREFIX)/html2img

test:
	swift test

clean:
	swift package clean

.PHONY: build build-universal install install-universal uninstall test clean
