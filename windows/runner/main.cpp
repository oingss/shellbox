#include <flutter/dart_project.h>
#include <windows.h>

#include <fstream>
#include <string>

#include "flutter_window.h"
#include "utils.h"

// -----------------------------------------------------------------------
// Minimal native crash-debugging log, deliberately NOT using any Flutter/
// Dart facility, so it can catch failures that happen before the Dart VM
// or even the Flutter engine has finished initializing (e.g. a native
// c000041d-style crash with no Dart-side output at all). Written next to
// the executable, in a "logs" subfolder, same convention as the Dart-side
// FileLogger (core/utils/file_logger.dart) so both logs sit together.
// Every line is flushed immediately: a buffered stream is useless if the
// process is about to be killed by the OS a few instructions later.
// -----------------------------------------------------------------------
namespace {

std::wofstream g_native_log;

std::wstring GetExeDirectory() {
  wchar_t path[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return L".";
  }
  std::wstring full_path(path, length);
  size_t last_slash = full_path.find_last_of(L"\\/");
  if (last_slash == std::wstring::npos) {
    return L".";
  }
  return full_path.substr(0, last_slash);
}

void NativeLogInit() {
  std::wstring dir = GetExeDirectory() + L"\\logs";
  ::CreateDirectoryW(dir.c_str(), nullptr);  // no-op if it already exists.
  std::wstring path = dir + L"\\native_startup.log";
  g_native_log.open(path, std::ios::out | std::ios::trunc);
}

void NativeLog(const std::wstring& message) {
  // Always mirror to the debugger/console too — free, and helps when a
  // debugger IS attached even if the file write somehow fails.
  ::OutputDebugStringW((message + L"\n").c_str());
  if (g_native_log.is_open()) {
    g_native_log << message << std::endl;  // std::endl flushes.
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE parent,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  NativeLogInit();
  NativeLog(L"[native] wWinMain entered");

  // Attach to console when present (e.g., 'flutter run') or create a
  // console window when running a single instance with commands.
  if (::AttachConsole(ATTACH_PARENT_PROCESS) ||
      ::IsDebuggerPresent()) {
    ::OutputDebugString(L"Attached to console.\n");
  }
  NativeLog(L"[native] console attach step done");

  // Set up project structure for the Flutter engine.
  NativeLog(L"[native] constructing flutter::DartProject");
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(GetCommandLineArguments());
  NativeLog(L"[native] DartProject constructed");

  // The FlutterWindow owns the FlutterViewController internally (created in
  // OnCreate); do not construct one here.
  NativeLog(L"[native] constructing FlutterWindow");
  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  NativeLog(L"[native] calling CreateAndShow — this is where the Flutter "
            L"engine + Dart VM actually start; if the log stops here, the "
            L"crash is inside engine startup");
  if (!window.CreateAndShow(L"ShellBox", origin, size)) {
    NativeLog(L"[native] CreateAndShow returned FALSE");
    return EXIT_FAILURE;
  }
  NativeLog(L"[native] CreateAndShow returned TRUE — window should be visible");
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  NativeLog(L"[native] message loop exited normally");
  return EXIT_SUCCESS;
}