cmake_minimum_required(VERSION 3.23)
project(cppfront-regression-tests LANGUAGES NONE)

enable_testing()

set(CPPFRONT_NO_MAGIC 1)
find_package(cppfront REQUIRED)

set(REGRESSION_TESTS_DIR "${CMAKE_CURRENT_LIST_DIR}/../cppfront/regression-tests")

configure_file("cmake/UpdateTestResults.cmake.in" "UpdateTestResults.cmake" @ONLY)
add_custom_target(cppfront_update_test_results)

function(cppfront_command_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "SOURCE;EXPECTED_FILE" "EXTRA_FLAGS")

    configure_file("${REGRESSION_TESTS_DIR}/${ARG_SOURCE}" "${ARG_SOURCE}" COPYONLY)

    cmake_path(GET ARG_SOURCE STEM test_name)

    file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${test_name}")
    add_custom_target(
        "${test_name}"
        COMMAND
        "${CMAKE_COMMAND}"
        -D "TEST_NAME=${test_name}"
        -D "EXTRA_FLAGS=${ARG_EXTRA_FLAGS}"
        -P "UpdateTestResults.cmake"
    )
    add_dependencies(cppfront_update_test_results "${test_name}")

    add_test(
        NAME "codegen/${test_name}"
        COMMAND cppfront::cppfront "${ARG_SOURCE}" ${ARG_EXTRA_FLAGS}
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )

    set(expected_output_file "${REGRESSION_TESTS_DIR}/test-results/${ARG_SOURCE}.output")
    if (EXISTS "${expected_output_file}")
        file(READ "${expected_output_file}" expected_output)
        string(REPLACE "\\" "\\\\" expected_output "${expected_output}")
        string(REPLACE "(" "\\(" expected_output "${expected_output}")
        string(REPLACE ")" "\\)" expected_output "${expected_output}")
        string(REPLACE "[" "\\[" expected_output "${expected_output}")
        string(REPLACE "]" "\\]" expected_output "${expected_output}")
        string(REPLACE "." "\\." expected_output "${expected_output}")
        string(REPLACE "+" "\\+" expected_output "${expected_output}")
        string(REPLACE "*" "\\*" expected_output "${expected_output}")
        string(REPLACE "?" "\\?" expected_output "${expected_output}")

        set_tests_properties(
            "codegen/${test_name}"
            PROPERTIES
            FIXTURES_SETUP "codegen/${test_name}"
            PASS_REGULAR_EXPRESSION "^${expected_output}$"
        )
    endif ()

    if (ARG_EXPECTED_FILE)
        cmake_path(REPLACE_EXTENSION ARG_SOURCE "cpp" OUTPUT_VARIABLE gen_cpp_src)

        add_test(
            NAME "codegen/check/${test_name}"
            COMMAND "${CMAKE_COMMAND}" -E compare_files "${gen_cpp_src}" "${ARG_EXPECTED_FILE}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        )

        set_tests_properties("codegen/check/${test_name}" PROPERTIES FIXTURES_REQUIRED "codegen/${test_name}")

        cppfront_build_tests(
            SOURCE ${ARG_SOURCE}
            EXTRA_FLAGS ${ARG_EXTRA_FLAGS}
        )
    endif ()
endfunction()

function(cppfront_build_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "SOURCE" "EXTRA_FLAGS")

    # The following tests aren't expected to be buildable C++, even if
    # cppfront succeeds.
    set(
        codegen_only_tests
        mixed-postfix-expression-custom-formatting
    )

    cmake_path(GET ARG_SOURCE STEM stem)
    if (stem IN_LIST codegen_only_tests)
        return()
    endif ()

    set(test_dir "${CMAKE_CURRENT_BINARY_DIR}/${stem}")
    set(test_name "build/${stem}")

    configure_file("${REGRESSION_TESTS_DIR}/${ARG_SOURCE}" "${test_dir}/${ARG_SOURCE}" COPYONLY)
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

function(cppfront_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "GROUP" "EXTRA_FLAGS")

    # Naughty, but needed for quick rebasing... :(
    file(
        GLOB sources
        RELATIVE "${REGRESSION_TESTS_DIR}"
        CONFIGURE_DEPENDS "${REGRESSION_TESTS_DIR}/${ARG_GROUP}-*.cpp2"
    )

    foreach (src IN LISTS sources)
        cmake_path(REPLACE_EXTENSION src "cpp" OUTPUT_VARIABLE expected_file)
        set(expected_file "${REGRESSION_TESTS_DIR}/test-results/${expected_file}")

        if (NOT EXISTS "${expected_file}")
            set(expected_file "")
        endif ()

        cppfront_command_tests(
            SOURCE ${src}
            EXPECTED_FILE ${expected_file}
            EXTRA_FLAGS ${ARG_EXTRA_FLAGS}
        )
    endforeach ()
endfunction()

cppfront_tests(GROUP mixed)
cppfront_tests(GROUP pure2 EXTRA_FLAGS -p)
