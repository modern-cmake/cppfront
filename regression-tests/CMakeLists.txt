cmake_minimum_required(VERSION 3.23)
project(cppfront-regression-tests LANGUAGES CXX)

option(CPPFRONT_DEVELOPING "Test results are updated.")

enable_testing()

set(CPPFRONT_NO_MAGIC 1)
find_package(cppfront REQUIRED)

set(REGRESSION_TESTS_DIR "${CMAKE_CURRENT_LIST_DIR}/../cppfront/regression-tests")
set(TEST_RESULTS_DIR "${REGRESSION_TESTS_DIR}/test-results")

# Set `COMPILER_ITEM_NAME`.
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(compiler_id "gcc")
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    set(compiler_id "apple-clang")
else ()
    string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" compiler_id)
endif ()
string(REGEX MATCH "[0-9]+" compiler_major_version "${CMAKE_CXX_COMPILER_VERSION}")
set(COMPILER_ITEM_NAME "${compiler_id}-${compiler_major_version}")

# Setup `BUILD_RESULTS_DIR`.
set(BUILD_RESULTS_DIR "${TEST_RESULTS_DIR}/${COMPILER_ITEM_NAME}")

if (CPPFRONT_DEVELOPING)
    file(MAKE_DIRECTORY "${BUILD_RESULTS_DIR}")

    # Write compiler version output.
    set(compiler_version_command "${CMAKE_CXX_COMPILER}" "--version")
    if (CMAKE_CXX_COMPILER_ID MATCHES "AppleClang")
        set(compiler_id "clang")
    endif ()
    execute_process(
        COMMAND ${compiler_version_command}
        OUTPUT_FILE "${BUILD_RESULTS_DIR}/${compiler_id}-version.output"
    )
endif ()

configure_file("cmake/ExecuteWithRedirection.cmake" "ExecuteWithRedirection.cmake" COPYONLY)
configure_file("cmake/ExecuteTestCase.cmake.in" "ExecuteTestCase.cmake" @ONLY)
configure_file("cmake/FindBuildResultFile.cmake.in" "FindBuildResultFile.cmake" @ONLY)
configure_file("cmake/UpdateBuildOutput.cmake.in" "UpdateBuildOutput.cmake" @ONLY)

include("${CMAKE_CURRENT_BINARY_DIR}/FindBuildResultFile.cmake")

