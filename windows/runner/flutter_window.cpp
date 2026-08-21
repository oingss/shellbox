#include "flutter_window.h"

#include <fstream>
#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
// Mirrors the logging helper in runner/main.cpp — kept file-local and
// dependency-free on purpose. Appends to the same native_startup.log so the
// whole native startup sequence reads as one timeline. This exists to
// pinpoint crashes inside engine/plugin startup (e.g. a plugin whose
// registrar throws or access-violates during RegisterPlugins), which
// otherwise fail completely silently — the process just disappears with
// exit code c000041d and no further output.
void AppendNativeLog(const std::wstring& message) {
  ::OutputDebugStringW((message + L"\n").c_str());
  wchar_t exe_path[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) return;
  std::wstring path(exe_path, length);
  size_t last_slash = path.find_last_of(L"\\/");
  if (last_slash == std::wstring::npos) return;
  std::wstring log_path =
      path.substr(0, last_slash) + L"\\logs\\native_startup.log";
  std::wofstream log(log_path, std::ios::out | std::ios::app);
  if (log.is_open()) {
    log << message << std::endl;
  }
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  AppendNativeLog(L"[native] FlutterWindow::OnCreate entered");
  if (!Win32Window::OnCreate()) {
    AppendNativeLog(L"[native] Win32Window::OnCreate FAILED");
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  AppendNativeLog(L"[native] constructing FlutterViewController "
                   L"(this starts the Flutter engine + Dart VM)");
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  AppendNativeLog(L"[native] FlutterViewController constructed");
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    AppendNativeLog(L"[native] engine() or view() is null after construction — "
                     L"engine failed to start (check flutter_assets/ and "
                     L"icudtl.dat are present next to the exe under data/)");
    return false;
  }
  AppendNativeLog(L"[native] engine + view OK, calling RegisterPlugins "
                   L"— if the log stops here, a plugin's native registrar "
                   L"is crashing (check which plugins are in pubspec.yaml: "
                   L"sqlite3_flutter_libs / file_picker / window_manager / "
                   L"tray_manager / flutter_secure_storage etc.)");
  RegisterPlugins(flutter_controller_->engine());
  AppendNativeLog(L"[native] RegisterPlugins returned OK");
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    AppendNativeLog(L"[native] first frame rendered, showing window");
    this->Show();
  });

  AppendNativeLog(L"[native] FlutterWindow::OnCreate returning true");
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> processed =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (processed) {
      return *processed;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}