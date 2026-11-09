cmake_minimum_required(VERSION 3.25)
project(components LANGUAGES CXX)

set(PROJECT_NAME_UPPER COMPONENTS)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake")
list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../prefix")
include(cookie)

dependencies()