function(cppfront_add_check_test)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "NAME;NEW_FILE;OLD_FILE;FIXTURES_REQUIRED" "")

    add_test(
        NAME "${ARG_NAME}"
        COMMAND "${CMAKE_COMMAND}" -E compare_files "${ARG_NEW_FILE}" "${ARG_OLD_FILE}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )
    set_tests_properties("${ARG_NAME}" PROPERTIES FIXTURES_REQUIRED "${ARG_FIXTURES_REQUIRED}")
endfunction()

function(cppfront_command_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "SOURCE;EXPECTED_FILE" "EXTRA_FLAGS")

    configure_file("${REGRESSION_TESTS_DIR}/${ARG_SOURCE}" "${ARG_SOURCE}" COPYONLY)

    cmake_path(GET ARG_SOURCE STEM test_name)

    if (NOT "${test_name}" MATCHES [[.*-error$]])
        set(gen_cpp_src "${test_name}.cpp")
        set(COMMAND_ERROR_IS_FATAL "COMMAND_ERROR_IS_FATAL" "ANY")
    endif ()
    add_test(
        NAME "codegen/${test_name}"
        COMMAND
        "${CMAKE_COMMAND}"
        -D "OUTPUT_FILE=${ARG_SOURCE}.output"
        -P "ExecuteWithRedirection.cmake"
        --
        "${CPPFRONT_EXECUTABLE}" "${ARG_SOURCE}" ${ARG_EXTRA_FLAGS}
        ${COMMAND_ERROR_IS_FATAL}
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )

    if (CPPFRONT_DEVELOPING)
        add_test(
            NAME "codegen/update/${test_name}"
            COMMAND
            "${CMAKE_COMMAND}"
            -E copy_if_different
            "${gen_cpp_src}"
            "${ARG_SOURCE}.output"
            "${TEST_RESULTS_DIR}"
        )
        set_tests_properties("codegen/update/${test_name}" PROPERTIES FIXTURES_CLEANUP "codegen/${test_name}")
        set(build_test_depends "codegen/update/${test_name}")
    endif ()

    set(expected_output_file "${TEST_RESULTS_DIR}/${ARG_SOURCE}.output")
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
        configure_file("${ARG_EXPECTED_FILE}" "${gen_cpp_src}.original" COPYONLY)
        cppfront_add_check_test(
            NAME "codegen/check/${test_name}"
            NEW_FILE "${gen_cpp_src}"
            OLD_FILE "${gen_cpp_src}.original"
            FIXTURES_REQUIRED "codegen/${test_name}"
        )

        cppfront_build_tests(
            SOURCE ${ARG_SOURCE}
            EXTRA_FLAGS ${ARG_EXTRA_FLAGS}
        )
    endif ()
endfunction()

function(cppfront_build_tests)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "SOURCE" "EXTRA_FLAGS")

    cmake_path(GET ARG_SOURCE STEM test_name)

    set(test_dir "${CMAKE_CURRENT_BINARY_DIR}/${test_name}")

    configure_file("${REGRESSION_TESTS_DIR}/${ARG_SOURCE}" "${test_dir}/${ARG_SOURCE}" COPYONLY)
    configure_file("cmake/CMakeLists.txt.in" "${test_dir}/CMakeLists.txt" @ONLY)
    configure_file("cmake/test-case-config.cmake.in" "${test_dir}/test-case-config.cmake.in" COPYONLY)

    add_test(
        NAME "build/${test_name}"
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
        # There's `CMAKE_CXX_LINKER_LAUNCHER`, too. So far, it's not needed.
        "-DCMAKE_CXX_COMPILER_LAUNCHER=${CMAKE_COMMAND};-D;OUTPUT_FILE=${gen_cpp_src}.output;-P;../../ExecuteWithRedirection.cmake;--"
    )
    set_tests_properties(
        "build/${test_name}"
        PROPERTIES
        DEPENDS "${build_test_depends};codegen/check/${test_name}"
        FIXTURES_SETUP "build/${test_name}"
    )

    cppfront_find_build_result_file(expected_output_file RESULT_FILE "${gen_cpp_src}.output")
    if (expected_output_file)
        cppfront_add_check_test(
            NAME "build/check/${test_name}"
            NEW_FILE "${test_dir}/build/${gen_cpp_src}.output"
            OLD_FILE "${expected_output_file}"
            FIXTURES_REQUIRED "build/${test_name}"
        )
    endif()

    add_test(
        NAME "build/execute/${test_name}"
        COMMAND
        "${CMAKE_COMMAND}"
        -D "OUTPUT_FILE=${test_dir}/${gen_cpp_src}.execution"
        -P "../ExecuteTestCase.cmake"
        WORKING_DIRECTORY "${test_dir}"
    )
    set_tests_properties(
        "build/execute/${test_name}"
        PROPERTIES
        FIXTURES_REQUIRED "build/${test_name}"
        FIXTURES_SETUP "build/execute/${test_name}"
        RESOURCE_LOCK "test.exe")

    cppfront_find_build_result_file(expected_execution_file RESULT_FILE "${gen_cpp_src}.execution")
    if (expected_execution_file)
        cppfront_add_check_test(
            NAME "build/execute/check/${test_name}"
            NEW_FILE "${test_dir}/${gen_cpp_src}.execution"
            OLD_FILE "${expected_execution_file}"
            FIXTURES_REQUIRED "build/execute/${test_name}"
        )
    endif()

    if (CPPFRONT_DEVELOPING)
        # Trigger regeneration to add the `check` tests for newly added results.
        if (NOT DEFINED expected_output_file OR NOT DEFINED expected_execution_file)
            file(GLOB unused CONFIGURE_DEPENDS "${BUILD_RESULTS_DIR}/${gen_cpp_src}.*")
        endif()

        add_test(
            NAME "build/update/${test_name}"
            COMMAND
            "${CMAKE_COMMAND}"
            -D "GEN_CPP_SRC=${gen_cpp_src}"
            -D "OUTPUT_FILE=build/${gen_cpp_src}.output"
            -D "EXECUTION_FILE=${gen_cpp_src}.execution"
            -P "../UpdateBuildOutput.cmake"
            WORKING_DIRECTORY "${test_dir}"
        )
        set_tests_properties(
            "build/update/${test_name}"
            PROPERTIES
            FIXTURES_CLEANUP "build/${test_name};build/execute/${test_name}"
        )
    endif ()
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
        set(expected_file "${TEST_RESULTS_DIR}/${expected_file}")

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
