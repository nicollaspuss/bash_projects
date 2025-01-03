#!/bin/bash
# +---------------------------------------------------------+
# | Name: Nicollas Puss                                     |
# | Date: 30/11/2024                                        |
# | Project: Status of Local Oracle Services.               |
# +---------------------------------------------------------+
# | V1: Adding information about PMON and State Diskgroups. |
# +---------------------------------------------------------+
# | V2: Adding information Oracle Services.                 |
# | V2.1: Validate Type of Oracle Service.                  |
# | V2.2: Validate if Oracle Service is running or not.     |
# +---------------------------------------------------------+
# | V3: Adding information about Oracle Home.               |
# +---------------------------------------------------------+
# | V4: Adding information about Database Release Version.  |
# +---------------------------------------------------------+
# | V5: Adding information about Grid Services.             |
# | V5.1: Validate status of Oracle Diskgroup.              |
# | V5.2: Validate if Oracle Diskgroup exists.              |
# +---------------------------------------------------------+
# | V6: Adding information about GoldenGate Processes.      |
# +---------------------------------------------------------+

# Set variables about Oracle Server:
hostinfo(){
    hostname=$(hostname)
    date=$(date +"%d/%m/%Y %H:%M:%S")
    soversion=$(cat /etc/os-release | grep REDHAT_BUGZILLA_PRODUCT= | cut -c 26- | sed 's/^\"//;s/\"$//')
    model=$(lscpu | grep "Model name" | cut -c 24-)
    architecture=$(lscpu | grep "Architecture" | cut -c 24-)
    vcpus=$(cat /proc/cpuinfo | grep processor | wc -l)
    memory=$(cat /proc/meminfo | grep MemTotal | awk '{print int($2/1024/1024*100)/100 "gb"}')
    pmongrid=$(ps -ef | grep pmon | cut -c 60- | sed '$d' | grep ASM | sort | sed 's/[0-9]*$//')
    gridhome=$(cat /etc/oratab | grep "$pmongrid" | awk -F':' '{print $2}' | cut -d' ' -f1)
    serverpool=$($gridhome/bin/crsctl status serverpool | grep NAME | awk -F= '{print $2}' | grep -Ev "Free|Generic" | sed 's/^ora.//')
}

