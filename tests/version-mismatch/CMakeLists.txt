# A dependency outside its "version" range must stop configuration.
cmake_minimum_required(VERSION 3.25)
project(version_mismatch LANGUAGES CXX)

set(PROJECT_NAME_UPPER VERSION_MISMATCH)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(cookie)

dependencies()
