#include "include/adg_share/adg_share_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "adg_share_plugin.h"

void AdgSharePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  adg_share::AdgSharePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
