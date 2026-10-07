include_guard(GLOBAL)

function(workspace)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs
        MEMBERS
        DISCOVER
        EXCLUDE
    )

    cmake_parse_arguments(PARSE_ARGV 0 WKSP
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if(WKSP_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR
            "workspace(): Missing values for keywords: ${WKSP_KEYWORDS_MISSING_VALUES}"
        )
    endif()

    if(WKSP_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "workspace(): Unknown arguments: ${WKSP_UNPARSED_ARGUMENTS}"
        )
    endif()

    if(NOT WKSP_MEMBERS AND NOT WKSP_DISCOVER)
        message(FATAL_ERROR
            "workspace(): Define explicit MEMBERS or provide DISCOVER roots"
        )
    endif()

    set(_workspace_members)

    foreach(member IN LISTS WKSP_MEMBERS)
        set(_workspace_member_path "${CMAKE_CURRENT_SOURCE_DIR}/${member}")
        if(NOT EXISTS "${_workspace_member_path}/CMakeLists.txt")
            message(FATAL_ERROR
                "workspace(): Member \"${member}\" does not contain a CMakeLists.txt"
            )
        endif()
        list(APPEND _workspace_members "${member}")
    endforeach()

    foreach(root IN LISTS WKSP_DISCOVER)
        file(GLOB _workspace_discovered CONFIGURE_DEPENDS
            RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
            "${CMAKE_CURRENT_SOURCE_DIR}/${root}/*/CMakeLists.txt"
        )

        foreach(member_file IN LISTS _workspace_discovered)
            cmake_path(GET member_file PARENT_PATH _workspace_member_dir)
            cmake_path(NORMAL_PATH _workspace_member_dir OUTPUT_VARIABLE _workspace_member_dir)
            list(APPEND _workspace_members "${_workspace_member_dir}")
        endforeach()
    endforeach()

    if(WKSP_EXCLUDE)
        set(_workspace_filtered_members)
        foreach(member IN LISTS _workspace_members)
            get_filename_component(_workspace_member_name "${member}" NAME)
            set(_workspace_excluded FALSE)

            foreach(excluded IN LISTS WKSP_EXCLUDE)
                if(member STREQUAL excluded OR _workspace_member_name STREQUAL excluded)
                    set(_workspace_excluded TRUE)
                    break()
                endif()
            endforeach()

            if(NOT _workspace_excluded)
                list(APPEND _workspace_filtered_members "${member}")
            endif()
        endforeach()

        set(_workspace_members "${_workspace_filtered_members}")
    endif()

    list(REMOVE_DUPLICATES _workspace_members)

    if(NOT _workspace_members)
        message(FATAL_ERROR "workspace(): No workspace members remain after filtering")
    endif()

    message(STATUS "workspace(): Configuring workspace members: ${_workspace_members}")

    foreach(member IN LISTS _workspace_members)
        add_subdirectory("${member}")
    endforeach()

    message(STATUS "workspace(): Configured workspace")
endfunction()
