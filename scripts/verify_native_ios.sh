#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/verify_native_ios.sh [options]

Runs deterministic native iOS verification from the repository root:
  1. PoseCore package tests
  2. SquatAnalysis package tests
  3. TrainerCore package tests
  4. TrainerRuntime package tests
  5. TrainerApp host-architecture Simulator workspace build
  6. PoseBakeoff host-architecture Simulator workspace build

Options:
  --packages-only       Run only the four Swift package suites.
  --trainer-app-only    Run the package suites and TrainerApp build only.
  --keep-build-artifacts
                        Keep isolated test/build artifacts and print their location.
  -h, --help            Show this help.

Environment:
  NATIVE_VERIFY_SCRATCH_ROOT
                        Existing writable directory for temporary build data.
                        Uses TMPDIR when set; otherwise /private/tmp. The
                        selected filesystem must have sufficient free space;
                        this harness does not enforce a storage quota.
  NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX
                        Set to 1 only when this process is already contained by
                        a trusted outer sandbox. Unset by default.

This harness verifies deterministic package behavior and compilation. It does
not replace physical-device checks or prove real-world pose accuracy.
EOF
}

mode="full"
selected_mode=""
keep_build_artifacts=0

select_mode() {
    local requested_mode="$1"
    local requested_option="$2"
    if [[ -n "$selected_mode" && "$selected_mode" != "$requested_mode" ]]; then
        echo "Conflicting verification modes: $requested_option cannot be combined with the previously selected mode." >&2
        usage >&2
        exit 2
    fi
    mode="$requested_mode"
    selected_mode="$requested_mode"
}

while (($# > 0)); do
    case "$1" in
    --packages-only)
        select_mode "packages" "$1"
        ;;
    --trainer-app-only)
        select_mode "trainer_app" "$1"
        ;;
    --keep-build-artifacts)
        keep_build_artifacts=1
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
workspace="$repo_root/ios/SquatTrainer.xcworkspace"

if [[ ! -d "$workspace" ]]; then
    echo "Missing workspace: $workspace" >&2
    exit 1
fi

disable_swiftpm_sandbox=0
case "${NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX:-}" in
"")
    ;;
1)
    disable_swiftpm_sandbox=1
    ;;
*)
    echo "NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX must be 1 when set." >&2
    exit 2
    ;;
esac

scratch_base_input="${NATIVE_VERIFY_SCRATCH_ROOT:-${TMPDIR:-/private/tmp}}"
if [[ -z "$scratch_base_input" || ! -d "$scratch_base_input" ]]; then
    echo "Verification scratch root must be an existing directory." >&2
    exit 1
fi
if ! scratch_base="$(cd "$scratch_base_input" 2>/dev/null && pwd -P)"; then
    echo "Could not canonicalize verification scratch root: $scratch_base_input" >&2
    exit 1
fi
if [[ "$scratch_base" == "/" || ! -w "$scratch_base" ]]; then
    echo "Verification scratch root must resolve to a writable non-root directory." >&2
    exit 1
fi

scratch_dir="$(mktemp -d "$scratch_base/squat-native-verification.XXXXXX")"
derived_data_path="$scratch_dir/DerivedData"
swift_cache_path="$scratch_dir/SwiftPMCache"
swift_config_path="$scratch_dir/SwiftPMConfig"
swift_security_path="$scratch_dir/SwiftPMSecurity"
swift_build_root="$scratch_dir/SwiftBuild"
export CLANG_MODULE_CACHE_PATH="$scratch_dir/ClangModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch_dir/SwiftPMModuleCache"

cleanup() {
    if ((keep_build_artifacts == 1)); then
        echo "Verification artifacts kept at: $scratch_dir"
        return 0
    fi

    case "$scratch_dir" in
    "$scratch_base"/squat-native-verification.??????)
        if ! rm -rf -- "$scratch_dir"; then
            echo "Failed to remove verification scratch directory: $scratch_dir" >&2
            return 1
        fi
        ;;
    *)
        echo "Refusing to remove unexpected scratch path: $scratch_dir" >&2
        return 1
        ;;
    esac
    return 0
}

cleanup_on_exit() {
    local exit_status="$?"
    trap - EXIT
    if ! cleanup; then
        if ((exit_status == 0)); then
            exit_status=1
        fi
    fi
    exit "$exit_status"
}

finish_successfully() {
    local success_message="$1"
    trap - EXIT
    if ! cleanup; then
        echo "FAIL: verification completed, but cleanup did not succeed." >&2
        exit 1
    fi
    echo
    echo "$success_message"
}
trap cleanup_on_exit EXIT

package_names=(
    "PoseCore"
    "SquatAnalysis"
    "TrainerCore"
    "TrainerRuntime"
)

echo "Native iOS verification"
echo "Repository: $repo_root"
echo "Mode: $mode"
swift --version
if ((disable_swiftpm_sandbox == 1)); then
    echo "SwiftPM sandbox: disabled by explicit NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX=1 opt-in"
fi

for package_name in "${package_names[@]}"; do
    echo
    echo "==> Testing $package_name"
    swift_test_args=(
        "test"
        "--package-path" "$repo_root/ios/Packages/$package_name"
        "--cache-path" "$swift_cache_path"
        "--config-path" "$swift_config_path"
        "--security-path" "$swift_security_path"
        "--scratch-path" "$swift_build_root/$package_name"
    )
    if ((disable_swiftpm_sandbox == 1)); then
        swift_test_args+=("--disable-sandbox")
    fi
    swift "${swift_test_args[@]}"
done

if [[ "$mode" == "packages" ]]; then
    finish_successfully "PASS: all four Swift package suites completed."
    exit 0
fi

if [[ ! -d "$repo_root/ios/Pods" ]]; then
    echo "Missing ios/Pods. Install the locked CocoaPods dependencies before building." >&2
    exit 1
fi

host_arch="$(uname -m)"
case "$host_arch" in
arm64 | x86_64)
    ;;
*)
    echo "Unsupported Simulator build architecture: $host_arch" >&2
    exit 1
    ;;
esac

echo
xcodebuild -version
echo "Isolated DerivedData: $derived_data_path"
echo "Simulator architecture: $host_arch"

build_scheme() {
    local scheme="$1"
    echo
    echo "==> Building $scheme through SquatTrainer.xcworkspace"
    xcodebuild \
        -workspace "$workspace" \
        -scheme "$scheme" \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$derived_data_path" \
        ARCHS="$host_arch" \
        ONLY_ACTIVE_ARCH=YES \
        CODE_SIGNING_ALLOWED=NO \
        COMPILER_INDEX_STORE_ENABLE=NO \
        -quiet \
        build
}

build_scheme "TrainerApp"
if [[ "$mode" == "full" ]]; then
    build_scheme "PoseBakeoff"
fi

if [[ "$mode" == "full" ]]; then
    finish_successfully "PASS: all package suites and both workspace Simulator builds completed."
else
    finish_successfully "PASS: all package suites and the TrainerApp workspace Simulator build completed."
fi
