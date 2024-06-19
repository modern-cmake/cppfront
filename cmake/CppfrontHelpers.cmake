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
    if (src MATCHES [[.*\.h2]])
        set(ext ".h")
    else ()
        set(ext ".cpp")
    endif ()
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
        set(need_cpp2util 0)

        # Classic SOURCES property

        get_target_property(type "${tgt}" TYPE)
        if (type STREQUAL "INTERFACE_LIBRARY")
            set(visibility "INTERFACE")
        else ()
            set(visibility "PRIVATE")
        endif ()

        get_target_property(sources "${tgt}" SOURCES)
        list(FILTER sources INCLUDE REGEX "\\.(cpp|h)2$")
        if (sources)
            set(need_cpp2util 1)
            cppfront_generate_cpp(cpp1sources ${sources})
            target_sources("${tgt}" ${visibility} ${cpp1sources})
            set_source_files_properties(${cpp1sources} PROPERTIES CXX_SCAN_FOR_MODULES ON)
        endif ()

        # New CXX_MODULES file sets

        get_target_property(interface_modules "${tgt}" INTERFACE_CXX_MODULE_SETS)
        get_target_property(private_modules "${tgt}" CXX_MODULE_SETS)

        set(all_modules ${interface_modules} ${private_modules})
        list(REMOVE_DUPLICATES all_modules)

        foreach (module_set IN LISTS all_modules)
            get_target_property(sources "${tgt}" "CXX_MODULE_SET_${module_set}")
            list(FILTER sources INCLUDE REGEX "\\.(cpp|h)2$")

            if (sources)
                set(need_cpp2util 1)
                cppfront_generate_cpp(cpp1sources ${sources})

                get_target_property(orig "${tgt}" "CXX_MODULE_SET_${module_set}")
                list(REMOVE_ITEM orig ${sources})
                list(APPEND orig ${cpp1sources})

                set_target_properties("${tgt}" PROPERTIES "CXX_MODULE_SET_${module_set}" "${orig}")
                set_property(TARGET "${tgt}" APPEND PROPERTY "CXX_MODULE_DIRS_${module_set}" "${CMAKE_BINARY_DIR}/_cppfront")
            endif ()
        endforeach ()

        if (need_cpp2util)
            target_link_libraries("${tgt}" ${visibility} cppfront::cpp2util)
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
