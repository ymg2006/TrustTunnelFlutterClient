#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <glib/gstdio.h>
#include <cerrno>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {

constexpr char kAppName[] = "TrustTunnel";
constexpr char kLoginLaunchArgument[] = "--login-item";
constexpr char kLaunchPresentationGroup[] = "LaunchPresentation";
constexpr char kOpenMainWindowOnLoginKey[] = "OpenMainWindowOnLogin";

gchar* get_config_dir() {
  const gchar* xdg_config_home = g_getenv("XDG_CONFIG_HOME");
  if (xdg_config_home != nullptr && xdg_config_home[0] != '\0') {
    return g_strdup(xdg_config_home);
  }

  return g_build_filename(g_get_home_dir(), ".config", nullptr);
}

gchar* get_autostart_file_path() {
  g_autofree gchar* config_dir = get_config_dir();
  return g_build_filename(config_dir, "autostart", "trusttunnel.desktop", nullptr);
}

gchar* get_launch_presentation_file_path() {
  g_autofree gchar* config_dir = get_config_dir();
  return g_build_filename(config_dir, kAppName, "launch_presentation.ini", nullptr);
}

gchar* get_executable_path() {
  g_autofree gchar* executable_path = g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path != nullptr && executable_path[0] != '\0') {
    return g_steal_pointer(&executable_path);
  }

  const gchar* program_name = g_get_prgname();
  return g_strdup(program_name != nullptr ? program_name : "vpn");
}

bool is_login_item_launch(MyApplication* self) {
  if (self->dart_entrypoint_arguments == nullptr) {
    return false;
  }

  for (gchar** argument = self->dart_entrypoint_arguments; *argument != nullptr; ++argument) {
    if (g_strcmp0(*argument, kLoginLaunchArgument) == 0) {
      return true;
    }
  }

  return false;
}

bool get_open_main_window_on_login() {
  g_autofree gchar* path = get_launch_presentation_file_path();
  g_autoptr(GKeyFile) key_file = g_key_file_new();

  if (!g_key_file_load_from_file(key_file, path, G_KEY_FILE_NONE, nullptr)) {
    return false;
  }

  g_autoptr(GError) error = nullptr;
  gboolean enabled = g_key_file_get_boolean(
      key_file,
      kLaunchPresentationGroup,
      kOpenMainWindowOnLoginKey,
      &error);

  if (error != nullptr) {
    return false;
  }

  return enabled;
}

bool set_open_main_window_on_login(bool enabled, GError** error) {
  g_autofree gchar* path = get_launch_presentation_file_path();
  g_autofree gchar* directory = g_path_get_dirname(path);
  if (g_mkdir_with_parents(directory, 0700) != 0) {
    g_set_error(
        error,
        G_FILE_ERROR,
        g_file_error_from_errno(errno),
        "Failed to create TrustTunnel config directory");
    return false;
  }

  g_autoptr(GKeyFile) key_file = g_key_file_new();
  g_key_file_load_from_file(key_file, path, G_KEY_FILE_NONE, nullptr);
  g_key_file_set_boolean(
      key_file,
      kLaunchPresentationGroup,
      kOpenMainWindowOnLoginKey,
      enabled);

  gsize data_length = 0;
  g_autofree gchar* data = g_key_file_to_data(key_file, &data_length, error);
  if (data == nullptr) {
    return false;
  }

  return g_file_set_contents(path, data, data_length, error);
}

bool should_show_main_window_on_launch(MyApplication* self) {
  return !is_login_item_launch(self) || get_open_main_window_on_login();
}

bool is_launch_at_login_enabled() {
  g_autofree gchar* path = get_autostart_file_path();
  return g_file_test(path, G_FILE_TEST_IS_REGULAR);
}

