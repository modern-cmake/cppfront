function(_convert_path_relative_to_source_dir file out)
  cmake_path(IS_RELATIVE file is_relative)

  if(is_relative)
    cmake_path(ABSOLUTE_PATH file BASE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} NORMALIZE)
  endif()

  cmake_path(RELATIVE_PATH file BASE_DIRECTORY ${CMAKE_SOURCE_DIR})

  set("${out}" "${file}" PARENT_SCOPE)
endfunction()

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
  cmake_path(ABSOLUTE_PATH absolute_binary BASE_DIRECTORY "${CMAKE_BINARY_DIR}/${parent_path}/_cppfront/" NORMALIZE)
  set("${out_absolute_binary_file}" "${absolute_binary}" PARENT_SCOPE)

  cmake_path(ABSOLUTE_PATH relative_source BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE absolute_source)
  set("${out_absolute_source_file}" "${absolute_source}" PARENT_SCOPE)
endfunction()

function(_cppfront_generate_file file out)
  _convert_path_relative_to_source_dir("${file}" source_file)

  _parse_relative_source("${source_file}" absolute_source_file absolute_binary_file)

  add_custom_command(
    OUTPUT "${absolute_binary_file}"
    COMMAND cppfront::cppfront "${absolute_source_file}" -o "${absolute_binary_file}" ${CPPFRONT_FLAGS}
    DEPENDS cppfront::cppfront "${absolute_source_file}"
    COMMENT "Generating the corresponding cpp file"
    VERBATIM
  )

  set("${out}" "${absolute_binary_file}" PARENT_SCOPE)
endfunction()

function(cppfront_generate_files out)
  set(files "")

  foreach(file IN LISTS ARGN)
    _cppfront_generate_file(${file} "output_file")
    list(APPEND files "${output_file}")
  endforeach()

  set("${out}" "${files}" PARENT_SCOPE)
endfunction()

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
    target_sources("${target}" PRIVATE ${cpp1sources})
  endif()
endfunction()

function(cppfront_enable_targets)
  foreach(target IN LISTS ARGN)
    _cppfront_enable_target("${target}")
  endforeach()
endfunction()

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

function(cppfront_enable_directories)
  foreach(directory IN LISTS ARGN)
    _cppfront_enable_directory("${directory}")
  endforeach()
endfunction()

if(NOT CPPFRONT_NO_MAGIC)
  cppfront_enable_directories(${CMAKE_CURRENT_SOURCE_DIR})
endif()
