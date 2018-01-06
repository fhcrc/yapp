import os
import subprocess
import sys
import configparser


def list_files(target, source, env):
    """
    Write a list of targets to a text file
    """
    with open(target[0].path, 'w') as f:
        f.write('\n'.join(sorted(str(t) for t in source)) + '\n')
    return None


def taxit_rp(refpkg, resource, img=None, singularity='singularity'):
    """
    Return the path to a resource in refpgk
    """
    cmd = []
    if img:
        cwd = os.getcwd()
        cmd += [singularity, 'exec', '-B', cwd, '--pwd', cwd, img]

    cmd += ['taxit', 'rp', refpkg, resource]
    output = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            universal_newlines=True).stdout.strip()
    if not output:
        sys.exit('taxit_rp() failed: has "scons -f SConstruct-get-data" been run?')

    return output


def get_conf(configfile='settings.conf'):
    """
    Returns (user_args, conf)
    """

    # arguments after "--" are ignored by scons
    user_args = sys.argv[1 + sys.argv.index('--'):] if '--' in sys.argv else []

    # we'd like to use some default values from the config file as we set
    # up the command line options, but we also want to be able to specify
    # the config file from the command line. This makes things a bit
    # convoluted at first.
    if user_args and os.path.exists(user_args[0]):
        settings = user_args[0]
    elif os.path.exists(configfile):
        settings = configfile
        user_args.insert(0, configfile)
    else:
        sys.exit('A configuration file must be provided, either as '
                 'the first argument after "--", or named "{}" '
                 'in this directory'.format(configfile))

    conf = configparser.SafeConfigParser(allow_no_value=True)
    conf.read(settings)

    return user_args, conf
