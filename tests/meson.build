test_support_sources = files('support/gitree-test-repo.vala')

test_deps = [
  vendor_gitg_dep,
]

test_vala_flags = vala_flags + [
  '--pkg', 'gitree-config',
  '--pkg', 'posix',
]

git_prog = find_program('git', required: true)

test_home = join_paths(meson.current_build_dir(), 'home')

test_env = environment()
test_env.set('HOME', test_home)
test_env.set('XDG_CACHE_HOME', join_paths(test_home, '.cache'))
test_env.set('XDG_CONFIG_HOME', join_paths(test_home, '.config'))
test_env.set('XDG_DATA_HOME', join_paths(test_home, '.local', 'share'))
test_env.set('GSETTINGS_SCHEMA_DIR', join_paths(meson.project_build_root(), 'data'))
test_env.set('GSETTINGS_BACKEND', 'memory')

unit_tests = [
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

  test(
    name,
    exe,
    suite: 'unit',
    protocol: 'tap',
    args: ['--tap'],
    env: test_env,
    depends: [gitree_exe],
  )
endforeach

xvfb_wrapper = find_program('ui/run-xvfb.sh')

ui_tests = [
  'smoke',
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

  test(
    'ui-' + name,
    xvfb_wrapper,
    suite: 'ui',
    protocol: 'tap',
    args: [exe, '--tap'],
    env: test_env,
    timeout: 60,
  )
endforeach
