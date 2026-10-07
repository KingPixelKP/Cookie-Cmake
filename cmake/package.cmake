include_guard(GLOBAL)

include(GNUInstallDirs)

function(_package_collect_cpp_sources out_var base_dir)
    if(EXISTS "${base_dir}")
        file(GLOB_RECURSE _package_sources CONFIGURE_DEPENDS
            "${base_dir}/*.cpp"
            "${base_dir}/*.cc"
            "${base_dir}/*.cxx"
        )
    else()
        set(_package_sources)
    endif()

    set("${out_var}" "${_package_sources}" PARENT_SCOPE)
endfunction()

function(_package_collect_headers out_var base_dir)
    if(EXISTS "${base_dir}")
        file(GLOB_RECURSE _package_headers CONFIGURE_DEPENDS
            "${base_dir}/*.h"
            "${base_dir}/*.hh"
            "${base_dir}/*.hpp"
            "${base_dir}/*.hxx"
        )
    else()
        set(_package_headers)
    endif()

    set("${out_var}" "${_package_headers}" PARENT_SCOPE)
endfunction()

function(_package_exclude_files out_var base_dir source_list)
    set(_package_filtered_sources ${source_list})

    foreach(_package_excluded IN LISTS ARGN)
        if(IS_ABSOLUTE "${_package_excluded}")
            set(_package_excluded_path "${_package_excluded}")
        else()
            set(_package_excluded_path "${base_dir}/${_package_excluded}")
        endif()

        cmake_path(NORMAL_PATH _package_excluded_path)
        list(REMOVE_ITEM _package_filtered_sources "${_package_excluded_path}")
    endforeach()

    set("${out_var}" "${_package_filtered_sources}" PARENT_SCOPE)
endfunction()

function(_package_normalize_test_framework out_var framework)
    string(TOUPPER "${framework}" _package_test_framework)

    if(_package_test_framework STREQUAL "" OR _package_test_framework STREQUAL "GTEST")
        set(_package_test_framework "GTEST")
    elseif(_package_test_framework STREQUAL "CTEST")
        set(_package_test_framework "CTEST")
    elseif(_package_test_framework STREQUAL "CATCH" OR _package_test_framework STREQUAL "CATCH2")
        set(_package_test_framework "CATCH2")
    else()
        message(FATAL_ERROR
            "package(): TEST_FRAMEWORK must be one of CTEST, GTEST, CATCH, or CATCH2"
        )
    endif()

    set("${out_var}" "${_package_test_framework}" PARENT_SCOPE)
endfunction()

function(_package_copy_data_dir_if_exists target source_dir output_dir)
    if(EXISTS "${source_dir}")
        add_custom_command(TARGET "${target}" POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${output_dir}/data"
            COMMAND ${CMAKE_COMMAND} -E copy_directory "${source_dir}" "${output_dir}/data"
            VERBATIM
        )
    endif()
endfunction()

#[[
Configure a package rooted at the current source directory.

Target selection:
  AUTO
    Re-enable auto-discovery even when explicit target mode flags are present.
  LIB
    Build a library target from files under `SRC_DIR`/`src` plus public headers
    under `INCLUDE_DIR`/`include`.
  BIN
    Build executables from `src/main.*` and files under `BIN_DIR`/`bin`.
  TESTS
    Build test executables from files under `TEST_DIR`/`test`.
  EXAMPLES
    Build example executables from files under `EXAMPLE_DIR`/`example`.
  BENCHMARKS
    Build benchmark executables from files under `BENCHMARK_DIR`/`benchmark`.
  NO_INSTALL
    Skip install/export rules for targets created by this package.