bool set_launch_at_login_enabled(bool enabled, GError** error) {
  g_autofree gchar* path = get_autostart_file_path();

  if (!enabled) {
    if (g_remove(path) == 0 || errno == ENOENT) {
      return true;
    }

    g_set_error(
        error,
        G_FILE_ERROR,
        g_file_error_from_errno(errno),
        "Failed to remove TrustTunnel autostart entry");
    return false;
  }

  g_autofree gchar* directory = g_path_get_dirname(path);
  if (g_mkdir_with_parents(directory, 0700) != 0) {
    g_set_error(
        error,
        G_FILE_ERROR,
        g_file_error_from_errno(errno),
        "Failed to create XDG autostart directory");
    return false;
  }

  g_autofree gchar* executable_path = get_executable_path();
  g_autofree gchar* quoted_executable_path = g_shell_quote(executable_path);
  g_autofree gchar* contents = g_strdup_printf(
      "[Desktop Entry]\n"
      "Type=Application\n"
      "Name=%s\n"
      "Exec=%s %s\n"
      "Terminal=false\n"
      "X-GNOME-Autostart-enabled=true\n",
      kAppName,
      quoted_executable_path,
      kLoginLaunchArgument);

  return g_file_set_contents(path, contents, -1, error);
}

bool get_enabled_argument(FlMethodCall* method_call, bool* enabled) {
  FlValue* arguments = fl_method_call_get_args(method_call);
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return false;
  }

  FlValue* enabled_value = fl_value_lookup_string(arguments, "enabled");
  if (enabled_value == nullptr || fl_value_get_type(enabled_value) != FL_VALUE_TYPE_BOOL) {
    return false;
  }

  *enabled = fl_value_get_bool(enabled_value);
  return true;
}

void respond_with_gerror(FlMethodCall* method_call, const char* code, GError* error) {
  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_error_response_new(
          code,
          error != nullptr ? error->message : "Unknown native Linux error",
          nullptr));
  fl_method_call_respond(method_call, response, nullptr);
}

void launch_at_login_method_call_cb(
    FlMethodChannel* channel,
    FlMethodCall* method_call,
    gpointer user_data) {
  (void)channel;
  (void)user_data;

  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "isEnabled") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(is_launch_at_login_enabled())));
  } else if (g_strcmp0(method, "setEnabled") == 0) {
    bool enabled = false;
    if (!get_enabled_argument(method_call, &enabled)) {
      response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("invalid_arguments", "Expected enabled argument", nullptr));
    } else {
      g_autoptr(GError) error = nullptr;
      if (!set_launch_at_login_enabled(enabled, &error)) {
        respond_with_gerror(method_call, "launch_at_login_error", error);
        return;
      }

      response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

void linux_main_window_method_call_cb(
    FlMethodChannel* channel,
    FlMethodCall* method_call,
    gpointer user_data) {
  (void)channel;

  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "shouldShowMainWindowOnLaunch") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(should_show_main_window_on_launch(self))));
  } else if (g_strcmp0(method, "getOpenMainWindowOnLogin") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(get_open_main_window_on_login())));
  } else if (g_strcmp0(method, "setOpenMainWindowOnLogin") == 0) {
    bool enabled = false;
    if (!get_enabled_argument(method_call, &enabled)) {
      response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("invalid_arguments", "Expected enabled argument", nullptr));
    } else {
      g_autoptr(GError) error = nullptr;
      if (!set_open_main_window_on_login(enabled, &error)) {
        respond_with_gerror(method_call, "linux_main_window_error", error);
        return;
      }

      response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

void register_linux_settings_channels(FlView* view, MyApplication* self) {
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  FlMethodChannel* launch_at_login_channel = fl_method_channel_new(
      messenger,
      "trusttunnel/launch_at_login",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      launch_at_login_channel,
      launch_at_login_method_call_cb,
      nullptr,
      nullptr);

  FlMethodChannel* linux_main_window_channel = fl_method_channel_new(
      messenger,
      "trusttunnel/linux_main_window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      linux_main_window_channel,
      linux_main_window_method_call_cb,
      g_object_ref(self),
      g_object_unref);
}

}  // namespace

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "vpn");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "vpn");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  register_linux_settings_channels(view, self);

  gtk_widget_grab_focus(GTK_WIDGET(view));

  if (should_show_main_window_on_launch(self)) {
    gtk_widget_show(GTK_WIDGET(window));
  }
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
