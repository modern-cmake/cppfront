cmake_minimum_required(VERSION 3.29)
project(cpp2-example)

find_package(cppfront REQUIRED)
# This works, too:
# add_subdirectory(../cppfront cppfront)

add_executable(main main.cpp2)
