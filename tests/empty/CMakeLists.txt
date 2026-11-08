# An empty workspace and an empty manifest must configure cleanly.
cmake_minimum_required(VERSION 3.25)
project(empty LANGUAGES CXX)

set(PROJECT_NAME_UPPER EMPTY)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(cookie)

dependencies()
workspace(DISCOVER libs)
