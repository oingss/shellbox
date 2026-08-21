#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <dwmapi.h>

#include <functional>
#include <memory>
#include <string>

// A utility class for managing a window.
class Win32Window {
 public:
  Win32Window();
  virtual ~Win32Window();

  struct Size {
   public:
    Size(int width, int height) : width(width), height(height) {}

    const int width;
    const int height;
  };

  struct Point {
   public:
    Point(int x, int y) : x(x), y(y) {}

    const int x;
    const int y;
  };

  // Creates and shows a win32 window with |title| and position and size using
  // |origin| and |size|. New windows are shown hidden by default. Returns false
  // if the window could not be created.
  bool CreateAndShow(const std::wstring& title,
                     const Point& origin,
                     const Size& size);

  // Destroys the window.
  void Destroy();

  // Wrapper functions for Win32 window API.
  HWND GetHandle() const;
  void SetChildContent(HWND content);
  void SetQuitOnClose(bool quit_on_close);
  void Show();
  void Hide();
  RECT GetClientArea();
  void SetTitle(const std::wstring& title);
  void SetSize(const Size& size);

 protected:
  // If set to false, the window will be hidden instead of closing.
  bool quit_on_close_ = true;

  HWND window_ = nullptr;
  HWND child_content_ = nullptr;

  // The size of the window as last reported in WM_SIZE.
  int width_ = 0;
  int height_ = 0;

  // Minimum / maximum size of the window.
  Size min_size_{0, 0};
  Size max_size_{0, 0};

  // Margins of the window frame.
  MARGINS margins_{0, 0, 0, 0};

  // Does-nothing handler for virtual methods.
  virtual bool OnCreate();
  virtual void OnDestroy();

  // Virtual handler for Win32 window message.
  virtual LRESULT MessageHandler(HWND hwnd, UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

 private:
  void SendSizeMessage(int width, int height);

  // Processes the window message.
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;
};

#endif  // RUNNER_WIN32_WINDOW_H_