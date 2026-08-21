cmake_minimum_required(VERSION 3.14)
project(shellbox_flutter_runner LANGUAGES CXX)

set(BINARY_NAME "shellbox_flutter")

add_executable(${BINARY_NAME} WIN32
  "main.cpp"
  "flutter_window.cpp"
  "flutter_window.h"
  "runner.exe.manifest"
  "utils.cpp"
  "utils.h"
  "win32_window.cpp"
  "win32_window.h"
)

apply_standard_settings(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE "APPLICATION_ID=\"${APPLICATION_ID}\"")

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Resource files must be in the same directory as the executable when built.
set(RUNNER_RESOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/resources")
target_compile_definitions(${BINARY_NAME} PRIVATE "RESOURCE_DIR=\"${RUNNER_RESOURCE_DIR}\"")

# Windows 10 + Windows 11 required APIs / features.
target_compile_definitions(${BINARY_NAME} PRIVATE _WIN32_WINNT=0x0A00)
target_compile_definitions(${BINARY_NAME} PRIVATE UNICODE _UNICODE)

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE NOMINMAX)

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)