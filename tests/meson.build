test_support_sources = files('support/gitree-test-repo.vala')

test_deps = [
  vendor_gitg_dep,
  gitree_dep,
]

test_vala_flags = vala_flags + [
  '--pkg', 'gitree-config',
  '--pkg', 'posix',
]

git_prog = find_program('git', required: true)

test_env_base = {
  'GITREE_BINARY': gitree_exe.full_path(),
  'GSETTINGS_SCHEMA_DIR': join_paths(meson.project_build_root(), 'data'),
  'GSETTINGS_BACKEND': 'memory',
}

unit_tests = [
  'cli',
  'settings',
  'smoke',
]

foreach name : unit_tests
  exe = executable(
    'test-' + name,
    files('unit/test-' + name + '.vala') + test_support_sources + gitree_all_resources,
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
    depends: [gitree_exe, gschemas_compiled],
  )
endforeach

xvfb_wrapper = find_program('ui/run-xvfb.sh')

ui_tests = [
  'dash',
  'preferences',
  'smoke',
  'window',
]

foreach name : ui_tests
  exe = executable(
    'test-ui-' + name,
    files('ui/test-' + name + '.vala') + test_support_sources + gitree_all_resources,
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
    timeout: 60,
  )
endforeach
