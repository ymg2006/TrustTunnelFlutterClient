#ifndef FLUTTER_PLUGIN_ADG_SHARE_PLUGIN_H_
#define FLUTTER_PLUGIN_ADG_SHARE_PLUGIN_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winrt/Windows.ApplicationModel.DataTransfer.h>
#include <winrt/Windows.Storage.h>
#include <winrt/base.h>

#include <memory>
#include <optional>
#include <string>

namespace adg_share {

class AdgSharePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit AdgSharePlugin(HWND hwnd);
  ~AdgSharePlugin() override;

  AdgSharePlugin(const AdgSharePlugin&) = delete;
  AdgSharePlugin& operator=(const AdgSharePlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::optional<std::wstring> ExtractFirstFilePath(
      const flutter::EncodableValue* arguments) const;

  std::optional<std::string> ExtractTitle(
      const flutter::EncodableValue* arguments) const;

  bool ShowShareUi(const std::wstring& file_path, const std::string& title);

  HWND hwnd_;
  winrt::Windows::ApplicationModel::DataTransfer::DataTransferManager share_manager_{nullptr};
  winrt::Windows::Storage::StorageFile pending_share_file_{nullptr};
  std::wstring pending_share_file_path_;
  std::wstring pending_share_title_;
  winrt::event_token data_requested_token_{};
  bool has_data_requested_token_ = false;
};

}  // namespace adg_share

#endif  // FLUTTER_PLUGIN_ADG_SHARE_PLUGIN_H_
