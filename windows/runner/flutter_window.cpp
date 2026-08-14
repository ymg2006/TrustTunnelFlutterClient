#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <windows.h>

#include <algorithm>
#include <map>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr wchar_t kRunRegistryKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kAppRegistryKey[] = L"Software\\TrustTunnel";
constexpr wchar_t kRunValueName[] = L"TrustTunnel";
constexpr wchar_t kOpenMainWindowOnLoginValueName[] =
    L"OpenMainWindowOnLogin";
constexpr wchar_t kLoginLaunchArgument[] = L"--login-item";

std::wstring GetExecutablePath() {
  wchar_t buffer[MAX_PATH];
  DWORD length = GetModuleFileNameW(nullptr, buffer, MAX_PATH);
  if (length == 0) {
    return L"";
  }

  return std::wstring(buffer, length);
}

std::wstring GetLaunchAtLoginCommand() {
  return L"\"" + GetExecutablePath() + L"\" " + kLoginLaunchArgument;
}

bool IsLoginItemLaunch() {
  int argc = 0;
  LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return false;
  }

  const std::wstring login_argument(kLoginLaunchArgument);
  bool found = false;
  for (int i = 1; i < argc; ++i) {
    if (login_argument == argv[i]) {
      found = true;
      break;
    }
  }

  LocalFree(argv);
  return found;
}

bool ReadRegistryDword(HKEY root, const wchar_t* subkey,
                       const wchar_t* value_name, DWORD fallback) {
  DWORD value = fallback;
  DWORD value_size = sizeof(value);
  LSTATUS status =
      RegGetValueW(root, subkey, value_name, RRF_RT_REG_DWORD, nullptr, &value,
                   &value_size);
  if (status != ERROR_SUCCESS) {
    return fallback != 0;
  }

  return value != 0;
}

LSTATUS WriteRegistryDword(HKEY root, const wchar_t* subkey,
                           const wchar_t* value_name, bool value) {
  HKEY key = nullptr;
  LSTATUS status =
      RegCreateKeyExW(root, subkey, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key,
                      nullptr);
  if (status != ERROR_SUCCESS) {
    return status;
  }

  DWORD dword_value = value ? 1 : 0;
  status = RegSetValueExW(key, value_name, 0, REG_DWORD,
                          reinterpret_cast<const BYTE*>(&dword_value),
                          sizeof(dword_value));
  RegCloseKey(key);
  return status;
}

bool IsLaunchAtLoginEnabled() {
  DWORD value_size = 0;
  LSTATUS status =
      RegGetValueW(HKEY_CURRENT_USER, kRunRegistryKey, kRunValueName,
                   RRF_RT_REG_SZ, nullptr, nullptr, &value_size);
  if (status != ERROR_SUCCESS || value_size == 0) {
    return false;
  }

  std::wstring value(value_size / sizeof(wchar_t), L'\0');
  status = RegGetValueW(HKEY_CURRENT_USER, kRunRegistryKey, kRunValueName,
                        RRF_RT_REG_SZ, nullptr, value.data(), &value_size);
  if (status != ERROR_SUCCESS) {
    return false;
  }

  return value.find(GetExecutablePath()) != std::wstring::npos;
}

