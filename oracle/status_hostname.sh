#!/bin/bash
# +---------------------------------------------------------+
# | Name: Nicollas Puss                                     |
# | Date: 30/11/2024                                        |
# | Project: Status of Local Oracle Services.               | 
# +---------------------------------------------------------+
# | V1: Adding information about PMON and State Diskgroup.  |
# +---------------------------------------------------------+
# | V2: Adding information Oracle Services.                 |
# | V2.1: Validate Type of Oracle Services.                 |
# | V2.2: Validate if Oracle Services is running or not.    |
# +---------------------------------------------------------+
# | V3: Adding information about Oracle Home.               |
# +---------------------------------------------------------+
# | V4: Adding information about Database Release Version.  |
# +---------------------------------------------------------+
# | V5: Adding information about Grid Services.             |
# +---------------------------------------------------------+
# | V6: Adding information about GoldenGate Processes.      |
# +---------------------------------------------------------+

# Set variables about Oracle Server:
hostinfo(){
    hostname=$(hostname)
    date=$(date +"%d/%m/%Y %H:%M:%S")
    SOVersion=$(cat /etc/os-release | grep PRETTY | cut -c 13- | sed 's/^\"//;s/\"$//')
    Model=$(lscpu | grep "Model name" | cut -c 24-)
    Architecture=$(lscpu | grep "Architecture" | cut -c 24-)
    VCPUs=$(cat /proc/cpuinfo | grep processor | wc -l)
    Memory=$(cat /proc/meminfo | grep MemTotal | awk '{print int($2/1024/1024*100)/100 " GB"}')
    Serverpool=$(/grid/product/19.17.0.0.0/bin/crsctl status serverpool | grep NAME | awk -F= '{print $2}' | grep -v -E '^(Free|Generic)$' | sed 's/^ora.//')
}

# Main function:
main(){
    clear
    hostinfo
        sleep 0.1
            echo "+--------------------------------------------------------------------------------------------------------------"
            echo "| Status Services - $(tput setaf 1)Oracle$(tput sgr0) - $hostname - $date - $SOVersion "
            sleep 0.1
            echo "| Server - $Model - $Architecture - $VCPUs vCPUs - $Memory"
            echo "+--------------------------------------------------------------------------------------------------------------"
            sleep 1
            echo "| $(tput setaf 1)Log Complete:$(tput sgr0) /tmp/status_hostname.txt"
            echo "| $(tput setaf 1)Recomendation:$(tput sgr0) Execute the status_hostname script with screen 10-point size."
            echo "| $(tput setaf 1)Serverpool:$(tput sgr0)" $Serverpool
            sleep 1
            echo "+--------------------------------------------------------------------------------------------------------------"
            echo "| $(tput setaf 1)GoldenGate Processes:$(tput sgr0)" Active Manager Process in the node:

            # Verify Manager Processes in the host:
            mgr=$(ps -ef | grep mgr | grep MGR | sort | awk -F'PARAMFILE ' '{print $2}')
                echo "$mgr" | while IFS= read -r line; do
                echo "| $line"
            done
            echo "+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
            echo "|                                                                       Oracle Services                                                                                 |"
            echo "+-----------------------+-----------------+-------------------------------------------------+--------------------------------------+------------------------------------+"
            echo "| PMON Active Databases | State Diskgroup | Active Services on the node - Eg.: app_database | Oracle Home - Active Oracle Database | Database Release - Oracle Database |"
            echo "+-----------------------+-----------------+-------------------------------------------------+--------------------------------------+------------------------------------+"

            # Verify all the Process Monitor services in the host:
            pmondb=$(ps -ef | grep smon | cut -c 58- | sed '$d' | grep -Ev +ASM | sort)

            # Iterate over each service and display the results side by side:
            for db in $pmondb; do
                . oraenv <<< $db > /dev/null 2>&1
                diskgroup=$(srvctl config database -d $db | grep "Disk Groups" | awk -F': ' '{print $2}')
                oraclehome=$(srvctl config database -d $db | grep "Oracle home" | awk -F': ' '{print $2}')
                fullversion=$($oraclehome/OPatch/opatch lsinventory | grep "Database Release Update" | head -n 1 | awk -F': ' '{print $3}' | sed 's/\"//g')

                # Handle services, splitting each service onto a new line if there are multiple:
                services=$(srvctl config service -d $db | grep "Service name" | awk -F': ' '{print $2}')
                cardinalities=$(srvctl config service -d $db | grep "Cardinality" | awk -F': ' '{print $2}')
    
                IFS=$'\n' read -rd '' -a service_array <<<"$services"
                IFS=$'\n' read -rd '' -a cardinality_array <<<"$cardinalities"
    
                for i in "${!service_array[@]}"; do
                    service="${service_array[$i]} - ${cardinality_array[$i]}"
        
                    # Check if the service is running
                    status=$(srvctl status service -d $db -s ${service_array[$i]} | grep "is running" || true)
        
                    if [ -n "$status" ]; then
                        if [ $i -eq 0 ]; then
                            printf "| %-21s | %-15s | %-47s | %-36s | %-34s |\n" "$db" "$diskgroup" "$service" "$oraclehome" "$fullversion"
                        else
                            printf "| %-21s | %-15s | %-47s | %-36s | %-34s |\n" "" "" "$service" "" ""
                        fi
                    fi
                done
            done
            echo "+-----------------------+-----------------+-------------------------------------------------+--------------------------------------+------------------------------------+"
            echo
            echo "+-----------------------------------------------------------------------------------------------------------------------+"
            echo "|                                                 Grid Services                                                         |"
            echo "+----------------------------+-----------------+----------------------------------+-------------------------------------+"
            echo "| PMON Active Grid Processes | State Diskgroups| Grid Home - Active Grid Database | Grid Release - Grid Database Release|"
            echo "+----------------------------+-----------------+----------------------------------+-------------------------------------+"
}

# Execution of the code:
main
