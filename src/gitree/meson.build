gitree_all_resources = vendor_gitg_resources

gitree_exe = executable(
  gitree_binary,
  files('gitree-main.vala') + gitree_all_resources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: [vendor_gitg_dep],
  vala_args: vala_flags + ['--pkg', 'gitree-config'],
  c_args: ['-DGETTEXT_PACKAGE="@0@"'.format(gitree_gettext)],
  install: true,
  install_dir: gitree_bindir,
)
