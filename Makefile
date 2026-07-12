APP := GLBQuickLook
DERIVED := build
FIXTURE_BASE := https://github.com/KhronosGroup/glTF-Sample-Assets/raw/main/Models

GLTFKIT2_VERSION := 0.5.15
GLTFKIT2_URL := https://github.com/warrenm/GLTFKit2/releases/download/$(GLTFKIT2_VERSION)/GLTFKit2.xcframework.zip
GLTFKIT2_SHA256 := 9d0c338282acce4986494aa02a5f1495278f56c60d43f31453fefea6875b4928

.PHONY: gen build install test ql reset fixtures vendor release release-check

vendor/GLTFKit2.xcframework:
	mkdir -p vendor
	curl -L --max-time 300 -o vendor/GLTFKit2.xcframework.zip $(GLTFKIT2_URL)
	echo "$(GLTFKIT2_SHA256)  vendor/GLTFKit2.xcframework.zip" | shasum -a 256 -c -
	cd vendor && unzip -oq GLTFKit2.xcframework.zip && rm GLTFKit2.xcframework.zip

vendor: vendor/GLTFKit2.xcframework

gen: vendor
	xcodegen generate

build: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration Release \
		-derivedDataPath $(DERIVED) build

LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

install: build
	-pkill -x $(APP)
	-$(LSREGISTER) -u $(DERIVED)/Build/Products/Release/$(APP).app
	rm -rf /Applications/$(APP).app
	ditto $(DERIVED)/Build/Products/Release/$(APP).app /Applications/$(APP).app
	$(LSREGISTER) -f -R -trusted /Applications/$(APP).app
	open /Applications/$(APP).app

test: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration Debug \
		-derivedDataPath $(DERIVED) test

ql:
	qlmanage -p fixtures/Box.glb

reset:
	qlmanage -r && qlmanage -r cache

release:
	bash scripts/release.sh

release-check:
	bash scripts/release.sh check

fixtures:
	mkdir -p fixtures
	curl -L --max-time 120 -o fixtures/Box.glb           $(FIXTURE_BASE)/Box/glTF-Binary/Box.glb
	curl -L --max-time 120 -o fixtures/Duck.glb          $(FIXTURE_BASE)/Duck/glTF-Binary/Duck.glb
	curl -L --max-time 120 -o fixtures/DamagedHelmet.glb $(FIXTURE_BASE)/DamagedHelmet/glTF-Binary/DamagedHelmet.glb
	curl -L --max-time 120 -o fixtures/Fox.glb           $(FIXTURE_BASE)/Fox/glTF-Binary/Fox.glb
	printf 'this is not a glb' > fixtures/broken.glb
