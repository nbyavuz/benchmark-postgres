#!/bin/sh

set -e

# Configurable directories
current_dir=$(pwd)
hammerdb_result_dir=$current_dir/results
log_dir=$current_dir/logs
hammerdb_log_dir=$log_dir/hammberdb
pg_log_dir=$log_dir/pg
pg_ctl_timeout=900

hammerdb_cli_dir=""
backup_dir=""
pg_data_dir=""

DATE=$(date --utc +'%Y-%m-%dt%H-%M-%S')
schemabuild_file_name=pgschemabuild-${DATE}.out
pgrun_file_name=pgrun-${DATE}.out
result_file_name=result-${DATE}.out
load_log_file_name=$pg_log_dir/load_log-${DATE}

mkdir -p $hammerdb_log_dir
mkdir -p $hammerdb_result_dir
mkdir -p $pg_log_dir

# Configurable settings
pg_count_ware=1024 # Warehouse count
pg_count_vu=512 # Virtual user count to create warehouses
pg_benchmark_vu="512 256" # Virtual user counts to test
pg_rampup=10 # Ramp up time in minutes
pg_duration=20 # Test duration in minutes

initialize_db () {

    echo "Starting PG server for the building schema"
    pg_ctl -D ${pg_data_dir} -l ${load_log_file_name} -t $pg_ctl_timeout start
    echo "Done"

    cd $hammerdb_cli_dir
    echo "Running schema build"
./hammerdbcli <<! 2>&1 | stdbuf -oL -eL sed -e "s,\x1B\[[0-9;]*[a-zA-Z],,g" -e "s,\r,,g" -e "s,hammerdb>,,g" -e "s,after\#[0-9]*,,g" >> $hammerdb_log_dir/${schemabuild_file_name}
set argv [list $pg_count_ware $pg_count_vu]
set argc 2
source ${current_dir}/pgschemabuild.tcl
!
    echo "Done"
}

create_backup () {

    echo "Clearing backup dir"
    rm -rf $backup_dir
    echo "Done"

    echo "Stopping PG server for the creating backup"
    pg_ctl -D $pg_data_dir -l $load_log_file_name -t $pg_ctl_timeout stop
    echo "Done"

    echo "Creating backup"
    mkdir -p $backup_dir
    cp -R $pg_data_dir/* $backup_dir
    echo "Done"
}

copy_backup_to_pg () {

    echo "Copying backup to pgdir"
    pg_ctl -D $pg_data_dir -l $1 -t $pg_ctl_timeout stop -m immediate
    rm -rf $pg_data_dir/*
    cp -R $backup_dir/* $pg_data_dir
    echo "Done"
}

run_optimizations () {

    echo "Running optimizations"

    # Run VACUUM and CHECKPOINT before each benchmark
    psql -c "CREATE EXTENSION pg_prewarm" -d tpcc -U postgres
    psql -c "VACUUM ANALYZE" -d tpcc -U postgres
    psql -c "CHECKPOINT" -d tpcc -U postgres
    psql -c "SELECT pg_size_pretty( pg_database_size('tpcc') );" postgres

    # prewarm the server
    psql -c "SELECT pg_prewarm('history')" -d tpcc -U postgres
    psql -c "SELECT pg_prewarm('orders')" -d tpcc -U postgres
    psql -c "SELECT pg_prewarm('customer')" -d tpcc -U postgres
    psql -c "SELECT pg_prewarm('stock')" -d tpcc -U postgres

    echo "Done"
}

run_hammerdb_benchmark () {

    echo "Running benchmark for $1 VU"
./hammerdbcli <<! 2>&1 | stdbuf -oL -eL sed -e "s,\x1B\[[0-9;]*[a-zA-Z],,g" -e "s,\r,,g" -e "s,hammerdb>,,g" -e "s,after\#[0-9]*,,g" >> $hammerdb_log_dir/${pgrun_file_name}
set argv [list $pg_rampup $pg_duration $1]
set argc 3
source ${current_dir}/pgrun.tcl
!
    echo "Done"
}

initialize_db
create_backup

first_iteration="true"
for cur_vu in ${pg_benchmark_vu}; do

    log_file=$pg_log_dir/pglog-${cur_vu}-${DATE}

    if [ "$first_iteration" != "true" ]; then
        copy_backup_to_pg $prev_log_file
    fi
    pg_ctl -D $pg_data_dir -l $log_file -t $pg_ctl_timeout start

    run_optimizations
    run_hammerdb_benchmark $cur_vu

    first_iteration="false"
    prev_log_file=$log_file
done

echo "Clearing backup dir"
rm -rf $backup_dir
echo "Done"

grep -e 'VU TEST' -e 'System achieved' $hammerdb_log_dir/${pgrun_file_name} > $hammerdb_result_dir/${result_file_name}
pg_ctl -D $pg_data_dir -l $log_file -t $pg_ctl_timeout stop -m immediate
echo "Benchmark is finished"

cd $current_dir