LSTATUS SetLaunchAtLoginEnabled(bool enabled) {
  if (!enabled) {
    HKEY key = nullptr;
    LSTATUS status =
        RegOpenKeyExW(HKEY_CURRENT_USER, kRunRegistryKey, 0, KEY_SET_VALUE,
                      &key);
    if (status == ERROR_FILE_NOT_FOUND) {
      return ERROR_SUCCESS;
    }
    if (status != ERROR_SUCCESS) {
      return status;
    }

    status = RegDeleteValueW(key, kRunValueName);
    RegCloseKey(key);

    return status == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : status;
  }

  HKEY key = nullptr;
  LSTATUS status =
      RegCreateKeyExW(HKEY_CURRENT_USER, kRunRegistryKey, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr);
  if (status != ERROR_SUCCESS) {
    return status;
  }

  const std::wstring command = GetLaunchAtLoginCommand();
  status = RegSetValueExW(
      key, kRunValueName, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
  return status;
}

bool GetOpenMainWindowOnLogin() {
  return ReadRegistryDword(HKEY_CURRENT_USER, kAppRegistryKey,
                           kOpenMainWindowOnLoginValueName, 0);
}

bool GetEnabledArgument(const flutter::MethodCall<flutter::EncodableValue>& call,
                        flutter::MethodResult<flutter::EncodableValue>* result,
                        bool* enabled) {
  const auto* arguments =
      std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    result->Error("invalid_arguments", "Expected an arguments map.");
    return false;
  }

  const auto enabled_it = arguments->find(flutter::EncodableValue("enabled"));
  if (enabled_it == arguments->end()) {
    result->Error("invalid_arguments", "Expected enabled argument.");
    return false;
  }

  const bool* enabled_value = std::get_if<bool>(&enabled_it->second);
  if (enabled_value == nullptr) {
    result->Error("invalid_arguments", "Expected enabled to be a boolean.");
    return false;
  }

  *enabled = *enabled_value;
  return true;
}

void RegisterLaunchAtLoginChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "trusttunnel/launch_at_login",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "isEnabled") {
          result->Success(flutter::EncodableValue(IsLaunchAtLoginEnabled()));
          return;
        }

        if (call.method_name() == "setEnabled") {
          bool enabled = false;
          if (!GetEnabledArgument(call, result.get(), &enabled)) {
            return;
          }

          LSTATUS status = SetLaunchAtLoginEnabled(enabled);
          if (status != ERROR_SUCCESS) {
            result->Error("launch_at_login_error",
                          "Unable to update Windows launch-at-login registry "
                          "entry.",
                          flutter::EncodableValue(static_cast<int>(status)));
            return;
          }

          result->Success();
          return;
        }

        result->NotImplemented();
      });

  channel.release();
}

void RegisterWindowsMainWindowChannel(flutter::BinaryMessenger* messenger,
                                      HWND window) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "trusttunnel/windows_main_window",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [window](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) {
        if (call.method_name() == "shouldShowMainWindowOnLaunch") {
          result->Success(
              flutter::EncodableValue(!IsLoginItemLaunch() ||
                                      GetOpenMainWindowOnLogin()));
          return;
        }

        if (call.method_name() == "show") {
          ShowWindow(window, SW_SHOWNORMAL);
          SetForegroundWindow(window);
          result->Success();
          return;
        }

        if (call.method_name() == "hide") {
          ShowWindow(window, SW_HIDE);
          result->Success();
          return;
        }

        if (call.method_name() == "getOpenMainWindowOnLogin") {
          result->Success(flutter::EncodableValue(GetOpenMainWindowOnLogin()));
          return;
        }

        if (call.method_name() == "setOpenMainWindowOnLogin") {
          bool enabled = false;
          if (!GetEnabledArgument(call, result.get(), &enabled)) {
            return;
          }

          LSTATUS status = WriteRegistryDword(
              HKEY_CURRENT_USER, kAppRegistryKey,
              kOpenMainWindowOnLoginValueName, enabled);
          if (status != ERROR_SUCCESS) {
            result->Error("windows_main_window_error",
                          "Unable to update Windows launch presentation "
                          "registry entry.",
                          flutter::EncodableValue(static_cast<int>(status)));
            return;
          }

          result->Success();
          return;
        }

        result->NotImplemented();
      });

  channel.release();
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterLaunchAtLoginChannel(flutter_controller_->engine()->messenger());
  RegisterWindowsMainWindowChannel(flutter_controller_->engine()->messenger(),
                                   GetHandle());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Request the first frame so the Dart-side window controller can apply the
  // launch visibility policy through window_manager.
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
