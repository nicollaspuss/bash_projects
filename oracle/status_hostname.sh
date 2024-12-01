#!/bin/bash
# ------------------------------------------------------------
# --- Name: Nicollas Puss - Project: Status of Server --------
# --- Date: 30/11/2024 - Oracle Database - Shell Scripting ---
# +-----------------------------------------------------------
# | V1: Setting information about host server.
# +-----------------------------------------------------------

# Set variables about Oracle Server:
hostinfo(){
    hostname=$(hostname)
    date=$(date +"%d/%m/%Y %H:%M:%S")
    SOVersion=$(cat /etc/os-release | grep PRETTY | cut -c 13- | sed 's/^\"//;s/\"$//')
    Model=$(lscpu | grep "Model name" | cut -c 22-)
    Architecture=$(lscpu | grep "Architecture" | cut -c 22-)
    VCPUs=$(cat /proc/cpuinfo | grep processor | wc -l)
    Memory=$(cat /proc/meminfo | grep MemTotal | awk '{print int($2/1024/1024*100)/100 " GB"}')
    Serverpool=$(/grid/product/19.17.0.0.0/bin/crsctl status serverpool | grep NAME | awk -F= '{print $2}')  
}

# Function - PMON Processes:
PMONProcesses(){    
    ps -ef | grep smon | cut -c 58- | sed '$d' | sort | sed 's/^/| /' | sed 's/$/                  |/' >> /tmp/pmon_processes.txt
}

# Function - Status Diskgroups:
StatusDiskgroups(){

    # Verify lists of databases according the PMON status:
    cat /tmp/pmon_processes.txt | sed 's/^| //' | sed 's/ *|$//' >> /tmp/databases.txt
    dbname=$(cat /tmp/databases.txt)
    for db in $dbname; do 
        echo "$db" | . oraenv > /dev/null
        srvctl config database -d $db | grep "Disk Groups" | awk -F': ' '{print $2}' >> /tmp/diskgroups.txt
    done
}

# Functions:
main(){
    rm /tmp/pmon_processes.txt
    rm /tmp/databases.txt
    rm /tmp/diskgroups.txt
    clear
    hostinfo
        sleep 0.1
            echo "+-------------------------------------------------------------------------------------------------------------+"
            echo "| Status Services - $(tput setaf 1)Oracle$(tput sgr0) - $hostname - $(tput setaf 1)$date$(tput sgr0) - $SOVersion "
            sleep 0.1
            echo "| $(tput setaf 1)Server$(tput sgr0) - $Model - $Architecture - $VCPUs vCPUs - $(tput setaf 1)Total Memory Allocated$(tput sgr0) - $Memory"
            echo "+-------------------------------------------------------------------------------------------------------------+"
            sleep 1
            echo "Log: /tmp/status_hostname.txt"
            echo
            echo "+-----------------------------"
            echo "| Serverpool: $(tput setaf 1)$Serverpool$(tput sgr0)"  
            echo "+-----------------------------"
            echo
            echo "+-----------------------+-----------------+-------------------------------------------------+--------------------------------------+-------------------------+"
            echo "| PMON Active Processes | State Diskgroup | Active services of Database - Eg.: app_database | Oracle Home - Active Oracle Database | Full Version - Database |"
            echo "+-----------------------+-----------------+----------------------------------------------------------------------------------------+-------------------------+"
            # PMONProcesses
            # StatusDiskgroups
            # paste /tmp/pmon_processes.txt /tmp/diskgroups.txt | sed 's/|[[:space:]]*/| /g'
        echo "+-----------------------+-----------------+"
}

# Execute script:
main
