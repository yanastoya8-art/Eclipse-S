#!/bin/bash

set -e

cd "$(dirname "$0")"

WORKING_LOCATION="$(pwd)"
PROJECT_NAME="Eclipse"
APPLICATION_NAME="Eclipse"

PLATFORM=${1:-ios}
case "$PLATFORM" in
    ios|iOS)
        PLATFORM="ios"
        SCHEME="$PROJECT_NAME"
        SDK="iphoneos"
        XCODE_DESTINATION="generic/platform=iOS"
        ;;
    *)
        echo "Error: Eclipse builds are iPhone/iPad only."
        echo "Usage: $0 [ios]"
        exit 1
        ;;
esac

mkdir -p build

cd build

BUILD_INVOCATION_DIR=$(mktemp -d "$WORKING_LOCATION/build/.ipa-$PLATFORM.XXXXXX")
trap 'rm -rf "$BUILD_INVOCATION_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
DERIVED_DATA_PATH="$BUILD_INVOCATION_DIR/DerivedData"
SOURCE_PACKAGES_DIR="$BUILD_INVOCATION_DIR/SourcePackages"

XCODE_CONTAINER=(-project "$WORKING_LOCATION/$PROJECT_NAME.xcodeproj")

MPVKIT_CHECKOUT="$WORKING_LOCATION/../MPVKit"
MPVKIT_LOCAL_RUNTIME="$MPVKIT_CHECKOUT/dist/release"
if [ -d "$MPVKIT_LOCAL_RUNTIME/Libmpv.xcframework" ] \
    || [ -d "$MPVKIT_LOCAL_RUNTIME/xcframework/Libmpv.xcframework" ]; then
    # MPVKit's manifest can auto-discover this directory, but SwiftPM's manifest
    # cache does not observe artifact contents. Bind resolution and archive to
    # the same reviewed local runtime that the native-export audit examines.
    export MPVKIT_LOCAL_ARTIFACTS_DIR="dist/release"
fi

xcodebuild -resolvePackageDependencies \
    "${XCODE_CONTAINER[@]}" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
    -skipPackagePluginValidation \
    -skipMacroValidation

LIBMPV_SLICE='*Libmpv.xcframework/ios-arm64/Libmpv.framework/Libmpv'

LIBMPV_BINARY=""
for ARTIFACT_ROOT in "$MPVKIT_CHECKOUT/dist/release" "$SOURCE_PACKAGES_DIR/artifacts"; do
    if [ ! -d "$ARTIFACT_ROOT" ]; then
        continue
    fi
    LIBMPV_BINARY="$(find "$ARTIFACT_ROOT" -path "$LIBMPV_SLICE" -type f -print -quit)"
    if [ -n "$LIBMPV_BINARY" ]; then
        break
    fi
done

if [ -z "$LIBMPV_BINARY" ]; then
    echo "Error: The resolved MPVKit runtime does not contain the $PLATFORM Libmpv device slice."
    exit 1
fi

LIBMPV_SYMBOLS="$BUILD_INVOCATION_DIR/libmpv-symbols.txt"
xcrun nm -gU "$LIBMPV_BINARY" > "$LIBMPV_SYMBOLS" 2>/dev/null || true
for SYMBOL in \
    mpv_apple_pip_api_version \
    mpv_apple_pip_get_capabilities \
    mpv_apple_pip_set_callback \
    mpv_apple_pip_set_mode \
    mpv_apple_pip_submit_target \
    mpv_apple_pip_disable_and_drain \
    mpv_apple_audiounit_recovery_count
do
    if ! grep -Eq "[[:space:]]_?${SYMBOL}$" "$LIBMPV_SYMBOLS"; then
        echo "Error: The resolved $PLATFORM Libmpv artifact is missing required native export '$SYMBOL'."
        echo "Rebuild the reviewed private MPVKit runtime in ../MPVKit/dist/release before packaging."
        exit 1
    fi
done
rm -f "$LIBMPV_SYMBOLS"

# Create archive (required for proper IPA structure)
ARCHIVE_PATH="$BUILD_INVOCATION_DIR/$APPLICATION_NAME.xcarchive"
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
    "${XCODE_CONTAINER[@]}" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "$XCODE_DESTINATION" \
    -sdk "$SDK" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
    -disableAutomaticPackageResolution \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) ECLIPSE_UNSIGNED_BUILD' \
    ENABLE_USER_SCRIPT_SANDBOXING=NO

# Verify archive was created
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "Error: Archive failed to create at $ARCHIVE_PATH"
    exit 1
fi

# Extract app from archive (correct path: Products/Applications)
APP_PATH="$ARCHIVE_PATH/Products/Applications/$PROJECT_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name "*.app" 2>/dev/null | head -n 1)"
    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        echo "Error: App not found at $ARCHIVE_PATH/Products/Applications"
        echo "Contents of archive:"
        find "$ARCHIVE_PATH" -type d -name "*.app" 2>/dev/null || echo "No app bundles found"
        exit 1
    fi
fi

"$WORKING_LOCATION/scripts/validate-ios-privacy-manifest.sh" "$APP_PATH"

# Create Payload directory and copy app
cd "$BUILD_INVOCATION_DIR"
mkdir Payload
cp -r "$APP_PATH" "Payload/$APPLICATION_NAME.app"

# Strip binary to reduce size
if [ -f "Payload/$APPLICATION_NAME.app/$PROJECT_NAME" ]; then
    strip "Payload/$APPLICATION_NAME.app/$PROJECT_NAME" 2>/dev/null || true
elif [ -f "Payload/$APPLICATION_NAME.app/$APPLICATION_NAME" ]; then
    strip "Payload/$APPLICATION_NAME.app/$APPLICATION_NAME" 2>/dev/null || true
fi

# Remove code signature
rm -rf "Payload/$APPLICATION_NAME.app/_CodeSignature" 2>/dev/null || true
rm -f "Payload/$APPLICATION_NAME.app/embedded.mobileprovision" 2>/dev/null || true

# Create IPA (preserve symlinks with -y, recursive with -r)
zip -qry "$APPLICATION_NAME.ipa" Payload
mv -f "$APPLICATION_NAME.ipa" "$WORKING_LOCATION/build/$APPLICATION_NAME.ipa"

# Cleanup
rm -rf Payload
rm -rf "$ARCHIVE_PATH"
