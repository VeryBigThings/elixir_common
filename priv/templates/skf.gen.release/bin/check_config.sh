#!/bin/bash
script_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
args="$@"
$script_dir/<%= app %> eval "<%= Mix.Vbt.app_module_name() %>.Release.check_config()"
