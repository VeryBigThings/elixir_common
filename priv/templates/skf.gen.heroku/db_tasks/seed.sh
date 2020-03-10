#!/bin/bash
function myHelp () {
# Using a here doc with standard out.
cat <<-END
Usage:
------
   -h | --help
     Display this help
   --file FILE_NAME
     Seeds specified file. Folder for seed file is "priv/repo/" + seed_file_name
------
If no options provided, it will seed default seed file: "priv/repo/seeds.exs"
END
};

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  myHelp;
  exit 0;
fi

script_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
args="$@"
$script_dir/<%= app %> eval "<%= base_module %>.ReleaseTasks.seed(~w($args))"
