# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)
if (POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

# Project-level configuration.
set(PROJECT_NAME "vpn_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "vpn_plugin_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "vpn_plugin.cc"
)

include(FetchContent)
set(_trusttunnel_cached_source "${CMAKE_BINARY_DIR}/_deps/trusttunnel_client-src")
if (EXISTS "${_trusttunnel_cached_source}/trusttunnel/CMakeLists.txt")
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

set(_trusttunnel_conan_generators
  "${CMAKE_BINARY_DIR}/trusttunnel-conan/build/Release/generators")
if (NOT EXISTS "${_trusttunnel_conan_generators}")
  find_program(_trusttunnel_conan_executable conan)
  if (NOT _trusttunnel_conan_executable)
    message(FATAL_ERROR "Conan is required to build the TrustTunnel Linux adapter. Install Conan 2 and rerun the build.")
  endif()
  find_package(Python3 COMPONENTS Interpreter REQUIRED)
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${trusttunnel_client_SOURCE_DIR}/scripts/bootstrap_conan_deps.py"
    RESULT_VARIABLE _trusttunnel_bootstrap_result
    COMMAND_ECHO STDOUT)
  if (NOT _trusttunnel_bootstrap_result EQUAL 0)
    message(FATAL_ERROR "Conan dependency bootstrap failed for the TrustTunnel Linux adapter.")
  endif()
  execute_process(
    COMMAND "${_trusttunnel_conan_executable}" install "${trusttunnel_client_SOURCE_DIR}"
      --output-folder "${CMAKE_BINARY_DIR}/trusttunnel-conan"
      --build missing
      -s build_type=Release
    RESULT_VARIABLE _trusttunnel_conan_result
    COMMAND_ECHO STDOUT)
  if (NOT _trusttunnel_conan_result EQUAL 0)
    message(FATAL_ERROR "Conan dependency install failed for the TrustTunnel Linux adapter.")
  endif()
endif()
if (EXISTS "${_trusttunnel_conan_generators}")
  list(APPEND CMAKE_PREFIX_PATH "${_trusttunnel_conan_generators}")
  list(APPEND CMAKE_MODULE_PATH "${_trusttunnel_conan_generators}")
  set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
add_subdirectory(
  "${trusttunnel_client_SOURCE_DIR}"
  "${CMAKE_BINARY_DIR}/trusttunnel_linux_core")

add_executable(trusttunnel_vpn_helper
  "trusttunnel_vpn_helper.cc"
)
apply_standard_settings(trusttunnel_vpn_helper)
target_compile_features(trusttunnel_vpn_helper PRIVATE cxx_std_20)
target_link_libraries(trusttunnel_vpn_helper PRIVATE vpnlibs_trusttunnel)
target_include_directories(trusttunnel_vpn_helper PRIVATE
  "${trusttunnel_client_SOURCE_DIR}/trusttunnel/include"
  "${trusttunnel_client_SOURCE_DIR}/core/include"
  "${trusttunnel_client_SOURCE_DIR}/net/include"
  "${trusttunnel_client_SOURCE_DIR}/common/include")
target_compile_definitions(trusttunnel_vpn_helper PRIVATE TRUSTTUNNEL_NATIVE_BACKEND)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_20)

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
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE vpnlibs_trusttunnel)
add_dependencies(${PLUGIN_NAME} trusttunnel_vpn_helper)
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${trusttunnel_client_SOURCE_DIR}/trusttunnel/include"
  "${trusttunnel_client_SOURCE_DIR}/core/include"
  "${trusttunnel_client_SOURCE_DIR}/net/include"
  "${trusttunnel_client_SOURCE_DIR}/common/include")
target_compile_definitions(${PLUGIN_NAME} PRIVATE TRUSTTUNNEL_NATIVE_BACKEND)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(vpn_plugin_bundled_libraries
  "$<TARGET_FILE:trusttunnel_vpn_helper>"
  PARENT_SCOPE
)

# === Tests ===
# These unit tests can be run from a terminal after building the example.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
if(${CMAKE_VERSION} VERSION_LESS "3.11.0")
message("Unit tests require CMake 3.11.0 or later")
else()
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

# The plugin's exported API is not very useful for unit testing, so build the
# sources directly into the test binary rather than using the shared library.
add_executable(${TEST_RUNNER}
  test/vpn_plugin_test.cc
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter)
target_link_libraries(${TEST_RUNNER} PRIVATE PkgConfig::GTK)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})

endif()  # CMake version check
endif()  # include_${PROJECT_NAME}_tests
