# Cookie-Cmake entry point: `include(cookie)` after adding this directory to
# CMAKE_MODULE_PATH. Defines package(), workspace(), dependencies() and the
# tooling helpers. Including it never touches the network.
include(tools)
include(package)
include(workspace)
include(dependencies)