Names and directories:
  NAME
    Override the package name. Defaults to the current directory name.
  LIB_TYPE
    Library type passed to `add_library`, for example `STATIC`, `SHARED`, or
    `INTERFACE`. When omitted, `BUILD_SHARED_LIBS` selects `SHARED` or `STATIC`.
  INCLUDE_DIR / OVERRIDE_INCLUDE
    Directory containing public headers. Defaults to `include`.
  SRC_DIR / OVERRIDE_SRC
    Directory containing library sources and `main.*`. Defaults to `src`.
  TEST_DIR / OVERRIDE_TEST
    Directory containing test sources. Defaults to `test`.
  EXAMPLE_DIR / OVERRIDE_EXAMPLE
    Directory containing example sources. Defaults to `example`.
  BENCHMARK_DIR / OVERRIDE_BENCHMARK
    Directory containing benchmark sources. Defaults to `benchmark`.
  BIN_DIR / OVERRIDE_BIN
    Directory containing additional executable sources. Defaults to `bin`.

Inferred runtime data directories:
  `BIN_DIR`/data
    Copied to the built `bin` output directory for `src/main.*` and `BIN_DIR`
    executables when present.
  `TEST_DIR`/data
    Copied to the built `test` output directory for test executables when
    present.
  `EXAMPLE_DIR`/data
    Copied to the built `example` output directory for example executables when
    present.
  `BENCHMARK_DIR`/data
    Copied to the built `benchmark` output directory for benchmark executables
    when present.

Dependencies:
  DEPS
    Shared dependencies applied where a standalone target needs them.
  PUBLIC_DEPS / PUB_DEPS
    Public library dependencies exposed to consumers of the package library.
  PRIVATE_DEPS / PRIV_DEPS
    Private library dependencies used only when linking the package library.
  BIN_DEPS
    Extra dependencies for binaries created from `BIN` or `src/main.*`.
  TEST_DEPS
    Extra dependencies for test targets.
  EXAMPLE_DEPS
    Extra dependencies for example targets.
  BENCHMARK_DEPS
    Extra dependencies for benchmark targets.

Testing:
  TEST_FRAMEWORK / TEST_LIB
    Select `GTEST`, `CTEST`, or `CATCH2` test integration. `TEST_LIB` is kept as
    a compatibility alias for the same choice.

Per-file exclusions:
  EXCLUDE_SRCS
    Skip specific files inside `SRC_DIR`/`src`, including `main.*` when needed.
  EXCLUDE_BINS
    Skip specific files inside `BIN_DIR`/`bin`.
  EXCLUDE_TESTS
    Skip specific files inside `TEST_DIR`/`test`.
  EXCLUDE_EXAMPLES
    Skip specific files inside `EXAMPLE_DIR`/`example`.
  EXCLUDE_BENCHMARKS
    Skip specific files inside `BENCHMARK_DIR`/`benchmark`.

