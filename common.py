def list_files(target, source, env):
    """
    Write a list of targets to a text file
    """
    with open(target[0].path, 'w') as f:
        f.write('\n'.join(sorted(str(t) for t in source)) + '\n')
    return None