# Main function:
main(){
    clear
    hostinfo
        sleep 0.1
            echo "+--------------------------------------------------------------------------------------------------------------"
            echo "| Status Services - Oracle - $hostname - $date - $soversion "
            sleep 0.1
            echo "| Server - $model - $architecture - $vcpus vCPUs - $memory"
            echo "+--------------------------------------------------------------------------------------------------------------"
            sleep 1
            echo "| Complete Log: /tmp/status_hostname.txt"
            echo "| Recomendation: Execute the status_hostname script with screen 10-point size."
            echo "| Serverpool:" $serverpool
            sleep 1
            echo "+--------------------------------------------------------------------------------------------------------------"
            echo "| GoldenGate Processes: Active Manager Process in the node:"

            # Verify Manager Processes in the host:
            mgr=$(ps -ef | grep mgr | grep MGR | sort | awk -F'PARAMFILE ' '{print $2}')
                echo "$mgr" | while IFS= read -r line; do
                echo "| $line"
            done

            # List the Oracle Services in the host:
            echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
            echo "|                                                                                        Oracle Services                                                                                     |"
            echo "+--------------------------------+-----------------------------+-------------------------------------------------+--------------------------------------+------------------------------------+"
            echo "| PMON Active Databases - Oracle | Diskgroup Database - Oracle | Active Services on the node - Eg.: app_database | Oracle Home - Active Oracle Database | Database Release - Oracle Database |"
            echo "+--------------------------------+-----------------------------+-------------------------------------------------+--------------------------------------+------------------------------------+"

            # Verify all the Process Monitor services in the host for Databases:
            pmondb=$(ps -ef | grep pmon | cut -c 60- | sed '$d' | grep -Ev "+ASM|osysmond.bin|auto|MG" | sort | sed 's/_[0-9]*$//')

            # Array to hold all diskgroups:
            all_diskgroups=""

            # Iterate over each service and display the results side by side:
            for db in $pmondb; do
                . oraenv <<< $db > /dev/null 2>&1
                dbdiskgroup=$(srvctl config database -d $db | grep "Disk Groups" | awk -F': ' '{print $2}')
                dboraclehome=$(srvctl config database -d $db | grep "Oracle home" | awk -F': ' '{print $2}')
                dbtype=$(srvctl config database -d $db | grep "Type" | awk -F': ' '{print $2}')
                dbfullversion=$($dboraclehome/OPatch/opatch lsinventory | grep "Update" | head -n 1 | awk -F': ' '{print $3}' | sed 's/\"//g')

                # Append diskgroups to the accumulation variable:
                all_diskgroups+="$dbdiskgroup,"
                # Handle services, splitting each service onto a new line if there are multiple:
                services=$(srvctl config service -d $db | grep "Service name" | awk -F': ' '{print $2}')
                cardinalities=$(srvctl config service -d $db | grep "Cardinality" | awk -F': ' '{print $2}')

                IFS=$'\n' read -rd '' -a service_array <<<"$services"
                IFS=$'\n' read -rd '' -a cardinality_array <<<"$cardinalities"

                for i in "${!service_array[@]}"; do
                    service="${service_array[$i]} - ${cardinality_array[$i]}"

                    # Check if the service is running:
                    status=$(srvctl status service -d $db -s ${service_array[$i]} | grep "is running" || true)

                    if [ -n "$status" ]; then
                        if [ $i -eq 0 ]; then
                            printf "| %-30s | %-27s | %-47s | %-36s | %-34s |\n" "$db - $dbtype" "$dbdiskgroup" "$service" "$dboraclehome" "$dbfullversion"
                        else
                            printf "| %-30s | %-27s | %-47s | %-36s | %-34s |\n" "" "" "$service" "" ""
                        fi
                    fi
                done
                echo "+--------------------------------+-----------------------------+-------------------------------------------------+--------------------------------------+------------------------------------+"
            done

            # Remove duplicate diskgroups:            
            all_diskgroups=$(echo $all_diskgroups | tr ',' '\n' | sort | uniq | tr '\n' ',' | sed 's/,$//')

            # List the Grid Services in the host:
            echo "|                                                                                        Grid Services                                                                                       |"
            echo "+----------------------------+-------------------------------------------------------------------------------------+----------------------------------+--------------------------------------+"
            echo "| PMON Active Grid Processes | Diskgroups State - Oracle Database - Cluster Oracle - RAC - Oracle - Database - ASM | Grid Home - Active Grid Database | Grid Release - Grid Database Release |"
            echo "+----------------------------+-------------------------------------------------------------------------------------+----------------------------------+--------------------------------------+"

            # Verify all the Process Monitor services in the host for Grid:
            pmongrid=$(ps -ef | grep pmon | cut -c 60- | sed '$d' | grep ASM | sort | sed 's/[0-9]*$//')
            gridhome=$(cat /etc/oratab | grep "$pmongrid" | awk -F':' '{print $2}' | cut -d' ' -f1) 
            gridfullversion=$($gridhome/OPatch/opatch lsinventory | grep "Update" | head -n 1 | awk -F': ' '{print $3}' | sed 's/\"//g')

            # Iterate over each diskgroup and display the status:
            IFS=',' read -r -a diskgroups <<< "$all_diskgroups"
            for dg in "${diskgroups[@]}"; do
                status=$(srvctl status diskgroup -diskgroup "$dg" 2>&1)
                if [[ $status == *"does not exist"* ]]; then
                    continue
                fi
                status=$(srvctl status diskgroup -diskgroup "$dg" | grep "Disk Group" | awk -F'Disk Group ' '{print $2}') 
                printf "| %-26s | %-83s | %-32s | %-36s |\n" "$pmongrid" "$status" "$gridhome" "$gridfullversion"
                pmongrid=""
                gridhome=""
                gridfullversion=""
            done 
            echo "+----------------------------+-------------------------------------------------------------------------------------+----------------------------------+--------------------------------------+"
}

# Execution logfile:
main | tee /tmp/status_hostname.txt
