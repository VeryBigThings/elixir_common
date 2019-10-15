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
args="$@"
/opt/app/bin/local_drive_backend eval "DMFBackend.ReleaseTasks.seed(~w($args))"