Relative exclusion paths are resolved from the matching category directory, for
example `EXCLUDE_TESTS slow.cpp` skips `test/slow.cpp`.
#]]
function(package)
    set(options
        AUTO
        LIB
        BIN
        TESTS
        EXAMPLES
        BENCHMARKS
        NO_INSTALL
    )
    set(oneValueArgs
        NAME
        LIB_TYPE
        INCLUDE_DIR
        OVERRIDE_INCLUDE
        SRC_DIR
        OVERRIDE_SRC
        TEST_DIR
        OVERRIDE_TEST
        EXAMPLE_DIR
        OVERRIDE_EXAMPLE
        BENCHMARK_DIR
        OVERRIDE_BENCHMARK
        BIN_DIR
        OVERRIDE_BIN
        TEST_LIB
        TEST_FRAMEWORK
    )
    set(multiValueArgs
        DEPS
        PUBLIC_DEPS
        PRIVATE_DEPS
        PUB_DEPS
        PRIV_DEPS
        BIN_DEPS
        TEST_DEPS
        EXAMPLE_DEPS
        BENCHMARK_DEPS
        EXCLUDE_SRCS
        EXCLUDE_BINS
        EXCLUDE_TESTS
        EXCLUDE_EXAMPLES
        EXCLUDE_BENCHMARKS
    )

    cmake_parse_arguments(PARSE_ARGV 0 PKG
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if(PKG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR
            "package(): Missing values for keywords: ${PKG_KEYWORDS_MISSING_VALUES}"
        )
    endif()

    if(PKG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "package(): Unknown arguments: ${PKG_UNPARSED_ARGUMENTS}"
        )
    endif()

    if(PKG_INCLUDE_DIR)
        set(_package_include_dir "${PKG_INCLUDE_DIR}")
    elseif(PKG_OVERRIDE_INCLUDE)
        set(_package_include_dir "${PKG_OVERRIDE_INCLUDE}")
    else()
        set(_package_include_dir "include")
    endif()

    if(PKG_SRC_DIR)
        set(_package_source_dir "${PKG_SRC_DIR}")
    elseif(PKG_OVERRIDE_SRC)
        set(_package_source_dir "${PKG_OVERRIDE_SRC}")
    else()
        set(_package_source_dir "src")
    endif()

    if(PKG_TEST_DIR)
        set(_package_test_dir "${PKG_TEST_DIR}")
    elseif(PKG_OVERRIDE_TEST)
        set(_package_test_dir "${PKG_OVERRIDE_TEST}")
    else()
        set(_package_test_dir "test")
    endif()

    if(PKG_EXAMPLE_DIR)
        set(_package_example_dir "${PKG_EXAMPLE_DIR}")
    elseif(PKG_OVERRIDE_EXAMPLE)
        set(_package_example_dir "${PKG_OVERRIDE_EXAMPLE}")
    else()
        set(_package_example_dir "example")
    endif()

    if(PKG_BENCHMARK_DIR)
        set(_package_benchmark_dir "${PKG_BENCHMARK_DIR}")
    elseif(PKG_OVERRIDE_BENCHMARK)
        set(_package_benchmark_dir "${PKG_OVERRIDE_BENCHMARK}")
    else()
        set(_package_benchmark_dir "benchmark")
    endif()

    if(PKG_BIN_DIR)
        set(_package_bin_dir "${PKG_BIN_DIR}")
    elseif(PKG_OVERRIDE_BIN)
        set(_package_bin_dir "${PKG_OVERRIDE_BIN}")
    else()
        set(_package_bin_dir "bin")
    endif()

    if("${_package_source_dir}" STREQUAL "${_package_bin_dir}")
        message(FATAL_ERROR
            "package(): SRC_DIR and BIN_DIR cannot be the same directory"
        )
    endif()

    if("${_package_source_dir}" STREQUAL "${_package_test_dir}")
        message(FATAL_ERROR
            "package(): SRC_DIR and TEST_DIR cannot be the same directory"
        )
    endif()

    if("${_package_source_dir}" STREQUAL "${_package_example_dir}")
        message(FATAL_ERROR
            "package(): SRC_DIR and EXAMPLE_DIR cannot be the same directory"
        )
    endif()

    if("${_package_source_dir}" STREQUAL "${_package_benchmark_dir}")
        message(FATAL_ERROR
            "package(): SRC_DIR and BENCHMARK_DIR cannot be the same directory"
        )
    endif()

    if(NOT PKG_NAME)
        get_filename_component(PKG_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
    endif()

    set(_package_target_modes_requested FALSE)

    if(PKG_LIB OR PKG_BIN OR PKG_TESTS OR PKG_EXAMPLES OR PKG_BENCHMARKS)
        set(_package_target_modes_requested TRUE)
    endif()

    set(_package_auto_mode TRUE)

    if(_package_target_modes_requested)
        set(_package_auto_mode FALSE)
    endif()

    if(PKG_AUTO)
        set(_package_auto_mode TRUE)
    endif()

    set(_package_include_path "${CMAKE_CURRENT_SOURCE_DIR}/${_package_include_dir}")
    set(_package_source_path "${CMAKE_CURRENT_SOURCE_DIR}/${_package_source_dir}")
    set(_package_test_path "${CMAKE_CURRENT_SOURCE_DIR}/${_package_test_dir}")
    set(_package_example_path "${CMAKE_CURRENT_SOURCE_DIR}/${_package_example_dir}")
    set(_package_benchmark_path "${CMAKE_CURRENT_SOURCE_DIR}/${_package_benchmark_dir}")
    set(_package_bin_path "${CMAKE_CURRENT_SOURCE_DIR}/${_package_bin_dir}")

    _package_collect_headers(_package_public_headers "${_package_include_path}")
    _package_collect_cpp_sources(_package_library_sources "${_package_source_path}")
    list(FILTER _package_library_sources EXCLUDE REGEX "/main\\.(cpp|cc|cxx)$")
    _package_exclude_files(
        _package_library_sources
        "${_package_source_path}"
        "${_package_library_sources}"
        ${PKG_EXCLUDE_SRCS}
    )

    _package_collect_cpp_sources(_package_binary_sources "${_package_bin_path}")
    _package_exclude_files(
        _package_binary_sources
        "${_package_bin_path}"
        "${_package_binary_sources}"
        ${PKG_EXCLUDE_BINS}
    )
    _package_collect_cpp_sources(_package_test_sources "${_package_test_path}")
    _package_exclude_files(
        _package_test_sources
        "${_package_test_path}"
        "${_package_test_sources}"
        ${PKG_EXCLUDE_TESTS}
    )

    _package_collect_cpp_sources(_package_example_sources "${_package_example_path}")
    _package_exclude_files(
        _package_example_sources
        "${_package_example_path}"
        "${_package_example_sources}"
        ${PKG_EXCLUDE_EXAMPLES}
    )

    _package_collect_cpp_sources(_package_benchmark_sources "${_package_benchmark_path}")
    _package_exclude_files(
        _package_benchmark_sources
        "${_package_benchmark_path}"
        "${_package_benchmark_sources}"
        ${PKG_EXCLUDE_BENCHMARKS}
    )

    file(GLOB _package_main_sources CONFIGURE_DEPENDS
        "${_package_source_path}/main.cpp"
        "${_package_source_path}/main.cc"
        "${_package_source_path}/main.cxx"
    )
    _package_exclude_files(
        _package_main_sources
        "${_package_source_path}"
        "${_package_main_sources}"
        ${PKG_EXCLUDE_SRCS}
    )
    list(LENGTH _package_main_sources _package_main_sources_count)

    if(_package_main_sources_count GREATER 1)
        message(FATAL_ERROR
            "package(): More than one main source was found in ${_package_source_dir}"
        )
    endif()

    set(_package_shared_dependencies ${PKG_DEPS})
    set(_package_public_dependencies ${PKG_PUBLIC_DEPS} ${PKG_PUB_DEPS})
    set(_package_private_dependencies ${PKG_PRIVATE_DEPS} ${PKG_PRIV_DEPS})
    set(_package_binary_dependencies ${PKG_BIN_DEPS})
    set(_package_test_dependencies ${PKG_TEST_DEPS})
    set(_package_example_dependencies ${PKG_EXAMPLE_DEPS})
    set(_package_benchmark_dependencies ${PKG_BENCHMARK_DEPS})

    if(PKG_TEST_LIB AND PKG_TEST_FRAMEWORK)
        _package_normalize_test_framework(_package_test_lib_framework "${PKG_TEST_LIB}")
        _package_normalize_test_framework(_package_named_test_framework "${PKG_TEST_FRAMEWORK}")

        if(NOT _package_test_lib_framework STREQUAL _package_named_test_framework)
            message(FATAL_ERROR
                "package(): TEST_LIB and TEST_FRAMEWORK must select the same test framework"
            )
        endif()
    endif()

    if(PKG_TEST_FRAMEWORK)
        set(_package_requested_test_framework "${PKG_TEST_FRAMEWORK}")
    else()
        set(_package_requested_test_framework "${PKG_TEST_LIB}")
    endif()

    _package_normalize_test_framework(_package_test_framework "${_package_requested_test_framework}")

    list(REMOVE_DUPLICATES _package_shared_dependencies)
    list(REMOVE_DUPLICATES _package_public_dependencies)
    list(REMOVE_DUPLICATES _package_private_dependencies)
    list(REMOVE_DUPLICATES _package_binary_dependencies)
    list(REMOVE_DUPLICATES _package_test_dependencies)
    list(REMOVE_DUPLICATES _package_example_dependencies)
    list(REMOVE_DUPLICATES _package_benchmark_dependencies)

    set(_package_should_make_lib FALSE)

    if(PKG_LIB)
        set(_package_should_make_lib TRUE)
    elseif(_package_auto_mode)
        if(_package_library_sources OR _package_public_headers)
            set(_package_should_make_lib TRUE)
        endif()
    endif()

    set(_package_should_make_main FALSE)

    if(_package_main_sources_count EQUAL 1)
        if(PKG_BIN OR _package_auto_mode)
            set(_package_should_make_main TRUE)
        endif()
    endif()

    set(_package_should_make_binaries FALSE)

    if(_package_binary_sources)
        if(PKG_BIN OR _package_auto_mode)
            set(_package_should_make_binaries TRUE)
        endif()
    endif()

    set(_package_should_make_tests FALSE)

    if(_package_test_sources)
        if(PKG_TESTS OR _package_auto_mode)
            set(_package_should_make_tests TRUE)
        endif()
    endif()

    set(_package_should_make_examples FALSE)

    if(_package_example_sources)
        if(PKG_EXAMPLES OR _package_auto_mode)
            set(_package_should_make_examples TRUE)
        endif()
    endif()

    set(_package_should_make_benchmarks FALSE)

    if(_package_benchmark_sources)
        if(PKG_BENCHMARKS OR _package_auto_mode)
            set(_package_should_make_benchmarks TRUE)
        endif()
    endif()

    if(PKG_LIB AND NOT _package_library_sources AND NOT _package_public_headers)
        message(FATAL_ERROR
            "package(): LIB was requested but no library sources or public headers were found"
        )
    endif()

    if(PKG_BIN AND NOT _package_should_make_main AND NOT _package_should_make_binaries)
        message(FATAL_ERROR
            "package(): BIN was requested but no src/main.* or bin/* sources were found"
        )
    endif()

    if(PKG_TESTS AND NOT _package_test_sources)
        message(FATAL_ERROR
            "package(): TESTS was requested but no test sources were found"
        )
    endif()

    if(PKG_EXAMPLES AND NOT _package_example_sources)
        message(FATAL_ERROR
            "package(): EXAMPLES was requested but no example sources were found"
        )
    endif()

    if(PKG_BENCHMARKS AND NOT _package_benchmark_sources)
        message(FATAL_ERROR
            "package(): BENCHMARKS was requested but no benchmark sources were found"
        )
    endif()

    message(STATUS "package(): Configuring package \"${PKG_NAME}\"")

    if(_package_should_make_lib)
        if(_package_library_sources)
            if(PKG_LIB_TYPE)
                add_library("${PKG_NAME}" "${PKG_LIB_TYPE}" ${_package_library_sources})
            else()
                add_library("${PKG_NAME}" ${_package_library_sources})
            endif()

            if(EXISTS "${_package_include_path}")
                target_include_directories("${PKG_NAME}"
                    PUBLIC
                    "$<BUILD_INTERFACE:${_package_include_path}>"
                    "$<INSTALL_INTERFACE:${_package_include_dir}>"
                )
            endif()

            if(_package_public_dependencies)
                target_link_libraries("${PKG_NAME}"
                    PUBLIC
                    ${_package_public_dependencies}
                )
            endif()

            if(_package_shared_dependencies OR _package_private_dependencies)
                target_link_libraries("${PKG_NAME}"
                    PRIVATE
                    ${_package_shared_dependencies}
                    ${_package_private_dependencies}
                )
            endif()
        else()
            if(PKG_LIB_TYPE AND NOT PKG_LIB_TYPE STREQUAL "INTERFACE")
                message(WARNING
                    "package(): No compiled library sources were found; creating an INTERFACE library instead"
                )
            endif()

            add_library("${PKG_NAME}" INTERFACE)

            if(EXISTS "${_package_include_path}")
                target_include_directories("${PKG_NAME}"
                    INTERFACE
                    "$<BUILD_INTERFACE:${_package_include_path}>"
                    "$<INSTALL_INTERFACE:${_package_include_dir}>"
                )
            endif()

            if(_package_shared_dependencies OR _package_public_dependencies)
                target_link_libraries("${PKG_NAME}"
                    INTERFACE
                    ${_package_shared_dependencies}
                    ${_package_public_dependencies}
                )
            endif()

            if(_package_private_dependencies)
                message(WARNING
                    "package(): PRIVATE_DEPS/PRIV_DEPS are ignored for header-only or INTERFACE packages"
                )
            endif()
        endif()

        add_library("${PROJECT_NAME}::${PKG_NAME}" ALIAS "${PKG_NAME}")
        add_library("${PKG_NAME}::${PKG_NAME}" ALIAS "${PKG_NAME}")
        add_library("${PKG_NAME}::lib" ALIAS "${PKG_NAME}")
        configure_target("${PKG_NAME}")

        if(NOT PKG_NO_INSTALL)
            install_project_target("${PKG_NAME}")

            if(EXISTS "${_package_include_path}")
                install_project_headers("${_package_include_path}")
            endif()
        endif()

        set(_package_library_target "${PKG_NAME}")
    endif()

    if(_package_should_make_main)
        list(GET _package_main_sources 0 _package_main_source)
        set(_package_main_target "${PKG_NAME}_main")
        set(_package_main_target_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${_package_bin_dir}")

        if(NOT _package_library_target)
            set(_package_main_target "${PKG_NAME}")
        endif()

        add_executable("${_package_main_target}" "${_package_main_source}")
        set_target_properties("${_package_main_target}"
            PROPERTIES
            ARCHIVE_OUTPUT_DIRECTORY "${_package_main_target_output_dir}"
            LIBRARY_OUTPUT_DIRECTORY "${_package_main_target_output_dir}"
            OUTPUT_NAME "${PKG_NAME}"
            RUNTIME_OUTPUT_DIRECTORY "${_package_main_target_output_dir}"
        )
        _package_copy_data_dir_if_exists(
            "${_package_main_target}"
            "${_package_bin_path}/data"
            "${_package_main_target_output_dir}"
        )

        if(_package_library_target)
            target_link_libraries("${_package_main_target}"
                PRIVATE
                "${_package_library_target}"
                ${_package_binary_dependencies}
            )
        else()
            set(_package_main_dependencies
                ${_package_shared_dependencies}
                ${_package_public_dependencies}
                ${_package_private_dependencies}
                ${_package_binary_dependencies}
            )

            if(_package_main_dependencies)
                target_link_libraries("${_package_main_target}"
                    PRIVATE
                    ${_package_main_dependencies}
                )
            endif()
        endif()

        configure_target("${_package_main_target}")

        if(NOT PKG_NO_INSTALL)
            install_project_target("${_package_main_target}")
        endif()

        add_executable("${PKG_NAME}::main" ALIAS "${_package_main_target}")
    endif()

    if(_package_should_make_binaries)
        list(LENGTH _package_binary_sources _package_binary_sources_count)

        foreach(source IN LISTS _package_binary_sources)
            get_filename_component(_package_binary_name "${source}" NAME_WE)
            set(_package_binary_target "${PKG_NAME}_bin_${_package_binary_name}")
            set(_package_binary_target_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${_package_bin_dir}")

            if(
                NOT _package_library_target
                AND _package_binary_sources_count EQUAL 1
                AND "${_package_binary_name}" STREQUAL "${PKG_NAME}"
            )
                set(_package_binary_target "${PKG_NAME}")
            endif()

            add_executable("${_package_binary_target}" "${source}")
            set_target_properties("${_package_binary_target}"
                PROPERTIES
                ARCHIVE_OUTPUT_DIRECTORY "${_package_binary_target_output_dir}"
                LIBRARY_OUTPUT_DIRECTORY "${_package_binary_target_output_dir}"
                OUTPUT_NAME "${_package_binary_name}"
                RUNTIME_OUTPUT_DIRECTORY "${_package_binary_target_output_dir}"
            )
            _package_copy_data_dir_if_exists(
                "${_package_binary_target}"
                "${_package_bin_path}/data"
                "${_package_binary_target_output_dir}"
            )

            if(_package_library_target)
                target_link_libraries("${_package_binary_target}"
                    PRIVATE
                    "${_package_library_target}"
                    ${_package_binary_dependencies}
                )
            else()
                set(_package_bin_dependencies_all
                    ${_package_shared_dependencies}
                    ${_package_public_dependencies}
                    ${_package_private_dependencies}
                    ${_package_binary_dependencies}
                )

                if(_package_bin_dependencies_all)
                    target_link_libraries("${_package_binary_target}"
                        PRIVATE
                        ${_package_bin_dependencies_all}
                    )
                endif()
            endif()

            configure_target("${_package_binary_target}")

            if(NOT PKG_NO_INSTALL)
                install_project_target("${_package_binary_target}")
            endif()

            add_executable("${PKG_NAME}::${_package_binary_name}" ALIAS "${_package_binary_target}")
        endforeach()
    endif()

    if(_package_should_make_tests)
        if(NOT ${PROJECT_NAME_UPPER}_BUILD_TESTS)
            message(STATUS
                "package(): Test sources were found for \"${PKG_NAME}\" but ${PROJECT_NAME_UPPER}_BUILD_TESTS is OFF"
            )
        else()
            foreach(source IN LISTS _package_test_sources)
                get_filename_component(_package_test_name "${source}" NAME_WE)
                set(_package_test_target "${PKG_NAME}_test_${_package_test_name}")
                set(_package_test_target_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${_package_test_dir}")

                add_executable("${_package_test_target}" "${source}")
                set_target_properties("${_package_test_target}"
                    PROPERTIES
                    ARCHIVE_OUTPUT_DIRECTORY "${_package_test_target_output_dir}"
                    LIBRARY_OUTPUT_DIRECTORY "${_package_test_target_output_dir}"
                    OUTPUT_NAME "${_package_test_name}"
                    RUNTIME_OUTPUT_DIRECTORY "${_package_test_target_output_dir}"
                )
                _package_copy_data_dir_if_exists(
                    "${_package_test_target}"
                    "${_package_test_path}/data"
                    "${_package_test_target_output_dir}"
                )

                set(_package_test_link_libraries)

                if(_package_library_target)
                    list(APPEND _package_test_link_libraries
                        "${_package_library_target}"
                        ${_package_test_dependencies}
                    )
                else()
                    list(APPEND _package_test_link_libraries
                        ${_package_shared_dependencies}
                        ${_package_public_dependencies}
                        ${_package_private_dependencies}
                        ${_package_test_dependencies}
                    )
                endif()

                if(_package_test_framework STREQUAL "GTEST")
                    list(APPEND _package_test_link_libraries GTest::gtest_main)
                    target_link_libraries("${_package_test_target}"
                        PRIVATE
                        ${_package_test_link_libraries}
                    )
                    gtest_discover_tests("${_package_test_target}" DISCOVERY_MODE PRE_TEST)
                elseif(_package_test_framework STREQUAL "CATCH2")
                    list(APPEND _package_test_link_libraries Catch2::Catch2WithMain)
                    target_link_libraries("${_package_test_target}"
                        PRIVATE
                        ${_package_test_link_libraries}
                    )
                    catch_discover_tests("${_package_test_target}" DISCOVERY_MODE PRE_TEST)
                else()
                    if(_package_test_link_libraries)
                        target_link_libraries("${_package_test_target}"
                            PRIVATE
                            ${_package_test_link_libraries}
                        )
                    endif()

                    add_test(NAME "${PKG_NAME}::${_package_test_name}" COMMAND "${_package_test_target}")
                endif()

                configure_target("${_package_test_target}")
            endforeach()
        endif()
    endif()

    if(_package_should_make_examples)
        if(NOT ${PROJECT_NAME_UPPER}_BUILD_EXAMPLES)
            message(STATUS
                "package(): Example sources were found for \"${PKG_NAME}\" but ${PROJECT_NAME_UPPER}_BUILD_EXAMPLES is OFF"
            )
        else()
            foreach(source IN LISTS _package_example_sources)
                get_filename_component(_package_example_name "${source}" NAME_WE)
                set(_package_example_target "${PKG_NAME}_example_${_package_example_name}")
                set(_package_example_target_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${_package_example_dir}")

                add_executable("${_package_example_target}" "${source}")
                set_target_properties("${_package_example_target}"
                    PROPERTIES
                    ARCHIVE_OUTPUT_DIRECTORY "${_package_example_target_output_dir}"
                    LIBRARY_OUTPUT_DIRECTORY "${_package_example_target_output_dir}"
                    OUTPUT_NAME "${_package_example_name}"
                    RUNTIME_OUTPUT_DIRECTORY "${_package_example_target_output_dir}"
                )
                _package_copy_data_dir_if_exists(
                    "${_package_example_target}"
                    "${_package_example_path}/data"
                    "${_package_example_target_output_dir}"
                )

                set(_package_example_link_libraries)

                if(_package_library_target)
                    list(APPEND _package_example_link_libraries
                        "${_package_library_target}"
                        ${_package_example_dependencies}
                    )
                else()
                    list(APPEND _package_example_link_libraries
                        ${_package_shared_dependencies}
                        ${_package_public_dependencies}
                        ${_package_private_dependencies}
                        ${_package_example_dependencies}
                    )
                endif()

                if(_package_example_link_libraries)
                    target_link_libraries("${_package_example_target}"
                        PRIVATE
                        ${_package_example_link_libraries}
                    )
                endif()

                configure_target("${_package_example_target}")
            endforeach()
        endif()
    endif()

    if(_package_should_make_benchmarks)
        if(NOT ${PROJECT_NAME_UPPER}_BUILD_BENCHMARKS)
            message(STATUS
                "package(): Benchmark sources were found for \"${PKG_NAME}\" but ${PROJECT_NAME_UPPER}_BUILD_BENCHMARKS is OFF"
            )
        else()
            foreach(source IN LISTS _package_benchmark_sources)
                get_filename_component(_package_benchmark_name "${source}" NAME_WE)
                set(_package_benchmark_target "${PKG_NAME}_benchmark_${_package_benchmark_name}")
                set(_package_benchmark_target_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${_package_benchmark_dir}")

                add_executable("${_package_benchmark_target}" "${source}")
                set_target_properties("${_package_benchmark_target}"
                    PROPERTIES
                    ARCHIVE_OUTPUT_DIRECTORY "${_package_benchmark_target_output_dir}"
                    LIBRARY_OUTPUT_DIRECTORY "${_package_benchmark_target_output_dir}"
                    OUTPUT_NAME "${_package_benchmark_name}"
                    RUNTIME_OUTPUT_DIRECTORY "${_package_benchmark_target_output_dir}"
                )
                _package_copy_data_dir_if_exists(
                    "${_package_benchmark_target}"
                    "${_package_benchmark_path}/data"
                    "${_package_benchmark_target_output_dir}"
                )

                set(_package_benchmark_link_libraries benchmark::benchmark benchmark::benchmark_main)

                if(_package_library_target)
                    list(APPEND _package_benchmark_link_libraries
                        "${_package_library_target}"
                        ${_package_benchmark_dependencies}
                    )
                else()
                    list(APPEND _package_benchmark_link_libraries
                        ${_package_shared_dependencies}
                        ${_package_public_dependencies}
                        ${_package_private_dependencies}
                        ${_package_benchmark_dependencies}
                    )
                endif()

                target_link_libraries("${_package_benchmark_target}"
                    PRIVATE
                    ${_package_benchmark_link_libraries}
                )

                configure_target("${_package_benchmark_target}")
            endforeach()
        endif()
    endif()

    message(STATUS "package(): Configured package \"${PKG_NAME}\"")
endfunction()
