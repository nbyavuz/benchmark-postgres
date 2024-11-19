#!/bin/sh

# Configurable directories
current_dir=$(pwd)
result_dir=$current_dir/results
log_dir=$current_dir/logs
hammerdb_cli_dir=""

DATE=$(date --utc +'%Y-%m-%dt%H-%M-%S')
schemabuild_file_name=pgschemabuild-${DATE}.out
pgrun_file_name=pgrun-${DATE}.out
result_file_name=result-${DATE}.out
mkdir -p $log_dir
mkdir -p $result_dir

# Configurable settings
pg_count_ware=300 # Warehouse count
pg_count_vu=60 # Virtual user count to create warehouses
pg_benchmark_vu="1 8 16 32" # Virtual user counts to test
pg_rampup=2 # Ramp up time in minutes
pg_duration=5 # Test duration in minutes

cd $hammerdb_cli_dir

for cur_vu in ${pg_benchmark_vu}; do

    psql -c "DROP DATABASE IF EXISTS tpcc" postgres

echo "Running schema build"
./hammerdbcli <<! 2>&1 | stdbuf -oL -eL sed -e "s,\x1B\[[0-9;]*[a-zA-Z],,g" -e "s,\r,,g" -e "s,hammerdb>,,g" -e "s,after\#[0-9]*,,g" >> $log_dir/${schemabuild_file_name}
set argv [list $pg_count_ware $pg_count_vu]
set argc 2
source ${current_dir}/pgschemabuild.tcl
!

    # Run VACUUM and CHECKPOINT before each benchmark
    psql -c "VACUUM" postgres
    psql -c "CHECKPOINT" postgres

    echo "Running benchmark for ${cur_vu} VU"
./hammerdbcli <<! 2>&1 | stdbuf -oL -eL sed -e "s,\x1B\[[0-9;]*[a-zA-Z],,g" -e "s,\r,,g" -e "s,hammerdb>,,g" -e "s,after\#[0-9]*,,g" >> $log_dir/${pgrun_file_name}
set argv [list $pg_rampup $pg_duration $cur_vu]
set argc 3
source ${current_dir}/pgrun.tcl
!
done

grep -e 'VU TEST' -e 'System achieved' $log_dir/${pgrun_file_name} > $result_dir/${result_file_name}

cd $current_dir
