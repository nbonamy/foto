
release:
	flutter build macos

install deploy: release
	sudo cp -rf ./build/macos/Build/Products/Release/foto.app /Applications
