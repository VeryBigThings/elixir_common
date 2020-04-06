#!/bin/bash
function myHelp () {
# Using a here doc with standard out.
cat <<-END
Usage:
------
   -h | --help
     Display this help
   -n NUMBER | --step NUMBER
     Runs the specific number of migrations
   --to VERSION
     Runs all until the supplied version is reached
   --all
     Runs all available if true
------
If no options provided, it will run all available migrations.
END
};

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  myHelp;
  exit 0;
fi

script_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
args="$@"
$script_dir/<%= app %> eval "<%= Mix.Vbt.app_module_name() %>.Release.migrate(~w($args))"
