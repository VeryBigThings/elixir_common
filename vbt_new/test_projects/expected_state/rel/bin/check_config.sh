#!/bin/bash
script_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
args="$@"
$script_dir/skafolder_tester eval "SkafolderTesterApp.Release.check_config()"
