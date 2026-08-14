#include "adg_share_plugin.h"

#include <flutter/encodable_value.h>
#include <ShObjIdl_core.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.h>

#include <vector>

namespace adg_share {
namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::ApplicationModel::DataTransfer::DataTransferManager;
using winrt::Windows::ApplicationModel::DataTransfer::DataRequestedEventArgs;
using winrt::Windows::Foundation::Collections::IVector;
using winrt::Windows::Storage::IStorageItem;
using winrt::Windows::Storage::StorageFile;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  const int size = MultiByteToWideChar(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
  std::wstring output(size, L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), output.data(), size);
  return output;
}

EncodableValue ShareStatus(const std::string& status) {
  return EncodableValue(EncodableMap{
      {EncodableValue("status"), EncodableValue(status)},
  });
}

const EncodableValue* FindMapValue(
    const EncodableMap& map,
    const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &it->second;
}

}  // namespace

void AdgSharePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(),
      "adg_share",
      &flutter::StandardMethodCodec::GetInstance());

  HWND hwnd = nullptr;
  if (registrar->GetView()) {
    hwnd = registrar->GetView()->GetNativeWindow();
  }

  auto plugin = std::make_unique<AdgSharePlugin>(hwnd);
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](
          const auto& call,
          auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AdgSharePlugin::AdgSharePlugin(HWND hwnd) : hwnd_(hwnd) {}

AdgSharePlugin::~AdgSharePlugin() = default;

void AdgSharePlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (method_call.method_name() != "share") {
    result->NotImplemented();
    return;
  }

  const auto file_path = ExtractFirstFilePath(method_call.arguments());
  if (!file_path.has_value()) {
    result->Success(ShareStatus("unavailable"));
    return;
  }

  const auto title = ExtractTitle(method_call.arguments())
      .value_or("Share");

  if (!ShowShareUi(file_path.value(), title)) {
    result->Success(ShareStatus("unavailable"));
    return;
  }

  result->Success(ShareStatus("success"));
}

std::optional<std::wstring> AdgSharePlugin::ExtractFirstFilePath(
    const EncodableValue* arguments) const {
  if (!arguments || !std::holds_alternative<EncodableMap>(*arguments)) {
    return std::nullopt;
  }

  const auto& payload = std::get<EncodableMap>(*arguments);
  const auto* content_value = FindMapValue(payload, "content");
  if (!content_value || !std::holds_alternative<EncodableList>(*content_value)) {
    return std::nullopt;
  }

  for (const auto& item_value : std::get<EncodableList>(*content_value)) {
    if (!std::holds_alternative<EncodableMap>(item_value)) {
      continue;
    }
    const auto& item = std::get<EncodableMap>(item_value);
    const auto* type_value = FindMapValue(item, "type");
    const auto* path_value = FindMapValue(item, "path");
    if (!type_value || !path_value ||
        !std::holds_alternative<std::string>(*type_value) ||
        !std::holds_alternative<std::string>(*path_value)) {
      continue;
    }
    if (std::get<std::string>(*type_value) == "file") {
      return Utf8ToWide(std::get<std::string>(*path_value));
    }
  }

  return std::nullopt;
}

std::optional<std::string> AdgSharePlugin::ExtractTitle(
    const EncodableValue* arguments) const {
  if (!arguments || !std::holds_alternative<EncodableMap>(*arguments)) {
    return std::nullopt;
  }

  const auto& payload = std::get<EncodableMap>(*arguments);
  const auto* subject = FindMapValue(payload, "subject");
  if (subject && std::holds_alternative<std::string>(*subject) &&
      !std::get<std::string>(*subject).empty()) {
    return std::get<std::string>(*subject);
  }

  const auto* chooser_title = FindMapValue(payload, "chooserTitle");
  if (chooser_title && std::holds_alternative<std::string>(*chooser_title) &&
      !std::get<std::string>(*chooser_title).empty()) {
    return std::get<std::string>(*chooser_title);
  }

  return std::nullopt;
}

bool AdgSharePlugin::ShowShareUi(
    const std::wstring& file_path,
    const std::string& title) {
  if (!hwnd_) {
    return false;
  }

  try {
    pending_share_file_ = StorageFile::GetFileFromPathAsync(file_path).get();
    pending_share_file_path_ = file_path;
    pending_share_title_ = Utf8ToWide(title);

    auto interop = winrt::get_activation_factory<DataTransferManager,
        IDataTransferManagerInterop>();

    if (has_data_requested_token_) {
      share_manager_.DataRequested(data_requested_token_);
      has_data_requested_token_ = false;
    }

    share_manager_ = nullptr;
    winrt::check_hresult(interop->GetForWindow(
        hwnd_,
        winrt::guid_of<DataTransferManager>(),
        winrt::put_abi(share_manager_)));

    data_requested_token_ = share_manager_.DataRequested(
        [this](
            DataTransferManager const& sender,
            DataRequestedEventArgs const& args) {
          auto request = args.Request();
          try {
            auto data = request.Data();
            data.Properties().Title(winrt::hstring(pending_share_title_));
            data.SetText(winrt::hstring(pending_share_file_path_));

            auto items = winrt::single_threaded_vector<IStorageItem>();
            items.Append(pending_share_file_);
            data.SetStorageItems(items);
          } catch (...) {
            request.FailWithDisplayText(L"Unable to prepare the selected file for sharing.");
          }
          sender.DataRequested(data_requested_token_);
          has_data_requested_token_ = false;
        });
    has_data_requested_token_ = true;

    winrt::check_hresult(interop->ShowShareUIForWindow(hwnd_));
    return true;
  } catch (...) {
    return false;
  }
}

}  // namespace adg_share
