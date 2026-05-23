#!/usr/bin/env bash
#
# Install the dhq CLI at the version pinned by DHQ_VERSION.
# Detects RUNNER_OS/RUNNER_ARCH, downloads the matching release archive from
# github.com/deployhq/deployhq-cli, verifies its SHA-256 against the release's
# checksums.txt, extracts to a per-version cache directory, and appends the
# directory to $GITHUB_PATH so the next step can call `dhq` directly.
set -euo pipefail

: "${DHQ_VERSION:?DHQ_VERSION must be set}"
VERSION="${DHQ_VERSION#v}"

REPO="deployhq/deployhq-cli"

case "${RUNNER_OS:-$(uname -s)}" in
    Linux|linux)               OS="linux";   EXT="tar.gz"; BIN_NAME="dhq" ;;
    macOS|Darwin|darwin)       OS="darwin";  EXT="tar.gz"; BIN_NAME="dhq" ;;
    Windows|MINGW*|MSYS*|CYGWIN*) OS="windows"; EXT="zip";  BIN_NAME="dhq.exe" ;;
    *) echo "Unsupported OS: ${RUNNER_OS:-$(uname -s)}" >&2; exit 1 ;;
esac

case "${RUNNER_ARCH:-$(uname -m)}" in
    X64|x86_64|amd64)       ARCH="amd64" ;;
    ARM64|arm64|aarch64)    ARCH="arm64" ;;
    *) echo "Unsupported arch: ${RUNNER_ARCH:-$(uname -m)}" >&2; exit 1 ;;
esac

CACHE_ROOT="${RUNNER_TOOL_CACHE:-${GITHUB_ACTION_PATH}/.cache}"
INSTALL_DIR="${CACHE_ROOT}/dhq/${VERSION}/${OS}_${ARCH}"
mkdir -p "$INSTALL_DIR"

if [[ -x "${INSTALL_DIR}/${BIN_NAME}" ]]; then
    echo "dhq v${VERSION} already cached at ${INSTALL_DIR}"
else
    ARCHIVE="dhq_${VERSION}_${OS}_${ARCH}.${EXT}"
    BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    echo "Downloading ${BASE_URL}/${ARCHIVE}"
    curl -fsSL "${BASE_URL}/${ARCHIVE}" -o "${TMP}/${ARCHIVE}"

    echo "Downloading checksums.txt"
    curl -fsSL "${BASE_URL}/checksums.txt" -o "${TMP}/checksums.txt"

    EXPECTED="$(awk -v f="${ARCHIVE}" '$2 == f {print $1}' "${TMP}/checksums.txt")"
    if [[ -z "$EXPECTED" ]]; then
        echo "No checksum entry for ${ARCHIVE} in checksums.txt" >&2
        exit 1
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL="$(sha256sum "${TMP}/${ARCHIVE}" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
        ACTUAL="$(shasum -a 256 "${TMP}/${ARCHIVE}" | awk '{print $1}')"
    else
        echo "Neither sha256sum nor shasum available; cannot verify checksum" >&2
        exit 1
    fi

    if [[ "$EXPECTED" != "$ACTUAL" ]]; then
        echo "Checksum mismatch for ${ARCHIVE}" >&2
        echo "  expected: $EXPECTED" >&2
        echo "  actual:   $ACTUAL" >&2
        exit 1
    fi

    echo "Extracting ${ARCHIVE}"
    if [[ "$EXT" == "zip" ]]; then
        unzip -q "${TMP}/${ARCHIVE}" -d "$TMP"
    else
        tar -xzf "${TMP}/${ARCHIVE}" -C "$TMP"
    fi

    mv "${TMP}/${BIN_NAME}" "${INSTALL_DIR}/${BIN_NAME}"
    chmod +x "${INSTALL_DIR}/${BIN_NAME}"
fi

echo "${INSTALL_DIR}" >> "$GITHUB_PATH"
"${INSTALL_DIR}/${BIN_NAME}" --version
