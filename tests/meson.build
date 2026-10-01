test_support_sources = files('support/gittree-test-repo.vala')
ui_support_sources = files('support/gittree-test-pointer.vala', 'support/gittree-test-widgets.vala')

test_deps = [
  vendor_gitg_dep,
  gittree_dep,
  gtksourceview_dep,
]

test_vala_flags = vala_flags + [
  '--pkg', 'gittree-config',
  '--pkg', 'posix',
]

git_prog = find_program('git', required: true)

test_env_base = {
  'GITTREE_BINARY': gittree_exe.full_path(),
  'GSETTINGS_SCHEMA_DIR': join_paths(meson.project_build_root(), 'data'),
  'GSETTINGS_BACKEND': 'memory',
}

unit_tests = [
  'cli',
  'diff-find',
  'filter-history',
  'history',
  'line-history',
  'path-history',
  'refs',
  'search',
  'settings',
  'smoke',
  'text-match',
  'ticks',
  'word-diff',
]

foreach name : unit_tests
  exe = executable(
    'test-' + name,
    files('unit/test-' + name + '.vala') + test_support_sources + gittree_all_resources,
    include_directories: [top_inc, vendor_gitg_inc],
    dependencies: test_deps,
    vala_args: test_vala_flags,
    install: false,
  )

  test_home = join_paths(meson.current_build_dir(), 'home', name)

  test(
    name,
    exe,
    suite: 'unit',
    protocol: 'tap',
    args: ['--tap'],
    env: test_env_base + {
      'HOME': test_home,
      'XDG_CACHE_HOME': join_paths(test_home, '.cache'),
      'XDG_CONFIG_HOME': join_paths(test_home, '.config'),
      'XDG_DATA_HOME': join_paths(test_home, '.local', 'share'),
    },
    depends: [gittree_exe, gschemas_compiled],
  )
endforeach

test(
  'read-only',
  find_program('unit/test-read-only.sh'),
  args: [gittree_exe],
  suite: 'unit',
)

test(
  'completion',
  find_program('unit/test-completion.sh'),
  args: [
    gittree_exe,
    join_paths(meson.project_source_root(), 'data', 'gittree.bash-completion'),
  ],
  suite: 'unit',
)

test(
  'meson-install',
  find_program('packaging/test-meson-install.sh'),
  args: [meson.project_build_root()],
  suite: 'install',
  depends: [gittree_exe, gschemas_compiled],
)

test(
  'vendor-closure',
  find_program('vendor/check-closure.sh'),
  suite: 'unit',
)

xvfb_wrapper = find_program('ui/run-xvfb.sh')

ui_tests = [
  'dash',
  'diff-find',
  'diff-pane',
  'filter',
  'follow',
  'history-activity',
  'preferences',
  'refs-panel',
  'renames',
  'search',
  'session',
  'smoke',
  'startup',
  'window',
]

foreach name : ui_tests
  exe = executable(
    'test-ui-' + name,
    files('ui/test-' + name + '.vala') + test_support_sources + ui_support_sources + gittree_all_resources,
    include_directories: [top_inc, vendor_gitg_inc],
    dependencies: test_deps,
    vala_args: test_vala_flags,
    install: false,
  )

  test_home = join_paths(meson.current_build_dir(), 'home', 'ui-' + name)

  test(
    'ui-' + name,
    xvfb_wrapper,
    suite: 'ui',
    protocol: 'tap',
    args: [exe, '--tap'],
    env: test_env_base + {
      'HOME': test_home,
      'XDG_CACHE_HOME': join_paths(test_home, '.cache'),
      'XDG_CONFIG_HOME': join_paths(test_home, '.config'),
      'XDG_DATA_HOME': join_paths(test_home, '.local', 'share'),
    },
    depends: [gschemas_compiled],
    timeout: 120,
  )
endforeach

gittree_bench = executable(
  'gittree-bench',
  files('perf/bench.vala') + gittree_all_resources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: test_deps,
  vala_args: test_vala_flags,
  install: false,
)

gittree_dump = executable(
  'gittree-dump',
  files('parity/gittree-dump.vala') + gittree_all_resources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: test_deps,
  vala_args: test_vala_flags,
  install: false,
)

if get_option('visual_tests')
  test(
    'visual-parity',
    find_program('visual/test-parity.sh'),
    suite: 'visual',
    env: test_env_base + {
      'GITTREE_VISUAL_OUT': join_paths(meson.current_build_dir(), 'visual'),
    },
    depends: [gittree_exe, gschemas_compiled],
    timeout: 300,
  )
endif
