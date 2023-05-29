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
    if(src MATCHES [[.*\.h2]])
      set(ext ".h")
    else()
      set(ext ".cpp")
    endif()
    set(out_file "${CMAKE_BINARY_DIR}/_cppfront/${basename}${ext}")

    add_custom_command(
        OUTPUT "${out_file}"
        COMMAND cppfront::cppfront "${src}" -o "${out_file}" ${CPPFRONT_FLAGS}
        DEPENDS cppfront::cppfront "${src}"
        VERBATIM
    )

    set_property(GLOBAL PROPERTY "cppfront/out_file/${src_hash}" "${out_file}")
    set("${out}" "${out_file}" PARENT_SCOPE)
endfunction()

function(cppfront_generate_cpp srcs)
    set(cpp2srcs "")
    foreach (src IN LISTS ARGN)
        _cppfront_generate_source("${src}" cpp2)
        list(APPEND cpp2srcs "${cpp2}")
    endforeach ()
    set("${srcs}" "${cpp2srcs}" PARENT_SCOPE)
endfunction()

function(cppfront_enable)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "" "TARGETS")

    foreach (tgt IN LISTS ARG_TARGETS)
        get_property(sources TARGET "${tgt}" PROPERTY SOURCES)
        list(FILTER sources INCLUDE REGEX "\\.(cpp|h)2$")

        if (sources)
            target_link_libraries("${tgt}" PRIVATE cppfront::cpp2util)
            cppfront_generate_cpp(cpp1sources ${sources})
            target_sources("${tgt}" PRIVATE ${cpp1sources})
        endif ()
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
