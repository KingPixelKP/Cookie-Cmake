# Cookie Cmake

CMake helpers that bring a Cargo-like workflow to C++ projects: the directory layout is the
configuration, dependencies live in one manifest, and a workspace discovers its packages.

Including Cookie-Cmake never touches the network.

## Using it

### With Nix flakes

```nix
inputs.cookie-cmake = {
  url = "github:KingPixelKP/Cookie-Cmake/v1.0.0";
  flake = false;
};
```

Pass `${cookie-cmake}` to CMake (for example `-DCOOKIE_CMAKE_DIR=${cookie-cmake}`), then:

```cmake
list(APPEND CMAKE_MODULE_PATH "${COOKIE_CMAKE_DIR}/cmake")
include(cookie)
```

### With FetchContent or add_subdirectory

```cmake
include(FetchContent)
FetchContent_Declare(cookie_cmake
  GIT_REPOSITORY https://github.com/KingPixelKP/Cookie-Cmake.git
  GIT_TAG v1.0.0
)
FetchContent_MakeAvailable(cookie_cmake)
```

The functions read a few project-wide variables. Set `PROJECT_NAME_UPPER` and the
`${PROJECT_NAME_UPPER}_BUILD_TESTS` / `_BUILD_BENCHMARKS` / `_INSTALL` options before calling them.

## Project layout

```text
my_project/
├── CMakeLists.txt        # dependencies(), workspace(), package()
├── deps.json             # dependency manifest
├── src/main.cpp          # main executable
└── libs/
    └── greet/
        ├── CMakeLists.txt      # package()
        ├── include/greet/      # public headers
        ├── src/                # library sources
        ├── test/               # one test executable per file
        ├── example/            # one example executable per file
        ├── benchmark/          # one benchmark executable per file
        └── bin/                # extra executables
```

A `data/` directory under `bin/`, `test/`, `example/` or `benchmark/` is copied next to the matching
executables.

## `package()`

Builds whatever the directory contains. With no mode flags it works out the targets from the layout,
and `NAME` defaults to the directory name:

```cmake
package(LIB_TYPE STATIC TEST_DEPS fmt::fmt)
```

A library `greet` gets the aliases `greet::greet`, `greet::lib` and `<project>::greet`.

| Argument | Meaning |
| --- | --- |
| `LIB`, `BIN`, `TESTS`, `EXAMPLES`, `BENCHMARKS` | Build only these kinds of targets (fails if the sources are missing). `AUTO` re-enables discovery alongside them. |
| `NAME` | Package name. Default: directory name. |
| `LIB_TYPE` | `STATIC`, `SHARED` or `INTERFACE`. Default: `BUILD_SHARED_LIBS`. |
| `DEPS` | Dependencies for every target that needs them. |
| `PUBLIC_DEPS` / `PRIVATE_DEPS` | Library dependencies, exposed to consumers or not. |
| `BIN_DEPS`, `TEST_DEPS`, `EXAMPLE_DEPS`, `BENCHMARK_DEPS` | Extra dependencies per kind of target. |
| `TEST_FRAMEWORK` | `GTEST` (default), `CATCH2` or `CTEST`. |
| `INCLUDE_DIR`, `SRC_DIR`, `TEST_DIR`, `EXAMPLE_DIR`, `BENCHMARK_DIR`, `BIN_DIR` | Override a directory name. |
| `EXCLUDE_SRCS`, `EXCLUDE_BINS`, `EXCLUDE_TESTS`, `EXCLUDE_EXAMPLES`, `EXCLUDE_BENCHMARKS` | Skip files. |
| `NO_INSTALL` | Skip install and export rules. |

## `dependencies()`

Reads a JSON manifest (default `${CMAKE_SOURCE_DIR}/deps.json`) and calls
`find_package(<package> CONFIG REQUIRED)` for each entry:

```json
{
  "fmt": { "package": "fmt", "version": "11...<13" },
  "gtest": { "package": "GTest", "kind": "test" },
  "gbenchmark": { "package": "benchmark", "kind": "bench" }
}
```

| Field | Meaning |
| --- | --- |
| key | Dependency name. Other tools can reuse it, e.g. a flake can treat it as the nixpkgs attribute. |
| `package` | `find_package` name. Default: the key. |
| `version` | Version requirement passed to `find_package`: a minimum (`"11.1"`) or a range (`"11...<13"`). Configuring fails when the installed version does not satisfy it. Ranges need a version file that supports them, which `write_basic_package_version_file` generates. |
| `components` | Array of required components, passed as `find_package(... COMPONENTS ...)`, e.g. `["Core", "Widgets"]` for Qt6. |
| `kind` | `build` (default, always found), `test` (only with `_BUILD_TESTS`) or `bench` (only with `_BUILD_BENCHMARKS`). |

Use `dependencies(FILE path/to/deps.json)` for a different location.

## `workspace()`

Adds every package found under the given roots, like a Cargo workspace:

```cmake
workspace(DISCOVER libs EXCLUDE experimental)
workspace(MEMBERS libs/greet tools/cli)
```

A workspace with no members is valid.

## Tooling

| Function | Purpose |
| --- | --- |
| `configure_project_tooling()` | Uses `lld` when available; enables clang-tidy / cppcheck when `_ENABLE_CLANG_TIDY` / `_ENABLE_CPPCHECK` are ON. |
| `configure_target(target)` | Applies the project warnings, sanitizers (`_SANITIZERS`) and coverage (`_ENABLE_COVERAGE`). `package()` calls it for you. See below. |
| `add_coverage_report_target()` | `coverage-report` target via `gcovr`. |
| `add_format_target()` | `format` target via `clang-format`. |
| `install_project_target(target)` / `install_project_headers(dir)` | Install and export rules when `_INSTALL` is ON. |

### What `configure_target()` turns on

- **Warnings (GCC and Clang):** `${PROJECT_NAME_UPPER}_COMPILE_DEFINITIONS` plus `-Wconversion
  -Wsign-conversion -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Woverloaded-virtual
  -Wnull-dereference -Wdouble-promotion -Wformat=2 -Wimplicit-fallthrough -Wcast-align`. MSVC gets
  `/W4 /permissive- /WX`.
- **Bounds checks in Debug builds:** `_GLIBCXX_ASSERTIONS`, so libstdc++ aborts with a message on
  out-of-range `operator[]`, `front()` on an empty container and similar, much like a Rust panic.
  It is ABI-compatible and has no effect with libc++, whose own hardening mode toolchains such as
  Nix already enable.
- **Coverage** (`_ENABLE_COVERAGE`): `--coverage`. Use a Debug build; `add_coverage_report_target()`
  warns about optimized ones.

## Development

```bash
nix flake check   # configures, builds and tests the projects in tests/
```

## License

[MIT](./LICENSE).
