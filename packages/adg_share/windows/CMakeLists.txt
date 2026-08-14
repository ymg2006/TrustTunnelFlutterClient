cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "adg_share")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "adg_share_plugin")

list(APPEND PLUGIN_SOURCES
  "adg_share_plugin.cpp"
  "adg_share_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/adg_share/adg_share_plugin_c_api.h"
  "adg_share_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL
  _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  runtimeobject
  ole32
  shell32)

set(adg_share_bundled_libraries
  ""
  PARENT_SCOPE
)
