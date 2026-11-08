include_guard(GLOBAL)

#[[
Finds every dependency listed in a JSON manifest, so a project declares its
dependencies in one file (like `[dependencies]` in Cargo.toml).

The manifest is an object keyed by dependency name. Each entry may set:

  package
    Name passed to `find_package(<package> CONFIG REQUIRED)`. Defaults to the
    key.
  version
    Version requirement passed to `find_package`: a minimum (`"11.1"`) or a
    range (`"11...<13"`). Configuring fails when the installed version does not
    satisfy it. Optional.
  kind
    `build` (default): always found.
    `test`:  found only when `${PROJECT_NAME_UPPER}_BUILD_TESTS` is ON.
    `bench`: found only when `${PROJECT_NAME_UPPER}_BUILD_BENCHMARKS` is ON.

Example `deps.json`:

  {
    "fmt": { "package": "fmt", "version": "11...<13" },
    "gtest": { "package": "GTest", "kind": "test" },
    "gbenchmark": { "package": "benchmark", "kind": "bench" }
  }

Other tools may read the same file; Nix flakes, for example, can map the keys
to nixpkgs attributes. Editing the manifest re-runs CMake on the next build.

Keyword arguments:
  FILE
    Manifest path. Defaults to `${CMAKE_SOURCE_DIR}/deps.json`.
]]#
function(dependencies)
    cmake_parse_arguments(PARSE_ARGV 0 DEPS "" "FILE" "")

    if(DEPS_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "dependencies(): Unknown arguments: ${DEPS_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT DEPS_FILE)
        set(DEPS_FILE "${CMAKE_SOURCE_DIR}/deps.json")
    endif()

    if(NOT EXISTS "${DEPS_FILE}")
        message(FATAL_ERROR "dependencies(): Manifest \"${DEPS_FILE}\" does not exist")
    endif()

    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${DEPS_FILE}")
    file(READ "${DEPS_FILE}" _deps_json)

    string(JSON _deps_type ERROR_VARIABLE _deps_error TYPE "${_deps_json}")
    if(_deps_error OR NOT _deps_type STREQUAL "OBJECT")
        message(FATAL_ERROR "dependencies(): \"${DEPS_FILE}\" must contain a JSON object ${_deps_error}")
    endif()

    string(JSON _deps_count LENGTH "${_deps_json}")
    if(_deps_count EQUAL 0)
        return()
    endif()

    math(EXPR _deps_last "${_deps_count} - 1")
    foreach(_deps_index RANGE ${_deps_last})
        string(JSON _deps_name MEMBER "${_deps_json}" ${_deps_index})

        string(JSON _deps_entry_type TYPE "${_deps_json}" "${_deps_name}")
        if(NOT _deps_entry_type STREQUAL "OBJECT")
            message(FATAL_ERROR "dependencies(): Entry \"${_deps_name}\" must be a JSON object")
        endif()

        string(JSON _deps_package ERROR_VARIABLE _deps_error GET "${_deps_json}" "${_deps_name}" package)
        if(_deps_error)
            set(_deps_package "${_deps_name}")
        endif()

        string(JSON _deps_kind ERROR_VARIABLE _deps_error GET "${_deps_json}" "${_deps_name}" kind)
        if(_deps_error)
            set(_deps_kind "build")
        endif()

        if(_deps_kind STREQUAL "test")
            if(NOT ${PROJECT_NAME_UPPER}_BUILD_TESTS)
                continue()
            endif()
        elseif(_deps_kind STREQUAL "bench")
            if(NOT ${PROJECT_NAME_UPPER}_BUILD_BENCHMARKS)
                continue()
            endif()
        elseif(NOT _deps_kind STREQUAL "build")
            message(FATAL_ERROR
                "dependencies(): Entry \"${_deps_name}\" has kind \"${_deps_kind}\"; expected build, test or bench"
            )
        endif()

        string(JSON _deps_version ERROR_VARIABLE _deps_error GET "${_deps_json}" "${_deps_name}" version)
        if(_deps_error)
            set(_deps_version "")
        endif()

        find_package(${_deps_package} ${_deps_version} CONFIG REQUIRED)
    endforeach()
endfunction()
