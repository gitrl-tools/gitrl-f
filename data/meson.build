schema_conf = configuration_data()
schema_conf.set('GETTEXT_PACKAGE', gitree_gettext)
schema_conf.set('APPLICATION_ID', application_id)

schema_path = '/io/github/li9i/gitree'
if get_option('profile') == 'development'
  schema_path = '/io/github/li9i/gitreeDevel'
endif
schema_conf.set('SCHEMA_PATH', schema_path)

schema_file = configure_file(
  input: 'io.github.li9i.gitree.gschema.xml.in',
  output: '@0@.gschema.xml'.format(application_id),
  configuration: schema_conf,
  install: true,
  install_dir: join_paths(gitree_datadir, 'glib-2.0', 'schemas'),
)

glib_compile_schemas = find_program('glib-compile-schemas')

gschemas_compiled = custom_target(
  'gschemas.compiled',
  input: schema_file,
  output: 'gschemas.compiled',
  command: [glib_compile_schemas, '--targetdir', '@OUTDIR@', meson.current_build_dir()],
  build_by_default: true,
)

test(
  'gschema-validate',
  glib_compile_schemas,
  args: ['--strict', '--dry-run', meson.current_build_dir()],
  suite: 'data',
  depends: gschemas_compiled,
)

man_conf = configuration_data()
man_conf.set('VERSION', gitree_version)

install_man(
  configure_file(
    input: 'gitree.1.in',
    output: 'gitree.1',
    configuration: man_conf,
  ),
  'git-tree.1',
)
