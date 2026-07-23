#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
CHECK_BINARY="${PROJECT_DIR}/.build/parser-checks"
TEST_EPUB="${PROJECT_DIR}/.build/voicepage-test.epub"

cd "${PROJECT_DIR}"
mkdir -p .build
rm -f "${TEST_EPUB}"
(
    cd Checks/EPUBFixture
    /usr/bin/zip -X0 "${TEST_EPUB}" mimetype >/dev/null
    /usr/bin/zip -Xr9 "${TEST_EPUB}" META-INF OEBPS >/dev/null
)
swiftc \
    Sources/VoicePage/Models.swift \
    Sources/VoicePage/ReadingLibraryStore.swift \
    Sources/VoicePage/ReadingPaginator.swift \
    Sources/VoicePage/DocumentLoader.swift \
    Checks/ParserChecks.swift \
    -o "${CHECK_BINARY}"
VOICEPAGE_TEST_EPUB="${TEST_EPUB}" "${CHECK_BINARY}"
