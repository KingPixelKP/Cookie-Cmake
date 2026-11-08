cmake_minimum_required(VERSION 3.25)
project(fixture VERSION 0.1.0 LANGUAGES CXX)

set(PROJECT_NAME_UPPER FIXTURE)
option(FIXTURE_BUILD_TESTS "Build tests" ON)
option(FIXTURE_BUILD_BENCHMARKS "Build benchmarks" OFF)
set(CMAKE_CXX_STANDARD 20)
set(FIXTURE_COMPILE_DEFINITIONS -Wall -Wextra -Werror)

if(FIXTURE_BUILD_TESTS)
  enable_testing()
  include(GoogleTest)
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(cookie)

dependencies()
workspace(DISCOVER libs)
package(NAME fixture BIN BIN_DEPS greet fmt::fmt)
