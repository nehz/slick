# -*- coding: utf-8 -*-

import os
import re
import shutil
import subprocess
import sys

import yaml

from argparse import ArgumentParser
from mako.template import Template

PLATFORMS = {'all', 'android', 'ios'}
CONFIG_REQUIRE = {'name', 'id', 'launch', 'version'}
SEMVER_MULTIPLIER = 100


class CLIError(Exception):
    pass


def copy_dir(src, dst, tpl_context, skip_dirs=None, match_dirs=None):
    for path, _, files in os.walk(src):
        if skip_dirs and path != src:
            if any((os.path.normpath(s) in path for s in skip_dirs)):
                continue
        if match_dirs and path != src:
            if not any((os.path.normpath(m) in path for m in match_dirs)):
                continue

        for file in files:
            file = os.path.join(path, file)
            rel = os.path.relpath(file, src)
            target = os.path.join(dst, rel)
            target_dir = os.path.dirname(target)

            if not os.path.exists(target_dir):
                os.makedirs(target_dir)

            tpl_path, ext = os.path.splitext(target)
            if ext == '.tpl':
                with open(tpl_path, 'wb') as w:
                    tpl = Template(filename=file,
                                   input_encoding='utf-8',
                                   output_encoding='utf-8',
                                   imports=['import os, os.path as path'])
                    w.write(tpl.render(**tpl_context))
            elif (not os.path.exists(target) or
                    os.path.getmtime(file) > os.path.getmtime(target)):
                shutil.copyfile(file, target)


def init(args):
    if os.path.exists(args.path):
        if not os.path.isdir(args.path):
            raise CLIError('Path is not a folder')
        if os.listdir(args.path):
            raise CLIError('Folder is not empty')
    else:
        os.makedirs(args.path)

    module_path = os.path.dirname(__file__)
    template_path = os.path.join(module_path, 'init')
    copy_dir(template_path, args.path, {})


def setup_android(config):
    sdk_path = os.environ.get('ANDROID_HOME')
    ndk_path = os.environ.get('ANDROID_NDK_HOME')

    if not sdk_path:
        raise CLIError('ANDROID_SDK_HOME not defined')
    if not os.path.exists(sdk_path):
        raise CLIError('ANDROID_SDK_HOME (%s) does not exist' % sdk_path)

    config['android']['ndk'] = False
    if not ndk_path:
        print('ANDROID_NDK_HOME not set, NDK building disabled')
    elif not os.path.exists(ndk_path):
        print('ANDROID_NDK_HOME (%s) does not exist, NDK building disabled' %
              ndk_path)
    else:
        config['android']['ndk'] = True

    # Get build-tools revision
    build_tools = next(os.walk(os.path.join(sdk_path, 'build-tools')))[1]
    build_tools.sort()
    if not build_tools:
        raise CLIError('No build-tools installed')
    config['android']['build_tools'] = build_tools[-1]
    print('Using build-tools:', build_tools[-1])

    # Map latest to target
    if config['android']['target'] == 'latest':
        targets = next(os.walk(os.path.join(sdk_path, 'platforms')))[1]
        targets = [int(t.replace('android-', '')) for t in targets]
        targets.sort()
        if not targets:
            raise CLIError('No platform targets installed')
        config['android']['target'] = targets[-1]
    print('Target:', config['android']['target'])

    # Correct ABIs
    arch = set(config['android'].get('arch', []))
    mapping = {
        'armeabi': {'arm'},
        'armeabi-v7a': {'arm-v7', 'arm-v7a', 'armv7', 'armv7a'},
    }
    for abi, v in mapping.items():
        if not arch & v:
            continue
        arch = arch - v
        arch.add(abi)
    config['android']['arch'] = arch


def gradle(*args):
    if hasattr(shutil, 'which'):
        if not shutil.which('gradle'):
            raise CLIError('Gradle not installed')

    subprocess.call(('gradle', ) + args,
                    cwd=os.path.join('build', 'android'),
                    shell=True)


def build_android():
    gradle('build')


def install_android():
    gradle('installDebug')


