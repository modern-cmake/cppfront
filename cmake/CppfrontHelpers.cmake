# - Helpers for cppfront usage
# This module provides helpers for cppfront usage
#
# These variables can affects the behaviour of this module:
#
#   CPPFRONT_NO_MAGIC:
#
#      Disabled by default.
#      When disabled, automatically translate `cpp2` to `cpp` for all targets
#      inside the directory where this module is included.
#
#   CPPFRONT_FLAGS:
#
#      a semicolon-separated list of additional flags to pass to `cppfront`.
#
# This function translates `cpp2` to `cpp`:
#
#   cppfront_generate_files(<OUTVAR> <cpp2 files>...)
#
# These function enables `cpp2`-to-`cpp` translation for targets or targets in directories:
#
#   cppfront_enable_targets(<targets>...)
#   cppfront_enable_directories(<directories>...)

include_guard()

function(_convert_path_relative_to_source_dir file out)
  cmake_path(IS_RELATIVE file is_relative)

  if(is_relative)
    cmake_path(ABSOLUTE_PATH file BASE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} NORMALIZE)
  endif()

  cmake_path(RELATIVE_PATH file BASE_DIRECTORY ${CMAKE_SOURCE_DIR})

  set("${out}" "${file}" PARENT_SCOPE)
endfunction()

# Parse the cpp2 `source` that is relative to `CMAKE_SOURCE_DIR`.
function(_parse_relative_source relative_source out_absolute_source_file out_absolute_binary_file)
  cmake_path(GET relative_source PARENT_PATH parent_path)
  cmake_path(GET relative_source FILENAME filename)
  cmake_path(GET filename STEM LAST_ONLY filestem)
  cmake_path(GET relative_source EXTENSION LAST_ONLY extension)

  if(extension MATCHES "\.h2")
    set(extension ".h")
  else()
    set(extension ".cpp")
  endif()

  set(absolute_binary "${filestem}${extension}")
  cmake_path(ABSOLUTE_PATH absolute_binary BASE_DIRECTORY "${CMAKE_BINARY_DIR}/_cppfront/${parent_path}/" NORMALIZE)
  set("${out_absolute_binary_file}" "${absolute_binary}" PARENT_SCOPE)

  cmake_path(ABSOLUTE_PATH relative_source BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE absolute_source)
  set("${out_absolute_source_file}" "${absolute_source}" PARENT_SCOPE)
endfunction()

# Writes to the variable named by `OUTVAR` a absolute path to the generated
# `.cpp` file associated with the `.cpp2` file in the arguments list.
function(_cppfront_generate_file file out)
  _convert_path_relative_to_source_dir("${file}" source_file)

  _parse_relative_source("${source_file}" absolute_source_file absolute_binary_file)

  cmake_path(GET absolute_binary_file PARENT_PATH binary_directory)

  add_custom_command(
    OUTPUT ${absolute_binary_file}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${binary_directory}
    COMMAND cppfront::cppfront "${absolute_source_file}" -o "${absolute_binary_file}" ${CPPFRONT_FLAGS}
    DEPENDS cppfront::cppfront "${absolute_source_file}"
    COMMENT "Generating ${absolute_binary_file}"
    VERBATIM
  )

  set("${out}" "${absolute_binary_file}" PARENT_SCOPE)
endfunction()

# cppfront_generate_files(<OUTVAR> <cpp2 files>...)
#
# Writes to the variable named by `OUTVAR` a list of absolute paths to the
# generated `.cpp` files associated with each `.cpp2` file in the arguments
# list.
function(cppfront_generate_files out)
  set(files "")

  foreach(file IN LISTS ARGN)
    _cppfront_generate_file(${file} "output_file")
    list(APPEND files "${output_file}")
  endforeach()

  set("${out}" "${files}" PARENT_SCOPE)
endfunction()

# Scans the `SOURCES` properties for `<target>` for entries ending in `.cpp2`.
# These are passed to `cppfront_generate_files` and the results are added to the
# target automatically. When `CPPFRONT_NO_MAGIC` is unset (i.e. by default),
# this command runs on all targets in the directory that imported this package
# at the end of processing the directory.
function(_cppfront_enable_target target)
  get_property(cpp2sources TARGET "${target}" PROPERTY SOURCES)
  list(FILTER cpp2sources INCLUDE REGEX "\\.(cpp|h)2$")

  if(cpp2sources)
    target_link_libraries("${target}" PRIVATE cppfront::cpp2util)
    get_property(source_dir TARGET "${target}" PROPERTY SOURCE_DIR)

    set(cpp2_absolute_sources "")
    foreach(source IN LISTS cpp2sources)
      cmake_path(IS_RELATIVE source is_relative)
      if(is_relative)
        cmake_path(ABSOLUTE_PATH source BASE_DIRECTORY ${source_dir} NORMALIZE)
      endif()
      list(APPEND cpp2_absolute_sources ${source})
    endforeach()

    cppfront_generate_files("cpp1sources" ${cpp2_absolute_sources})

    add_custom_target("${target}.parse_cpp2" DEPENDS ${cpp1sources})
    add_dependencies("${target}" "${target}.parse_cpp2")
    target_sources("${target}" PRIVATE "${cpp1sources}")
  endif()
endfunction()

# cppfront_enable_targets(<targets>...)
#
# Scans the `SOURCES` properties for `<targets>` for entries ending in `.cpp2`.
# These are passed to `cppfront_generate_cpp` and the results are added to the
# target automatically. When `CPPFRONT_NO_MAGIC` is unset (i.e. by default),
# this command runs on all targets in the directory that imported this package
# at the end of processing the directory.
function(cppfront_enable_targets)
  foreach(target IN LISTS ARGN)
    _cppfront_enable_target("${target}")
  endforeach()
endfunction()

# Recursively scans all targets inside `<directory>` and calls `cppfront_enable_targets` for them.
function(_cppfront_enable_directory directory)
  function(_cppfront_enable_current_dir directory)
    get_property(targets DIRECTORY "${directory}" PROPERTY BUILDSYSTEM_TARGETS)

    cppfront_enable_targets(${targets})

    get_property(subdirs DIRECTORY "${directory}" PROPERTY SUBDIRECTORIES)

    foreach(subdir IN LISTS subdirs)
      _cppfront_enable_current_dir("${subdir}")
    endforeach()
  endfunction()

  message(STATUS "Enabling cppfront for all targets in ${directory}")
  cmake_language(DEFER DIRECTORY "${directory}" CALL _cppfront_enable_current_dir "${directory}")
endfunction()

# cppfront_enable_directories(<directories>...)
#
# Recursively scans all targets inside `<directories>` and calls
# `cppfront_enable_targets` for them.
function(cppfront_enable_directories)
  foreach(directory IN LISTS ARGN)
    _cppfront_enable_directory("${directory}")
  endforeach()
endfunction()

# If `CPPFRONT_NO_MAGIC` not enabled, automatically translate `cpp2`-to-`cpp`
# for all targets inside the directory where this module is included.
if(NOT CPPFRONT_NO_MAGIC)
  cppfront_enable_directories(${CMAKE_CURRENT_SOURCE_DIR})
endif()
