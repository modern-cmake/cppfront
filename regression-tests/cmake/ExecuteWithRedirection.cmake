if (NOT "${CMAKE_ARGV5}" STREQUAL "--")
    message(FATAL_ERROR "Unexpected argument.")
endif ()
foreach (i RANGE 6 ${CMAKE_ARGC})
    list(APPEND command_args "${CMAKE_ARGV${i}}") # Probably doesn't handle nested `;`.
endforeach ()
execute_process(
    COMMAND ${command_args}
    OUTPUT_VARIABLE OUTPUT
    ERROR_VARIABLE OUTPUT
    ECHO_OUTPUT_VARIABLE
    ECHO_ERROR_VARIABLE
)
file(WRITE "${OUTPUT_FILE}" "${OUTPUT}")
