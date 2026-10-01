project(
  'gittree', ['c', 'vala'],
  version: '0.3.6',
  license: 'GPL-2.0-or-later',
  default_options: 'buildtype=debugoptimized',
  meson_version: '>= 0.61.0',
)

application_id = 'io.github.li9i.gittree'
gittree_name = meson.project_name()
gittree_binary = 'gittree'
gittree_version = meson.project_version()
gittree_gettext = gittree_name

if get_option('profile') == 'development'
  application_id = 'io.github.li9i.gittreeDevel'
endif

gittree_prefix = get_option('prefix')
gittree_bindir = join_paths(gittree_prefix, get_option('bindir'))
gittree_datadir = join_paths(gittree_prefix, get_option('datadir'))
gittree_libdir = join_paths(gittree_prefix, get_option('libdir'))
gittree_localedir = join_paths(gittree_prefix, get_option('localedir'))

gittree_pkgdatadir = join_paths(gittree_datadir, gittree_name)
gittree_pkglibdir = join_paths(gittree_libdir, gittree_name)

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

gnome = import('gnome')
i18n = import('i18n')

source_root = meson.current_source_dir()
build_root = meson.current_build_dir()

vapi_dir = join_paths(source_root, 'vapi')
po_dir = join_paths(source_root, 'po')

top_inc = include_directories('.')

glib_req_version = '>= 2.68'

gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0', version: glib_req_version)
glib_dep = dependency('glib-2.0', version: glib_req_version)
gtk_dep = dependency('gtk+-3.0', version: '>= 3.22.0')
gtksourceview_dep = dependency('gtksourceview-4', version: '>= 4.0')
gdk_dep = dependency('gdk-3.0')
libgit2_glib_dep = dependency('libgit2-glib-1.0', version: '>= 1.1.0')
gsettings_desktop_schemas_dep = dependency('gsettings-desktop-schemas')
libm_dep = cc.find_library('m', required: false)

config_h = configuration_data()
config_h.set_quoted('APPLICATION_ID', application_id)
config_h.set_quoted('PROFILE', get_option('profile'))
config_h.set_quoted('GETTEXT_PACKAGE', gittree_gettext)
config_h.set_quoted('PACKAGE_NAME', gittree_name)
config_h.set_quoted('PACKAGE_VERSION', gittree_version)
config_h.set_quoted('PACKAGE_URL', 'https://github.com/li9i/gittree')
config_h.set_quoted('VERSION', gittree_version)
config_h.set_quoted('PLATFORM_NAME', 'unix')
config_h.set_quoted('GITG_DATADIR', gittree_pkgdatadir)
config_h.set_quoted('GITG_LOCALEDIR', gittree_localedir)
config_h.set_quoted('GITG_LIBDIR', gittree_pkglibdir)

configure_file(
  output: 'config.h',
  configuration: config_h,
)

add_project_arguments('-include', 'config.h', language: 'c')

warn_flags = [
  '-Wno-switch',
  '-Wno-unused-parameter',
  '-Wno-incompatible-pointer-types',
  '-Wno-discarded-qualifiers',
  '-Wno-unused-but-set-variable',
  '-Wno-deprecated-declarations',
]
add_project_arguments(cc.get_supported_arguments(warn_flags), language: 'c')

vala_flags = [
  '--target-glib', '2.68',
  '--vapidir', vapi_dir,
  '--pkg', 'config',
  '--pkg', 'gitg-platform-support',
]

subdir('src')
subdir('data')
subdir('po')
subdir('tests')

gnome.post_install(
  glib_compile_schemas: true,
)

summary({
  'prefix': gittree_prefix,
  'binary': gittree_binary,
  'application id': application_id,
  'profile': get_option('profile'),
  'visual tests': get_option('visual_tests'),
}, section: 'Configuration')
