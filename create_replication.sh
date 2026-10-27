#!/bin/bash

# Wait for GoldenGate and both databases to be healthy (first start takes a few minutes)
for container in ogg234demo db233demoW db233demoE; do
    echo "Waiting for $container to be healthy ......"
    until [ "$(docker inspect -f '{{.State.Health.Status}}' $container 2>/dev/null)" = "healthy" ]; do
        sleep 10
    done
done

hostname_ogg=("localhost")                             # Default to localhost for local Docker build
conn_propeties=("WEST:172.28.0.102" "EAST:172.28.0.103")   # Database Connection Properties: (<alias name>:<database host>)
list_region=("WEST" "EAST")                            # Database Regions Name
extract_properties=("WEST:EWEST:ew" "EAST:EEAST:ee")   # Name for the Extract (<connection alias>:<Extract_name>:<trail>)
replicat_properties=("WEST:REAST:ee" "EAST:RWEST:ew")  # Name for the replicat represents where the data come from (<connection alias>:<Replicat_name>:<trail>)
ogg_port=1055

#Create Connection to the all Databases
for region in "${conn_propeties[@]}"
do
    conn_name=`echo $region | awk -F':' '{print $1}'`
    ip=`echo $region | awk -F':' '{print $2}'`
    curl -k -X POST 'https://'$hostname_ogg':'$ogg_port'/services/v2/credentials/OracleGoldenGate/'$conn_name'' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H 'Authorization: Basic b2dnYWRtaW46V2VsY29tZSMjMTIz' \
    -d '{"userid":"oggadmin@'$ip':1521/freepdb1","password":"Welcome##123"}'
    echo 
    echo
done

# Add Schematranda, heartbeat and checkpoint tables to all Databases
for region in "${list_region[@]}"
do
    curl -k -X POST 'https://'$hostname_ogg':'$ogg_port'/services/v2/connections/OracleGoldenGate.'$region'/trandata/schema' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H 'Authorization: Basic b2dnYWRtaW46V2VsY29tZSMjMTIz' \
    -d '{"operation":"add","schemaName":"hr","allColumns": true}'
    echo
    echo
    curl -k -X POST 'https://'$hostname_ogg':'$ogg_port'/services/v2/connections/OracleGoldenGate.'$region'/tables/heartbeat' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H 'Authorization: Basic b2dnYWRtaW46V2VsY29tZSMjMTIz' \
    -d '{"frequency":60}'
    echo
    echo
    curl -k -X POST 'https://'$hostname_ogg':'$ogg_port'/services/v2/connections/OracleGoldenGate.'$region'/tables/checkpoint' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H 'Authorization: Basic b2dnYWRtaW46V2VsY29tZSMjMTIz' \
    -d '{"operation":"add","name":"oggadmin.checkpoints"}'
    echo
    echo
done

# Add Extracts
for extract in "${extract_properties[@]}"
do
    region_name=`echo $extract | awk -F':' '{print $1}'`
    extract_name=`echo $extract | awk -F':' '{print $2}'`
    extract_file=`echo $extract | awk -F':' '{print $3}'`
    echo "#######################################"
    echo "Creating extract "$extract_name" ......"
    echo "#######################################"
    curl -k -X POST 'https://'$hostname_ogg':'$ogg_port'/services/v2/extracts/'$extract_name'' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H 'Authorization: Basic b2dnYWRtaW46V2VsY29tZSMjMTIz' \
    -d '{
    "description":"Create Extract Demo",
    "config":[
        "EXTRACT '$extract_name'",
        "EXTTRAIL '$extract_file'",
        "USERIDALIAS '$region_name' DOMAIN OracleGoldenGate",
        "TRANLOGOPTIONS EXCLUDETAG 00",
        "DDL INCLUDE MAPPED",
        "TABLE HR.*;"
    ],
    "source":"tranlogs",
    "credentials":{
        "alias":"'$region_name'"
    },
    "registration":"default",
    "begin":"now",
    "targets":[
        {
        "name":"'$extract_file'",
        "sizeMB":5
        }
    ],
    "status":"running"
    }'
    echo
    echo  
done

# Add Replicat
for replicat in "${replicat_properties[@]}"
do
    region_name=`echo $replicat | awk -F':' '{print $1}'`
    replicat_name=`echo $replicat | awk -F':' '{print $2}'`
    replicat_file=`echo $replicat | awk -F':' '{print $3}'`
    echo "#########################################"
    echo "Creating replicat "$replicat_name" ......"
    echo "#########################################"
    curl -k -X POST 'https://'$hostname_ogg':'$ogg_port'/services/v2/replicats/'$replicat_name'' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H 'Authorization: Basic b2dnYWRtaW46V2VsY29tZSMjMTIz' \
    -d '{
    "description":"Create Replicat Demo",
    "config":[
        "REPLICAT '$replicat_name'",
        "USERIDALIAS '$region_name' DOMAIN OracleGoldenGate",
        "DDL INCLUDE MAPPED",
        "MAP hr.*, TARGET hr.*;"
        ],
        "credentials": {"alias":"'$region_name'"},
        "mode": {"parallel":false,"type":"integrated"},
        "source": {"name": "'$replicat_file'"},
        "checkpoint":{"table":"oggadmin.checkpoints"},
        "status": "running"
    }'
    echo
    echo  
done


echo "#########################################################################"
echo "# Please visit https://localhost:$ogg_port to explore GoldenGate        #"
echo "#########################################################################"

echo
