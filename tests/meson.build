test_support_sources = files('support/gitrlf-test-repo.vala')
ui_support_sources = files('support/gitrlf-test-pointer.vala', 'support/gitrlf-test-widgets.vala')

test_deps = [
  vendor_gitg_dep,
  gitrlf_dep,
  gtksourceview_dep,
]

test_vala_flags = vala_flags + [
  '--pkg', 'gitrlf-config',
  '--pkg', 'posix',
]

git_prog = find_program('git', required: true)

test_env_base = {
  'GITRLF_BINARY': gitrlf_exe.full_path(),
  'GSETTINGS_SCHEMA_DIR': join_paths(meson.project_build_root(), 'data'),
  'GSETTINGS_BACKEND': 'memory',
}

unit_tests = [
  'changes',
  'cli',
  'diff-find',
  'diff-tool',
  'filter-history',
  'history',
  'line-history',
  'path-history',
  'refs',
  'search',
  'search-words',
  'settings',
  'smoke',
  'text-match',
  'ticks',
  'word-diff',
]

foreach name : unit_tests
  exe = executable(
    'test-' + name,
    files('unit/test-' + name + '.vala') + test_support_sources + gitrlf_all_resources,
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
    depends: [gitrlf_exe, gschemas_compiled],
  )
endforeach

test(
  'read-only',
  find_program('unit/test-read-only.sh'),
  args: [gitrlf_exe],
  suite: 'unit',
)

test(
  'completion',
  find_program('unit/test-completion.sh'),
  args: [
    gitrlf_exe,
    join_paths(meson.project_source_root(), 'data', 'gitrlf.bash-completion'),
  ],
  suite: 'unit',
)

test(
  'meson-install',
  find_program('packaging/test-meson-install.sh'),
  args: [meson.project_build_root()],
  suite: 'install',
  depends: [gitrlf_exe, gschemas_compiled],
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
    files('ui/test-' + name + '.vala') + test_support_sources + ui_support_sources + gitrlf_all_resources,
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
    # ui-filter run alone: 106.5 s with 43 tests, 122.1 s with 48 tests.
    timeout: name == 'filter' ? 240 : 120,
  )
endforeach

gitrlf_bench = executable(
  'gitrlf-bench',
  files('perf/bench.vala') + gitrlf_all_resources,
  include_directories: [top_inc, vendor_gitg_inc],
  dependencies: test_deps,
  vala_args: test_vala_flags,
  install: false,
)

gitrlf_dump = executable(
  'gitrlf-dump',
  files('parity/gitrlf-dump.vala') + gitrlf_all_resources,
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
      'GITRLF_VISUAL_OUT': join_paths(meson.current_build_dir(), 'visual'),
    },
    depends: [gitrlf_exe, gschemas_compiled],
    timeout: 300,
  )
endif
