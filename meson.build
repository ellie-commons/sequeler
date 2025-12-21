# project name and programming language
project('io.github.ellie_commons.sequeler', 'vala', 'c',
    version: '0.8.2',
    meson_version: '>= 0.56.0')

cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required: true)

vala_args = ['--pkg', 'posix']

add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala'
)

if get_option('profile') == 'development'
	application_id = '@0@.Devel'.format(meson.project_name())
	vala_args += ['-D', 'IS_DEVEL']
else
	application_id = meson.project_name()
endif

linux_dep = meson.get_compiler('vala').find_library('linux')

# Include the translations module
i18n = import('i18n')

# Include the gnome module
gnome = import('gnome')
asresources = gnome.compile_resources(
    'as-resources', 'data/assets.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

# Set our translation domain
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

vala_lint = find_program('io.elementary.vala-lint', required : false)
if vala_lint.found()
    test (
        'Vala lint',
        vala_lint,
        args: ['-d', join_paths(meson.project_source_root(), 'src')]
    )
endif

subdir('src')
subdir('data')
subdir('po')

meson.add_install_script('build-aux/meson_post_install.py')
