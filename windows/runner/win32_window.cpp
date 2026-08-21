#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// The number of Win32Window objects that currently exist.
int g_active_window_count = 0;

}  // namespace

bool Win32Window::CreateAndShow(const std::wstring& title, const Point& origin,
                                const Size& size) {
  if (window_ != nullptr) {
    return true;
  }

  HINSTANCE hinstance = ::GetModuleHandle(nullptr);

  WNDCLASS window_class = {};
  window_class.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kWindowClassName;
  window_class.style = CS_HREDRAW | CS_VREDRAW;

  ::RegisterClass(&window_class);

  HWND window = ::CreateWindowEx(
      WS_EX_APPWINDOW | WS_EX_WINDOWEDGE, kWindowClassName, title.c_str(),
      WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
      origin.x, origin.y, size.width, size.height, nullptr, nullptr, hinstance,
      this);

  if (window == nullptr) {
    return false;
  }

  // Use DWM frame extension for the default margins.
  ::DwmExtendFrameIntoClientArea(window, &(const_cast<MARGINS&>(margins_)));

  window_ = window;
  quit_on_close_ = true;

  // The window is kept hidden until the first Flutter frame is rendered.
  ::ShowWindow(window, SW_HIDE);

  return true;
}

void Win32Window::Destroy() {
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

void Win32Window::Show() {
  ::ShowWindow(window_, SW_SHOWNORMAL);
  ::SetForegroundWindow(window_);
}

void Win32Window::Hide() {
  ::ShowWindow(window_, SW_HIDE);
}

HWND Win32Window::GetHandle() const {
  return window_;
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  ::GetClientRect(window_, &frame);
  return frame;
}

void Win32Window::SetTitle(const std::wstring& title) {
  ::SetWindowText(window_, title.c_str());
}

void Win32Window::SetSize(const Size& size) {
  RECT frame;
  ::GetClientRect(window_, &frame);
  ::MoveWindow(window_, frame.left, frame.top, size.width, size.height, TRUE);
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {
  if (window_ == nullptr) {
    return;
  }
  ::DestroyWindow(window_);
  window_ = nullptr;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

void Win32Window::SendSizeMessage(int width, int height) {
  width_ = width;
  height_ = height;

  if (child_content_ != nullptr) {
    RECT frame = GetClientArea();
    ::MoveWindow(child_content_, frame.left, frame.top,
                 frame.right - frame.left, frame.bottom - frame.top, TRUE);
  }
}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CREATE:
      if (!OnCreate()) {
        return -1;
      }
      break;
    case WM_SIZE:
      SendSizeMessage(static_cast<int>(LOWORD(lparam)),
                      static_cast<int>(HIWORD(lparam)));
      break;
    case WM_DESTROY:
      OnDestroy();
      if (quit_on_close_) {
        ::PostQuitMessage(0);
      }
      break;
    case WM_CLOSE:
      ::DestroyWindow(hwnd);
      break;
    default:
      return ::DefWindowProc(hwnd, message, wparam, lparam);
  }
  return 0;
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  auto* that = reinterpret_cast<Win32Window*>(
      ::GetWindowLongPtr(window, GWLP_USERDATA));

  if (that == nullptr) {
    if (message == WM_NCCREATE) {
      auto* create_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
      that = static_cast<Win32Window*>(create_struct->lpCreateParams);
      ::SetWindowLongPtr(window, GWLP_USERDATA,
                         reinterpret_cast<LONG_PTR>(that));
    } else {
      return ::DefWindowProc(window, message, wparam, lparam);
    }
  }

  return that->MessageHandler(window, message, wparam, lparam);
}