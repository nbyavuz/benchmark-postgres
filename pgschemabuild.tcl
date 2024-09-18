puts "SETTING CONFIGURATION"

global complete
proc wait_to_complete {} {
global complete
set complete [vucomplete]
if {!$complete} {after 20000 wait_to_complete} else { exit }
}


dbset db pg
dbset bm tpc-c
diset connection pg_host localhost
diset connection pg_port 5432
diset tpcc pg_count_ware [expr [lindex $argv 0]]
diset tpcc pg_num_vu [expr [lindex $argv 1]]
diset tpcc pg_partition false
diset tpcc pg_superuser postgres
diset tpcc pg_superuserpass postgres
diset tpcc pg_defaultdbase postgres
diset tpcc pg_user tpcc
diset tpcc pg_pass tpcc
diset tpcc pg_dbase tpcc

print dict
buildschema
wait_to_complete
vudestroy

