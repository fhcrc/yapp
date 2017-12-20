import os
import subprocess
import sys


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
