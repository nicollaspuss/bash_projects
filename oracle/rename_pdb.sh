#!/bin/bash
# ----------------------------------
# --- Name: Nicollas Puss ----------
# --- Date: 20/11/2024 -------------
# --- Project: Oracle Rename PDB ---
# ---------------------------------------------------------------------------------------------
# Obs.: Version: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - DBRU - 19.17.0.0.0
# ---------------------------------------------------------------------------------------------
# Export the environment variables:
export ORACLE_SID=orcl
export ORACLE_HOME=/oracle/product/19.17.0.0.0
export PATH=PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin:/oracle/product/19.17.0.0.0/bin:/oracle/product/19.17.0.0.0/OPatch:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin
clear

# Function to see the PDBs in the CDB:
validate_pdbname(){
sqlplus / as sysdba << EOFSQL > /tmp/pdbs.txt
set pages 100
set lines 100
col name format a50
select name as Pluggables from v\$pdbs where name not in ('PDB\$SEED') order by name;
exit;
EOFSQL
}

# Function to rename the PDB:
rename_pdbname(){
echo "*****************************"
echo "*** VERIFYING PDBS IN CDB ***"
echo "*****************************"
    # Generate PDB lists:
    PDBS=$(cat /tmp/pdbs.txt | sed '1,12d' | head -n -3)

    # Seeing in the screen PDB lists:
    echo -e "$PDBS"

    # Verifying the PDB name to rename:
    echo
    read -p "1) Which PDB do you want to rename? " pdb_name

    # Validate if the PDB exists:
    if echo "$PDBS" | grep -q -w "$pdb_name"; then
        echo "The PDB already exists."
        echo
        echo "EG: NEWNAMEPDB"
        read -p "2) Which name do you want to put? " new_name 
        if echo "$new_name" | grep -q -w "$PDBS"; then
            echo "The PDB already exists."
            echo
            exit
        else 
            echo "The PDB does not exists. Processing."
            echo "Log: /tmp/renamepdb.txt"
            echo
            while true; do
            read -p "3) Do you want to continue? (y/Y to continue, n/N to cancel): " user_response
            case "$user_response" in
                [yY])
                    echo "You chose to continue. Proceeding with the process."
                    sleep 2
                    export ORACLE_SID=orcl
                    export ORACLE_HOME=/oracle/product/19.17.0.0.0
                    export PATH=PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin:/oracle/product/19.17.0.0.0/bin:/oracle/product/19.17.0.0.0/OPatch:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin
                    sqlplus / as sysdba << EOFSQL | tee -a /tmp/renamepdb.txt
alter pluggable database $pdb_name close immediate;
alter pluggable database $pdb_name open restricted;
alter session set container = $pdb_name;
alter pluggable database rename global_name to $new_name;
alter pluggable database close immediate;
alter pluggable database open;
show con_name;
exit;
EOFSQL
                    break
                    ;;
                [nN])
                    echo "You chose not to continue. Exiting the process."
                    exit 0
                    ;;
                *)
                    echo "Invalid input. Please enter 's/S' to continue or 'n/N' to cancel."
                    echo "Returning to the previous menu."
                    echo
                    continue
                    ;;
            esac
        done                 
        fi
    else
        echo "The PDB does not exists. Please, validate again."
    fi
}

# The main function:
main(){
    validate_pdbname
    rename_pdbname
}

# Executing the code:
main
