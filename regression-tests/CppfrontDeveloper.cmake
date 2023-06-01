configure_file("cmake/UpdateTestResults.cmake.in" "UpdateTestResults.cmake" @ONLY)

function(cppfront_dev_setup_to_update_test_results TEST_NAME EXTRA_FLAGS)
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}")
    add_custom_target(
        "${TEST_NAME}"
        COMMAND
        "${CMAKE_COMMAND}"
        -D "TEST_NAME=${TEST_NAME}"
        -D "EXTRA_FLAGS=${EXTRA_FLAGS}"
        -P "UpdateTestResults.cmake"
    )

    set_property(DIRECTORY APPEND PROPERTY CPPFRONT_DEV_UPDATE_TEST_RESULTS_DEPENDS "${TEST_NAME}")
endfunction()

function(cppfront_dev_add_update_test_results_target)
    get_property(DEPENDS DIRECTORY PROPERTY CPPFRONT_DEV_UPDATE_TEST_RESULTS_DEPENDS)
    add_custom_target(cppfront_update_test_results DEPENDS ${DEPENDS})
endfunction()

cmake_language(DEFER CALL cppfront_dev_add_update_test_results_target)
