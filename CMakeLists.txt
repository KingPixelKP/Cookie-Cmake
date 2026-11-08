cmake_minimum_required(VERSION 3.25)
project(CookieCmake VERSION 1.0.0 LANGUAGES CXX)

# Lets projects consume Cookie-Cmake with add_subdirectory()/FetchContent too.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
include(cookie)
