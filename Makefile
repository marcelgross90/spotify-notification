.PHONY: build test validate-localizations app clean

build:
	swift build --scratch-path .build

test: validate-localizations
	swift test --scratch-path .build

validate-localizations:
	./scripts/validate-localizations.sh

app:
	./scripts/package-app.sh release

clean:
	swift package --scratch-path .build clean
	rm -rf .build/xcode dist
