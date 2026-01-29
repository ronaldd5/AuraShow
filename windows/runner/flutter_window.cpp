#include "flutter_window.h"

#include <optional>

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/generated_plugin_registrant.h"
#include <just_audio_windows/just_audio_windows_plugin.h>

#include <media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h>
#include <media_kit_video/media_kit_video_plugin_c_api.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <video_player_win/video_player_win_plugin_c_api.h>
#include <volume_controller/volume_controller_plugin_c_api.h>

FlutterWindow::FlutterWindow(const flutter::DartProject &project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

// Track the primary engine.
namespace {
flutter::FlutterEngine *g_primary_engine = nullptr;

// Register plugins needed by secondary windows, excluding DesktopMultiWindow
// to avoid "main window already exists" errors.
void RegisterSecondaryPlugins(flutter::FlutterEngine *engine) {
  // MediaKitLibsWindowsVideoPluginCApiRegisterWithRegistrar(
  //     engine->GetRegistrarForPlugin("MediaKitLibsWindowsVideoPluginCApi"));
  // MediaKitVideoPluginCApiRegisterWithRegistrar(
  //     engine->GetRegistrarForPlugin("MediaKitVideoPluginCApi"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
      engine->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      engine->GetRegistrarForPlugin("UrlLauncherWindows"));
  VideoPlayerWinPluginCApiRegisterWithRegistrar(
      engine->GetRegistrarForPlugin("VideoPlayerWinPluginCApi"));
  VolumeControllerPluginCApiRegisterWithRegistrar(
      engine->GetRegistrarForPlugin("VolumeControllerPluginCApi"));
}
} // namespace

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    // Register plugins for secondary engines.
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *engine = flutter_view_controller->engine();

    // Register generic plugins (including window_manager)
    RegisterSecondaryPlugins(engine);

    // Register just_audio for secondary windows (background audio, projection
    // sound)
    JustAudioWindowsPluginRegisterWithRegistrar(
        engine->GetRegistrarForPlugin("JustAudioWindowsPlugin"));

    // --- NATIVE STYLING FIX FOR HEADLESS WINDOW ---
    // Directly modify the HWND to remove borders/titlebar
    auto view = flutter_view_controller->view();
    if (view) {
      HWND child_hwnd = view->GetNativeWindow();
      // Ensure we get the actual TOP LEVEL window (the frame)
      HWND hwnd = GetAncestor(child_hwnd, GA_ROOT);

      // Get current style
      LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);

      // Remove OVERLAPPEDWINDOW (Caption, ThickFrame, etc)
      style &= ~WS_OVERLAPPEDWINDOW;
      // Add POPUP (no chrome)
      style |= WS_POPUP;

      SetWindowLongPtr(hwnd, GWL_STYLE, style);

      // Notify change
      SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);

      // TRUE FULLSCREEN: Resize to cover the entire monitor (including taskbar)
      HMONITOR hMonitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      MONITORINFO mi = {sizeof(mi)};
      if (GetMonitorInfo(hMonitor, &mi)) {
        SetWindowPos(hwnd, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top,
                     mi.rcMonitor.right - mi.rcMonitor.left,
                     mi.rcMonitor.bottom - mi.rcMonitor.top,
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
      } else {
        // Fallback if monitor info fails
        ShowWindow(hwnd, SW_MAXIMIZE);
      }
    }
  });

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  g_primary_engine = flutter_controller_->engine();
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
  case WM_FONTCHANGE:
    flutter_controller_->engine()->ReloadSystemFonts();
    break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
