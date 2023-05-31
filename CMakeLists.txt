cmake_minimum_required(VERSION 3.23)
project(
    cppfront
    LANGUAGES CXX
    VERSION 0.3.0
)

##
# Project options

include(CMakeDependentOption)

cmake_dependent_option(
    CPPFRONT_NO_SYSTEM "Do not mark cpp2 runtime headers as SYSTEM" OFF
    "NOT PROJECT_IS_TOP_LEVEL" ON
)
mark_as_advanced(CPPFRONT_NO_SYSTEM)

cmake_dependent_option(
    CPPFRONT_INSTALL_RULES "Include install rules for cppfront" "${PROJECT_IS_TOP_LEVEL}"
    "NOT CMAKE_SKIP_INSTALL_RULES" OFF
)
mark_as_advanced(CPPFRONT_INSTALL_RULES)

##
# Target definition for cppfront executable

add_executable(cppfront_cppfront cppfront/source/cppfront.cpp)
add_executable(cppfront::cppfront ALIAS cppfront_cppfront)
set_target_properties(
    cppfront_cppfront
    PROPERTIES
    OUTPUT_NAME cppfront
    EXPORT_NAME cppfront
)
target_compile_features(cppfront_cppfront PRIVATE cxx_std_20)
target_sources(
    cppfront_cppfront
    PRIVATE
    FILE_SET HEADERS
    BASE_DIRS cppfront/source
    FILES cppfront/source/common.h
          cppfront/source/io.h
          cppfront/source/lex.h
          cppfront/source/parse.h
          cppfront/source/reflect.h
          cppfront/source/sema.h
)

##
# Target definition for cpp2util runtime library

add_library(cppfront_cpp2util INTERFACE)
add_library(cppfront::cpp2util ALIAS cppfront_cpp2util)
set_target_properties(cppfront_cpp2util PROPERTIES EXPORT_NAME cpp2util)

target_compile_features(cppfront_cpp2util INTERFACE cxx_std_20)
target_sources(
    cppfront_cpp2util
    INTERFACE
    FILE_SET HEADERS
    BASE_DIRS cppfront/include
    FILES cppfront/include/cpp2util.h
)

if (NOT CPPFRONT_NO_SYSTEM)
    # File sets add this path to INTERFACE_INCLUDE_DIRECTORIES, but it should
    # really be marked as SYSTEM instead when the project is not top-level.
    target_include_directories(
        cppfront_cpp2util
        SYSTEM INTERFACE
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/cppfront/include>"
    )
endif ()

##
# Enable cpp2 autodetection for add_subdirectory users

if (NOT PROJECT_IS_TOP_LEVEL)
    get_directory_property(_CPPFRONT_MAGIC_DIR PARENT_DIRECTORY)
    include(cmake/CppfrontHelpers.cmake)
endif ()

##
# Installation and CMake packaging logic

if (CPPFRONT_INSTALL_RULES)
    include(GNUInstallDirs)
    include(CMakePackageConfigHelpers)

    set(CPPFRONT_INSTALL_CMAKEDIR "${CMAKE_INSTALL_DATADIR}/cmake/cppfront"
        CACHE STRING "Install location for cppfront's platform-independent CMake files")

    mark_as_advanced(CPPFRONT_INSTALL_CMAKEDIR)

    install(
        TARGETS cppfront_cppfront cppfront_cpp2util
        EXPORT cppfront-targets
        FILE_SET HEADERS
        COMPONENT cppfront
    )

    install(
        EXPORT cppfront-targets
        DESTINATION "${CPPFRONT_INSTALL_CMAKEDIR}"
        NAMESPACE cppfront::
        COMPONENT cppfront
    )

    configure_package_config_file(
        cmake/cppfront-config.cmake.in
        cmake/cppfront-config.cmake
        INSTALL_DESTINATION "${CPPFRONT_INSTALL_CMAKEDIR}"
        PATH_VARS CMAKE_INSTALL_BINDIR
    )

    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/cmake/cppfront-config-version.cmake"
        COMPATIBILITY ExactVersion
        ARCH_INDEPENDENT  # to allow finding host executables in cross-builds
    )

    install(
        FILES
        "${CMAKE_CURRENT_BINARY_DIR}/cmake/cppfront-config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake/cppfront-config-version.cmake"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CppfrontHelpers.cmake"
        DESTINATION "${CPPFRONT_INSTALL_CMAKEDIR}"
        COMPONENT cppfront
    )
endif ()
