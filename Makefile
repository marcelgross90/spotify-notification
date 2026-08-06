.PHONY: build test app clean

build:
	swift build --scratch-path .build

test:
	swift test --scratch-path .build

app:
	./scripts/package-app.sh release

clean:
	swift package --scratch-path .build clean
	rm -rf dist
