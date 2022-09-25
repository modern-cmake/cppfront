cmake_minimum_required(VERSION 3.23)
project(cppfront-regression-tests LANGUAGES NONE)

enable_testing()

set(CPPFRONT_NO_MAGIC 1)
find_package(cppfront REQUIRED)

# The following tests aren't expected to be buildable C++, even if
# cppfront succeeds.
set(
    codegen_only_tests
    mixed-postfix-expression-custom-formatting
)

function(cppfront_command_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "SOURCE;EXPECTED_CPP;EXPECTED_OUTPUT" "EXTRA_FLAGS")

    cmake_path(GET ARG_SOURCE FILENAME src_filename)
    configure_file("${ARG_SOURCE}" "${src_filename}" COPYONLY)

    cmake_path(GET ARG_SOURCE STEM test_name)
    add_test(
        NAME "${test_name}"
        COMMAND cppfront::cppfront "${src_filename}" ${ARG_EXTRA_FLAGS}
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )

    file(READ "${ARG_EXPECTED_OUTPUT}" expected_output)
    string(REPLACE "\\" "\\\\" expected_output "${expected_output}")
    string(REPLACE "(" "\\(" expected_output "${expected_output}")
    string(REPLACE ")" "\\)" expected_output "${expected_output}")
    string(REPLACE "[" "\\[" expected_output "${expected_output}")
    string(REPLACE "]" "\\]" expected_output "${expected_output}")

    set_tests_properties("${test_name}" PROPERTIES PASS_REGULAR_EXPRESSION "^${expected_output}$")

    if (ARG_EXPECTED_CPP)
        cmake_path(REPLACE_EXTENSION src_filename "cpp" OUTPUT_VARIABLE gen_cpp_src)

        add_test(
            NAME "${test_name}/check"
            COMMAND "${CMAKE_COMMAND}" -E compare_files "${gen_cpp_src}" "${ARG_EXPECTED_CPP}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        )

        set_tests_properties("${test_name}" PROPERTIES FIXTURES_SETUP "${test_name}/check")
        set_tests_properties("${test_name}/check" PROPERTIES FIXTURES_REQUIRED "${test_name}/check")
    endif ()
endfunction()

function(cppfront_cmake_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "SOURCE" "EXTRA_FLAGS")

    cmake_path(GET ARG_SOURCE STEM stem)
    if (stem IN_LIST codegen_only_tests)
        return()
    endif ()

    set(test_dir "${CMAKE_CURRENT_BINARY_DIR}/${stem}")
    set(test_name "${stem}/build")

    configure_file("${ARG_SOURCE}" "${test_dir}/${stem}.cpp2" COPYONLY)
    configure_file("cmake/CMakeLists.txt.in" "${test_dir}/CMakeLists.txt" @ONLY)

    add_test(
        NAME "${test_name}"
        COMMAND
        "${CMAKE_CTEST_COMMAND}"
        --build-and-test "${test_dir}" "${test_dir}/build"
        --build-generator "${CMAKE_GENERATOR}"
        -C Release
        --build-options
        "-DCMAKE_BUILD_TYPE=Release"
        "-Dcppfront_DIR=${cppfront_DIR}"
        "-Dcppfront-exe_DIR=${cppfront-exe_DIR}"
        "-DCPPFRONT_FLAGS=${ARG_EXTRA_FLAGS}"
    )
endfunction()

function(insert_dir pathvar dir)
    cmake_path(GET "${pathvar}" FILENAME filename)
    cmake_path(GET "${pathvar}" PARENT_PATH base)
    cmake_path(APPEND base "${dir}" "${filename}" OUTPUT_VARIABLE "${pathvar}")
    set("${pathvar}" "${${pathvar}}" PARENT_SCOPE)
endfunction()

function(cppfront_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "GROUP" "EXTRA_FLAGS")

    # Naughty, but needed for quick submodule updates... :(
    file(
        GLOB sources CONFIGURE_DEPENDS 
	"${CMAKE_CURRENT_SOURCE_DIR}/../cppfront/regression-tests/${ARG_GROUP}-*.cpp2"
    )

    foreach (src IN LISTS sources)
        cmake_path(REPLACE_EXTENSION src "cpp" OUTPUT_VARIABLE expected_cpp)
	insert_dir(expected_cpp "test-results")

	set(expected_output "${src}-output")
	insert_dir(expected_output "test-results")

	if (EXISTS "${expected_cpp}")
	    cppfront_cmake_tests(
                SOURCE ${src}
                EXTRA_FLAGS ${ARG_EXTRA_FLAGS}
            )
            cppfront_command_tests(
                SOURCE ${src}
		EXPECTED_OUTPUT ${expected_output}
		EXPECTED_CPP ${expected_cpp}
                EXTRA_FLAGS ${ARG_EXTRA_FLAGS}
            )
        else ()
            cppfront_command_tests(
                SOURCE ${src}
		EXPECTED_OUTPUT ${expected_output}
                EXTRA_FLAGS ${ARG_EXTRA_FLAGS}
            )
        endif ()
    endforeach ()
endfunction()

cppfront_tests(GROUP mixed)
cppfront_tests(GROUP pure2 EXTRA_FLAGS -p)
