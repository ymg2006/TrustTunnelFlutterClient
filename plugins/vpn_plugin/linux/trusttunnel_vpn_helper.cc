#include <atomic>
#include <condition_variable>
#include <csignal>
#include <fstream>
#include <mutex>
#include <string>

#include <toml++/toml.h>

#include "vpn/trusttunnel/client.h"
#include "vpn/trusttunnel/config.h"
#include "vpn/vpn.h"

namespace {

std::atomic_bool keep_running{true};
std::condition_variable waiter;
std::mutex waiter_mutex;

void signal_handler(int) {
  keep_running = false;
  waiter.notify_all();
}

std::string read_file(const char* path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    return {};
  }

  return std::string(
      std::istreambuf_iterator<char>(input),
      std::istreambuf_iterator<char>());
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 3 || std::string(argv[1]) != "--config") {
    return 2;
  }

  std::signal(SIGINT, signal_handler);
  std::signal(SIGTERM, signal_handler);

  const auto config_text = read_file(argv[2]);
  if (config_text.empty()) {
    return 3;
  }

  auto table = toml::parse(config_text);
  auto config = ag::TrustTunnelConfig::build_config(table);
  if (!config.has_value()) {
    return 4;
  }

  ag::VpnCallbacks callbacks = {};
  callbacks.protect_handler = [](ag::SocketProtectEvent*) {};
  callbacks.verify_handler = [](ag::VpnVerifyCertificateEvent* event) {
    if (event) {
      event->result = 0;
    }
  };
  callbacks.state_changed_handler = [](ag::VpnStateChangedEvent* event) {
    if (event && event->state == ag::VPN_SS_DISCONNECTED && event->error.code != 0) {
      keep_running = false;
      waiter.notify_all();
    }
  };
  callbacks.client_output_handler = [](ag::VpnClientOutputEvent*) {};
  callbacks.connection_info_handler = [](ag::VpnConnectionInfoEvent*) {};

  ag::TrustTunnelClient client(std::move(config.value()), std::move(callbacks));
  auto result = client.connect(ag::TrustTunnelClient::AutoSetup{});
  if (result) {
    return 5;
  }

  std::unique_lock<std::mutex> lock(waiter_mutex);
  waiter.wait(lock, [] { return !keep_running.load(); });

  client.disconnect();
  return 0;
}
