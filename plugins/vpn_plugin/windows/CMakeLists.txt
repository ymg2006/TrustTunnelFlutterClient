# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)
if (POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

# Project-level configuration.
set(PROJECT_NAME "vpn_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "vpn_plugin_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "vpn_plugin.cpp"
  "vpn_plugin.h"
  "runner/platform_api.g.cpp"
  "runner/platform_api.g.h"
)

# Build and link the native TrustTunnel Windows adapter. This keeps the Windows
# app on the same native backend model as mobile rather than launching the CLI.
file(GLOB _python_appdata_scripts "$ENV{APPDATA}/Python/Python*/Scripts")
file(GLOB _python_localappdata_scripts "$ENV{LOCALAPPDATA}/Python/*/Scripts")
foreach (_python_scripts_dir
    IN LISTS _python_appdata_scripts _python_localappdata_scripts)
  if (IS_DIRECTORY "${_python_scripts_dir}")
    set(ENV{PATH} "${_python_scripts_dir};$ENV{PATH}")
  endif()
endforeach()

include(FetchContent)
set(_trusttunnel_cached_source "${CMAKE_BINARY_DIR}/_deps/trusttunnel_client-src")
if (EXISTS "${_trusttunnel_cached_source}/platform/windows/CMakeLists.txt")
  set(trusttunnel_client_SOURCE_DIR "${_trusttunnel_cached_source}")
else()
  FetchContent_Declare(
    trusttunnel_client
    GIT_REPOSITORY https://github.com/TrustTunnel/TrustTunnelClient.git
    GIT_TAG e365309c7d6ad92a0f92096e613f9acd06fd1d5a
  )

  if (POLICY CMP0169)
    cmake_policy(SET CMP0169 OLD)
  endif()
  FetchContent_GetProperties(trusttunnel_client)
  if (NOT trusttunnel_client_POPULATED)
    FetchContent_Populate(trusttunnel_client)
  endif()
endif()

get_filename_component(_trusttunnel_cmake_dir "${CMAKE_COMMAND}" DIRECTORY)
set(ENV{PATH} "${_trusttunnel_cmake_dir};$ENV{PATH}")
get_filename_component(_trusttunnel_cmake_root "${_trusttunnel_cmake_dir}" DIRECTORY)
if (EXISTS "${_trusttunnel_cmake_root}/Ninja/ninja.exe")
  set(ENV{PATH} "${_trusttunnel_cmake_root}/Ninja;$ENV{PATH}")
endif()
if (CMAKE_CXX_COMPILER)
  get_filename_component(_trusttunnel_msvc_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
  set(ENV{PATH} "${_trusttunnel_msvc_dir};$ENV{PATH}")
endif()

set(_trusttunnel_conan_generators
  "${CMAKE_BINARY_DIR}/trusttunnel-conan/build/Release/generators")
if (NOT EXISTS "${_trusttunnel_conan_generators}")
  find_program(_trusttunnel_conan_executable conan)
  if (NOT _trusttunnel_conan_executable)
    message(FATAL_ERROR "Conan is required to build the TrustTunnel Windows adapter. Install Conan 2 and rerun the build.")
  endif()
  find_package(Python3 COMPONENTS Interpreter REQUIRED)
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/bootstrap_trusttunnel_conan.py" "${trusttunnel_client_SOURCE_DIR}"
    RESULT_VARIABLE _trusttunnel_bootstrap_result
    COMMAND_ECHO STDOUT)
  if (NOT _trusttunnel_bootstrap_result EQUAL 0)
    message(FATAL_ERROR "Conan dependency bootstrap failed for the TrustTunnel Windows adapter.")
  endif()
  execute_process(
    COMMAND "${_trusttunnel_conan_executable}" install "${trusttunnel_client_SOURCE_DIR}"
      --output-folder "${CMAKE_BINARY_DIR}/trusttunnel-conan"
      --build missing
      -s build_type=Release
      -s compiler.cppstd=17
      -s compiler.runtime=static
      -s compiler.runtime_type=Release
      -c tools.cmake.cmaketoolchain:generator=Ninja
    RESULT_VARIABLE _trusttunnel_conan_result
    COMMAND_ECHO STDOUT)
  if (NOT _trusttunnel_conan_result EQUAL 0)
    message(FATAL_ERROR "Conan dependency install failed for the TrustTunnel Windows adapter.")
  endif()
endif()
if (EXISTS "${_trusttunnel_conan_generators}")
  list(APPEND CMAKE_PREFIX_PATH "${_trusttunnel_conan_generators}")
  list(APPEND CMAKE_MODULE_PATH "${_trusttunnel_conan_generators}")
  set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
endif()

set(_vpn_plugin_saved_c_flags "${CMAKE_C_FLAGS}")
set(_vpn_plugin_saved_cxx_flags "${CMAKE_CXX_FLAGS}")
set(_vpn_plugin_saved_c_flags_debug "${CMAKE_C_FLAGS_DEBUG}")
set(_vpn_plugin_saved_cxx_flags_debug "${CMAKE_CXX_FLAGS_DEBUG}")
set(_vpn_plugin_saved_c_flags_release "${CMAKE_C_FLAGS_RELEASE}")
set(_vpn_plugin_saved_cxx_flags_release "${CMAKE_CXX_FLAGS_RELEASE}")
set(_vpn_plugin_saved_c_flags_relwithdebinfo "${CMAKE_C_FLAGS_RELWITHDEBINFO}")
set(_vpn_plugin_saved_cxx_flags_relwithdebinfo "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
set(_vpn_plugin_saved_c_flags_minsizerel "${CMAKE_C_FLAGS_MINSIZEREL}")
set(_vpn_plugin_saved_cxx_flags_minsizerel "${CMAKE_CXX_FLAGS_MINSIZEREL}")

foreach (_trusttunnel_flag_var
    CMAKE_C_FLAGS CMAKE_CXX_FLAGS
    CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG
    CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELEASE
    CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_CXX_FLAGS_RELWITHDEBINFO
    CMAKE_C_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_MINSIZEREL)
  string(REPLACE "/MDd" "/MTd" ${_trusttunnel_flag_var} "${${_trusttunnel_flag_var}}")
  string(REPLACE "/MD" "/MT" ${_trusttunnel_flag_var} "${${_trusttunnel_flag_var}}")
endforeach()

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
add_subdirectory(
  "${trusttunnel_client_SOURCE_DIR}/platform/windows"
  "${CMAKE_BINARY_DIR}/trusttunnel_windows_adapter")
foreach (_trusttunnel_target
    vpn_easy vpn_easy_a vpn_easy_service
    vpn_easy_test vpn_easy_service_test vpn_easy_pipe_test)
  if (TARGET ${_trusttunnel_target})
    set_target_properties(${_trusttunnel_target} PROPERTIES
      MSVC_RUNTIME_LIBRARY "MultiThreaded")
  endif()
endforeach()
foreach (_trusttunnel_test_target
    vpn_easy_service vpn_easy_test vpn_easy_service_test vpn_easy_pipe_test)
  if (TARGET ${_trusttunnel_test_target})
    set_target_properties(${_trusttunnel_test_target} PROPERTIES
      EXCLUDE_FROM_ALL TRUE
      EXCLUDE_FROM_DEFAULT_BUILD TRUE)
  endif()
endforeach()

set(CMAKE_C_FLAGS "${_vpn_plugin_saved_c_flags}")
set(CMAKE_CXX_FLAGS "${_vpn_plugin_saved_cxx_flags}")
set(CMAKE_C_FLAGS_DEBUG "${_vpn_plugin_saved_c_flags_debug}")
set(CMAKE_CXX_FLAGS_DEBUG "${_vpn_plugin_saved_cxx_flags_debug}")
set(CMAKE_C_FLAGS_RELEASE "${_vpn_plugin_saved_c_flags_release}")
set(CMAKE_CXX_FLAGS_RELEASE "${_vpn_plugin_saved_cxx_flags_release}")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "${_vpn_plugin_saved_c_flags_relwithdebinfo}")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${_vpn_plugin_saved_cxx_flags_relwithdebinfo}")
set(CMAKE_C_FLAGS_MINSIZEREL "${_vpn_plugin_saved_c_flags_minsizerel}")
set(CMAKE_CXX_FLAGS_MINSIZEREL "${_vpn_plugin_saved_cxx_flags_minsizerel}")

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/vpn_plugin/vpn_plugin_c_api.h"
  "vpn_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
target_link_libraries(${PLUGIN_NAME} PRIVATE vpn_easy)
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${trusttunnel_client_SOURCE_DIR}/platform/windows/include")
target_compile_definitions(${PLUGIN_NAME} PRIVATE TRUSTTUNNEL_NATIVE_BACKEND)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(vpn_plugin_bundled_libraries
  "$<TARGET_FILE:vpn_easy>"
  PARENT_SCOPE
)

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
add_executable(${TEST_RUNNER}
  test/vpn_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
