# Fake package for the components test: provides "circle" and "square".
set(Shapes_VERSION 1.0.0)
set(Shapes_circle_FOUND TRUE)
set(Shapes_square_FOUND TRUE)

# Same logic as check_required_components() from CMakePackageConfigHelpers.
foreach(_component IN LISTS Shapes_FIND_COMPONENTS)
  if(NOT Shapes_${_component}_FOUND AND Shapes_FIND_REQUIRED_${_component})
    set(Shapes_FOUND FALSE)
    set(Shapes_NOT_FOUND_MESSAGE "Shapes has no component \"${_component}\"")
  endif()
endforeach()
