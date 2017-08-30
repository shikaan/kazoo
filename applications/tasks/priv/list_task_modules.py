#!/usr/bin/env python2
# -*- coding: utf-8 -*-

import sys, os, glob

header_path = "src/task_modules.hrl"
task_modules_path = "src/modules/*.erl"
ignore_files = ['src/modules/kt_compactor_worker.erl']

def fname(path):
    (name, ext) = (os.path.splitext(os.path.basename(path)))
    return name

with open(header_path, 'w') as header_file:
    name = fname(header_path)
    header_name = name.upper()

    keys = [key for key in glob.glob(task_modules_path) if key not in ignore_files]
    keys.sort()
    first, rest = keys[0], keys[1:]

    header_file.write("-ifndef("+header_name+"_HRL).\n")

    header_file.write("-define("+header_name+"_HRL, 'true').\n\n")

    header_file.write("-define(TASKS, ['"+fname(first)+"'\n")

    for k in rest:
        if "kt_skel" not in k:
            header_file.write("               ,'"+fname(k)+"'\n")

    header_file.write("               ]).\n\n")
    header_file.write("-endif.\n")
