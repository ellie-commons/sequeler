icon_sizes = ['16', '24', '32', '48', '64', '128']

icons_dir = join_paths(get_option('datadir'), 'icons', 'hicolor')
foreach size : icon_sizes
		asset = join_paths('assets', 'icons', '@0@x@0@'.format(size), '@0@.svg'.format(meson.project_name()))
		install_data(
				asset,
				install_dir:  join_paths(icons_dir, '@0@x@0@'.format(size), 'apps'),
				rename: '@0@.svg'.format(application_id)
		)
		install_data(
				asset,
				install_dir: join_paths(icons_dir,  '@0@x@0@@2'.format(size), 'apps'),
				rename: '@0@.svg'.format(application_id)
		)
endforeach

install_data(
		join_paths('assets', 'icons', '128x128', '@0@.svg'.format(meson.project_name())),
		install_dir: join_paths(icons_dir , 'scalable', 'apps'),
		rename: '@0@.svg'.format(application_id)
)

install_data(
		join_paths('assets', 'icons', 'status', 'table.svg'),
		install_dir: join_paths(icons_dir , '16x16', 'status'),
)

install_data(
		join_paths('assets', 'icons', 'status', 'table-empty.svg'),
		install_dir: join_paths(icons_dir , '16x16', 'status'),
)

install_data(
		join_paths('assets', 'icons', 'actions', 'office-database-new.svg'),
		install_dir: join_paths(icons_dir , '24x24', 'actions'),
)

install_data(
		join_paths('assets', 'icons', 'actions', 'office-database-remove.svg'),
		install_dir: join_paths(icons_dir , '24x24', 'actions'),
)

install_data(
		join_paths('assets', 'icons', 'actions', 'office-database-edit.svg'),
		install_dir: join_paths(icons_dir , '24x24', 'actions'),
)

install_data(
		join_paths('assets', 'icons', 'actions', 'application-logout.svg'),
		install_dir: join_paths(icons_dir , '24x24', 'actions'),
)

# Install the Desktop file
desktop_conf = configuration_data()
desktop_conf.set('icon', application_id)
desktop_conf.set('binary', application_id)

desktop_file = i18n.merge_file(
		input: configure_file(
			input: '@0@.desktop.in.in'.format(meson.project_name()),
			output: '@0@.desktop.in'.format(application_id),
			configuration: desktop_conf
		),
		output:'@0@.desktop'.format(application_id),
		po_dir: join_paths(meson.source_root(), 'po', 'extra'),
		type: 'desktop',
		install: true,
		install_dir: join_paths(get_option('datadir'), 'applications')
)

# Validate desktop file
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
	test(
		'validate-desktop',
		desktop_file_validate,
		args: [
			desktop_file.full_path()
		]
	)
endif

# Install the MetaInfo file
metainfo_conf = configuration_data()
metainfo_conf.set('appid', application_id)
metainfo_conf.set('version', meson.project_version())

metainfo_file = i18n.merge_file(
		input: configure_file(
			input: '@0@.metainfo.xml.in.in'.format(meson.project_name()),
			output: '@0@.metainfo.xml.in'.format(application_id),
			configuration: metainfo_conf
		),
		output: '@0@.metainfo.xml'.format(application_id),
		po_dir: join_paths(meson.source_root(), 'po'),
		install: true,
		install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Validate MetaInfo file
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
	test(
		'validate', appstream_util,
		args: [
			'validate-relax', metainfo_file.full_path()
		]
	)
endif
