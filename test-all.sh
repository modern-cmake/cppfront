#!/bin/bash

set -eo pipefail

export CMAKE_GENERATOR="Ninja"
export CMAKE_BUILD_TYPE="Release"
export CMAKE_PREFIX_PATH="$PWD/_local"
export CMAKE_INSTALL_PREFIX="$PWD/_local"

cmake -S . -B build/cppfront
cmake --build build/cppfront --target install

cmake -S example -B build/example
cmake --build build/example --config Release
./build/example/main
cmake -E cat xyzzy

cmake -S regression-tests -B build/regression-tests
cmake --build build/regression-tests
ctest --test-dir build/regression-tests --output-on-failure -j "$(nproc)"
