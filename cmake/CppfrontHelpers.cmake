set(CPPFRONT_FLAGS ""
    CACHE STRING "Global flags to pass to cppfront when generating code")

define_property(
    TARGET PROPERTY CPPFRONT_FLAGS
    BRIEF_DOCS "Target-specific flags to pass to cppfront when generating code"
)

function(_cppfront_unique_name base hash outvar)
    string(LENGTH "${hash}" len)
    foreach (i RANGE 0 "${len}")
        string(SUBSTRING "${hash}" 0 "${i}" uniq)
        if (uniq)
            set(name "${base}-${uniq}")
        else ()
            set(name "${base}")
        endif ()
        get_property(name_used GLOBAL PROPERTY "cppfront/names/${name}" SET)
        if (NOT name_used)
            set("${outvar}" "${name}" PARENT_SCOPE)
            set_property(GLOBAL PROPERTY "cppfront/names/${name}" 1)
            return()
        endif ()
    endforeach ()
    # This should be impossible, unless caching in _cppfront_generate_source
    # is broken.
    message(FATAL_ERROR "Could not compute a unique name using ${base} and ${hash}")
endfunction()

function(_cppfront_generate_source src out)
    cmake_parse_arguments(PARSE_ARGV 2 ARG "" "TARGET" "")

    file(REAL_PATH "${src}" src)
    string(SHA256 src_hash "${src}")

    get_property(out_file GLOBAL PROPERTY "cppfront/out_file/${src_hash}")
    if (out_file)
        set("${out}" "${out_file}" PARENT_SCOPE)
        return()
    endif ()

    cmake_path(GET src STEM original_stem)
    _cppfront_unique_name("${original_stem}" "${src_hash}" basename)

    # assume no SHA256 collisions
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/_cppfront/")
    if (src MATCHES [[.*\.h2]])
        set(ext ".h")
    else ()
        set(ext ".cpp")
    endif ()
    set(out_file "${CMAKE_BINARY_DIR}/_cppfront/${basename}${ext}")

    if (ARG_TARGET)
        set(target_flags "$<TARGET_PROPERTY:${ARG_TARGET},CPPFRONT_FLAGS>")
        set(target_flags "$<TARGET_GENEX_EVAL:${ARG_TARGET},${target_flags}>")
    else ()
        set(target_flags "")
    endif ()

    add_custom_command(
        OUTPUT "${out_file}"
        COMMAND cppfront::cppfront "${src}" -o "${out_file}" ${CPPFRONT_FLAGS} ${target_flags}
        DEPENDS cppfront::cppfront "${src}"
        COMMAND_EXPAND_LISTS
        VERBATIM
    )

    set_property(GLOBAL PROPERTY "cppfront/out_file/${src_hash}" "${out_file}")
    set("${out}" "${out_file}" PARENT_SCOPE)
endfunction()

function(cppfront_target_sources)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET" "SOURCES")

    if (NOT TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET argument assigned non-existent target `${ARG_TARGET}`")
    endif ()

    if (NOT ARG_SOURCES)
        return()
    endif ()

    # Determine flag visibility
    get_target_property(type "${ARG_TARGET}" TYPE)
    if (type STREQUAL "INTERFACE_LIBRARY")
        set(visibility "INTERFACE")
    else ()
        set(visibility "PRIVATE")
    endif ()

    # Check if flags imply we need C++23
    set(flags ${CPPFRONT_FLAGS} "$<TARGET_PROPERTY:${ARG_TARGET},CPPFRONT_FLAGS>")
    set(flags "$<TARGET_GENEX_EVAL:${ARG_TARGET},${flags}>")
    set(flags "$<LIST:TRANSFORM,${flags},REPLACE,^-p.*$,-im>") # -p[ure-cpp2] implies -im[port-std]
    set(flags "$<LIST:FILTER,${flags},INCLUDE,^-(im|in)>") # -im[port-std] can be overridden by -in[clude-std]
    set(flags "$<LIST:TRANSFORM,${flags},REPLACE,^-(im|in).*$,-\\1>") # normalize to short flag
    set(flags "$<LIST:SUBLIST,$<LIST:REVERSE,${flags}>,0,1>") # get the last flag or none
    target_compile_features("${ARG_TARGET}" ${visibility} "$<$<STREQUAL:${flags},-im>:cxx_std_23>")

    # Link to utility libraries
    target_link_libraries("${ARG_TARGET}" ${visibility} cppfront::cpp2util)

    set(cpp1sources "")
    foreach (src IN LISTS ARG_SOURCES)
        _cppfront_generate_source("${src}" cpp2 TARGET ${ARG_TARGET})
        list(APPEND cpp1sources "${cpp2}")
    endforeach ()

    set_source_files_properties(${cpp1sources} PROPERTIES CXX_SCAN_FOR_MODULES ON)

    target_sources("${ARG_TARGET}" ${visibility} ${cpp1sources})
endfunction()

function(cppfront_enable)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "" "TARGETS")

    foreach (tgt IN LISTS ARG_TARGETS)
        get_property(sources TARGET "${tgt}" PROPERTY SOURCES)
        list(FILTER sources INCLUDE REGEX "\\.(cpp|h)2$")

        cppfront_target_sources(
            TARGET "${tgt}"
            SOURCES ${sources}
        )
    endforeach ()
endfunction()

if (NOT CPPFRONT_NO_MAGIC)
    function(_cppfront_enable_dir)
        get_property(targets DIRECTORY . PROPERTY BUILDSYSTEM_TARGETS)
        cppfront_enable(TARGETS ${targets})
    endfunction()

    if (NOT _CPPFRONT_MAGIC_DIR)
        set(_CPPFRONT_MAGIC_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    endif ()

    message(VERBOSE "Enabling cppfront for all targets in ${_CPPFRONT_MAGIC_DIR}")
    cmake_language(DEFER DIRECTORY "${_CPPFRONT_MAGIC_DIR}" CALL _cppfront_enable_dir)
endif ()
