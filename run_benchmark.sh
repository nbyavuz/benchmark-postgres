#!/bin/sh

# Configurable directories
current_dir=$(pwd)
result_dir=$current_dir/results
log_dir=$current_dir/logs
hammerdb_cli_dir=

rm -rf $log_dir
mkdir -p $log_dir
mkdir -p $result_dir

# Configurable settings
pg_count_ware=300 # Warehouse count
pg_count_vu=60 # Virtual user count
pg_rampup=2 # Ramp up time in minutes
pg_duration=5 # Test duration in minutes
pg_vacuum=true # Vacuum

cd $hammerdb_cli_dir

./hammerdbcli <<! 2>&1 | stdbuf -oL -eL sed -e "s,\x1B\[[0-9;]*[a-zA-Z],,g" -e "s,\r,,g" -e "s,hammerdb>,,g" -e "s,after\#[0-9]*,,g" >> $log_dir/pgschemabuild.output
set argv [list $pg_count_ware $pg_count_vu]
set argc 2
source ${current_dir}/pgschemabuild.tcl
!

./hammerdbcli <<! 2>&1 | stdbuf -oL -eL sed -e "s,\x1B\[[0-9;]*[a-zA-Z],,g" -e "s,\r,,g" -e "s,hammerdb>,,g" -e "s,after\#[0-9]*,,g" >> $log_dir/pgrun.output
set argv [list $pg_rampup $pg_duration $pg_vacuum]
set argc 3
source ${current_dir}/pgrun.tcl
!

grep -e 'VU TEST' -e 'System achieved' $log_dir/pgrun.output > $result_dir/result-$(date --utc +'%Y-%m-%dt%H-%M-%S').out

cd $current_dir
