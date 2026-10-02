gittree_lib_sources = files(
  'gittree-application.vala',
  'gittree-bar-edge.vala',
  'gittree-bar-row.vala',
  'gittree-bar-spacer.vala',
  'gittree-command-line.vala',
  'gittree-copy-menu.vala',
  'gittree-dash-view.vala',
  'gittree-diff-find-bar.vala',
  'gittree-diff-find.vala',
  'gittree-diff-scroll-bar.vala',
  'gittree-filter.vala',
  'gittree-history-activity.vala',
  'gittree-history-model.vala',
  'gittree-history-paned.vala',
  'gittree-history.vala',
  'gittree-languages.vala',
  'gittree-line-history.vala',
  'gittree-poll.vala',
  'gittree-preferences-dialog.vala',
  'gittree-ref.vala',
  'gittree-refs-header.vala',
  'gittree-refs-list.vala',
  'gittree-refs-row.vala',
  'gittree-refs.vala',
  'gittree-repository.vala',
  'gittree-search-choice.vala',
  'gittree-search-keys.vala',
  'gittree-search-query.vala',
  'gittree-search-switches.vala',
  'gittree-search.vala',
  'gittree-text-match.vala',
  'gittree-text-search.vala',
  'gittree-ticks.vala',
  'gittree-window.vala',
  'gittree-word-diff.vala',
)

gittree_resources = gnome.compile_resources(
  'gittree-resources',
  'resources/gittree.gresource.xml',
  source_dir: join_paths(meson.current_source_dir(), 'resources'),
  c_name: 'gittree',
)

gittree_deps = [
  vendor_gitg_dep,
  gtksourceview_dep,
]

gittree_vala_flags = vala_flags + [
  '--pkg', 'gittree-config',
  '--pkg', 'posix',
  '--gresources', join_paths(meson.current_source_dir(), 'resources/gittree.gresource.xml'),
  '--gresourcesdir', join_paths(meson.current_source_dir(), 'resources'),
]

libgittree = static_library(
  'gittree',
  gittree_lib_sources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: gittree_deps,
  vala_args: gittree_vala_flags,
  vala_header: 'gittree.h',
  vala_vapi: 'gittree.vapi',
  c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gittree_gettext)],
  install: false,
)

gittree_dep = declare_dependency(
  link_with: libgittree,
  include_directories: [top_inc, vendor_gitg_inc, include_directories('.')],
  dependencies: gittree_deps,
)

gittree_all_resources = gittree_resources + vendor_gitg_resources

gittree_exe = executable(
  gittree_binary,
  files('gittree-main.vala') + gittree_all_resources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: [gittree_dep],
  vala_args: gittree_vala_flags,
  c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gittree_gettext)],
  install: true,
  install_dir: gittree_bindir,
)

install_symlink(
  'git-tree',
  pointing_to: gittree_binary,
  install_dir: gittree_bindir,
)
