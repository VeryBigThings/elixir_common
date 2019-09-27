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

args="$@"
/opt/app/bin/local_drive_backend eval "DMFBackend.ReleaseTasks.migrate(~w($args))"
