gitrlf_lib_sources = files(
  'gitrlf-application.vala',
  'gitrlf-bar-edge.vala',
  'gitrlf-bar-row.vala',
  'gitrlf-bar-spacer.vala',
  'gitrlf-changes.vala',
  'gitrlf-command-line.vala',
  'gitrlf-copy-menu.vala',
  'gitrlf-dash-view.vala',
  'gitrlf-diff-find-bar.vala',
  'gitrlf-diff-find.vala',
  'gitrlf-diff-scroll-bar.vala',
  'gitrlf-diff-tool.vala',
  'gitrlf-filter.vala',
  'gitrlf-headed-list.vala',
  'gitrlf-history-activity.vala',
  'gitrlf-history-model.vala',
  'gitrlf-history-paned.vala',
  'gitrlf-history.vala',
  'gitrlf-languages.vala',
  'gitrlf-line-history.vala',
  'gitrlf-poll.vala',
  'gitrlf-preferences-dialog.vala',
  'gitrlf-ref.vala',
  'gitrlf-refs-header.vala',
  'gitrlf-refs-list.vala',
  'gitrlf-refs-row.vala',
  'gitrlf-refs.vala',
  'gitrlf-repository.vala',
  'gitrlf-search-choice.vala',
  'gitrlf-search-keys.vala',
  'gitrlf-search-query.vala',
  'gitrlf-search-switches.vala',
  'gitrlf-search.vala',
  'gitrlf-text-match.vala',
  'gitrlf-text-search.vala',
  'gitrlf-ticks.vala',
  'gitrlf-window.vala',
  'gitrlf-word-diff.vala',
)

gitrlf_resources = gnome.compile_resources(
  'gitrlf-resources',
  'resources/gitrlf.gresource.xml',
  source_dir: join_paths(meson.current_source_dir(), 'resources'),
  c_name: 'gitrlf',
)

gitrlf_deps = [
  vendor_gitg_dep,
  gtksourceview_dep,
]

gitrlf_vala_flags = vala_flags + [
  '--pkg', 'gitrlf-config',
  '--pkg', 'posix',
  '--gresources', join_paths(meson.current_source_dir(), 'resources/gitrlf.gresource.xml'),
  '--gresourcesdir', join_paths(meson.current_source_dir(), 'resources'),
]

libgitrlf = static_library(
  'gitrlf',
  gitrlf_lib_sources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: gitrlf_deps,
  vala_args: gitrlf_vala_flags,
  vala_header: 'gitrlf.h',
  vala_vapi: 'gitrlf.vapi',
  c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gitrlf_gettext)],
  install: false,
)

gitrlf_dep = declare_dependency(
  link_with: libgitrlf,
  include_directories: [top_inc, vendor_gitg_inc, include_directories('.')],
  dependencies: gitrlf_deps,
)

gitrlf_all_resources = gitrlf_resources + vendor_gitg_resources

gitrlf_exe = executable(
  gitrlf_binary,
  files('gitrlf-main.vala') + gitrlf_all_resources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: [gitrlf_dep],
  vala_args: gitrlf_vala_flags,
  c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gitrlf_gettext)],
  install: true,
  install_dir: gitrlf_bindir,
)