def setup(platform):
    print('Setup platform:', platform)

    # App config
    try:
        with open('app.yaml', 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
    except IOError:
        raise CLIError('Cannot find app.yaml')

    missing = CONFIG_REQUIRE - (set(config) & CONFIG_REQUIRE)
    if missing:
        raise CLIError('App config missing fields: ', missing)
    if platform not in config:
        config[platform] = {}

    # Assume semver
    if 'version_num' not in config:
        pat = '(?P<major>\d+)' \
              '(?:\.(?P<minor>\d+))?' \
              '(?:\.(?P<patch>\d+))?' \
              '(?:\-.*?(?P<pre>\d+).*)?'
        match = re.match(pat, config['version'])
        if not match:
            raise CLIError('Version in app config not in semantic format')
        groups = match.groupdict()
        for k, v in groups.items():
            if not v or int(v) < SEMVER_MULTIPLIER:
                continue
            raise CLIError('Version %s in app config must be < %d' %
                           (k, SEMVER_MULTIPLIER))
        config['version_num'] = \
            (int(groups.get('pre') or 0) +
             int(groups.get('patch') or 0) * SEMVER_MULTIPLIER ** 1 +
             int(groups.get('minor') or 0) * SEMVER_MULTIPLIER ** 2 +
             int(groups.get('major')) * SEMVER_MULTIPLIER ** 3)

    # Platform setup hook
    platform_setup = globals().get('setup_' + platform, None)
    if callable(platform_setup):
        if platform not in config:
            config[platform] = {}
        platform_setup(config)

    # Copy files and setup project
    build_path = os.path.abspath(os.path.join('build', platform))
    package_path = os.path.join(build_path, 'package')
    native_path = os.path.join(build_path, 'native')

    module_path = os.path.dirname(__file__)
    template_path = os.path.join(module_path, 'build', platform)
    base_path = os.path.join(os.path.dirname(module_path))
    core_path = os.path.join(base_path, 'core')
    platform_base_path = os.path.join(base_path, 'platform')
    platform_path = os.path.join(platform_base_path, platform)
    platform_common_path = os.path.join(platform_base_path, 'common')
    platform_native_path = os.path.join(platform_path, 'native')

    context = {
        'app': config,
        'build_path': build_path,
    }

    copy_dir('components', os.path.join(package_path, 'components'), context)
    copy_dir(core_path, os.path.join(package_path, 'core'), context)
    copy_dir(platform_native_path, os.path.join(build_path, 'native'), context)
    copy_dir(os.path.join(platform_base_path),
             os.path.join(package_path, 'platform'), context,
             skip_dirs=[platform_native_path],
             match_dirs=[platform_path, platform_common_path])

    context['native_modules'] = next(os.walk(native_path))[1]
    copy_dir(template_path, build_path, context)


def build(platform):
    setup(platform)
    print('Build platform:', platform)

    # Platform build hook
    platform_build = globals().get('build_' + platform, None)
    if callable(platform_build):
        platform_build()


def install(platform):
    setup(platform)
    print('Install platform:', platform)

    # Platform build hook
    platform_install = globals().get('install_' + platform, None)
    if callable(platform_install):
        platform_install()


def main():
    parser = ArgumentParser('slick')
    command = parser.add_subparsers()

    cmd = command.add_parser('init', help='create a project')
    cmd.set_defaults(func=init)
    cmd.add_argument('path', help='project path', nargs='?', default='.')

    cmd = command.add_parser('setup', help='setup project for target')
    cmd.set_defaults(func=setup)
    cmd.add_argument('platforms', help='platforms',
                     nargs='+', choices=PLATFORMS)

    cmd = command.add_parser('build', help='build project for target')
    cmd.set_defaults(func=build)
    cmd.add_argument('platforms', help='platforms',
                     nargs='+', choices=PLATFORMS)

    cmd = command.add_parser('install', help='install project on target')
    cmd.set_defaults(func=install)
    cmd.add_argument('platforms', help='platforms',
                     nargs='+', choices=PLATFORMS)

    args = parser.parse_args()
    if hasattr(args, 'func'):
        try:
            if hasattr(args, 'platforms'):
                if 'all' in args.platforms:
                    args.platforms = PLATFORMS - {'all'}
                for p in args.platforms:
                    args.func(platform=p)
            else:
                args.func(args)
        except CLIError as e:
            print('Error:', e)
            sys.exit(1)
    else:
        parser.print_help()
