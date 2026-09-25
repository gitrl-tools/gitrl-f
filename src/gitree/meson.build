gitree_lib_sources = files(
  'gitree-application.vala',
  'gitree-command-line.vala',
  'gitree-dash-view.vala',
  'gitree-history-activity.vala',
  'gitree-preferences-dialog.vala',
  'gitree-repository.vala',
  'gitree-window.vala',
)

gitree_resources = gnome.compile_resources(
  'gitree-resources',
  'resources/gitree.gresource.xml',
  source_dir: join_paths(meson.current_source_dir(), 'resources'),
  c_name: 'gitree',
)

gitree_deps = [
  vendor_gitg_dep,
  gtksourceview_dep,
]

gitree_vala_flags = vala_flags + [
  '--pkg', 'gitree-config',
  '--gresources', join_paths(meson.current_source_dir(), 'resources/gitree.gresource.xml'),
  '--gresourcesdir', join_paths(meson.current_source_dir(), 'resources'),
]

libgitree = static_library(
  'gitree',
  gitree_lib_sources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: gitree_deps,
  vala_args: gitree_vala_flags,
  vala_header: 'gitree.h',
  vala_vapi: 'gitree.vapi',
  c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gitree_gettext)],
  install: false,
)

gitree_dep = declare_dependency(
  link_with: libgitree,
  include_directories: [top_inc, vendor_gitg_inc, include_directories('.')],
  dependencies: gitree_deps,
)

gitree_all_resources = gitree_resources + vendor_gitg_resources

gitree_exe = executable(
  gitree_binary,
  files('gitree-main.vala') + gitree_all_resources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: [gitree_dep],
  vala_args: gitree_vala_flags,
  c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gitree_gettext)],
  install: true,
  install_dir: gitree_bindir,
)
