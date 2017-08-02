#!/bin/bash

#Node names and IP addresses of the hosts to be used
ZK_NODE="manager" # Node name of the host where zookeeper to be launched
KAFKA_NODE="manager" #Node name of the host where kafka to be launched
ORDERER_NODE="manager" #Node name of the host where orderer to be launched
PEER_NODE1="worker1"
PEER_NODE2="worker2"
PEER_NODE3="fabric07"
PEER_NODE4="fabric08"
TLS=true
function printHelp {

   echo "Usage: "
   echo " ./multihost_test_launcher.sh [opt] [value] "
   echo "    -z: number of zookeepers, default=1"
   echo "    -k: number of kafka, default=5"
   echo "    -o: number of orderers, default=4"
   echo "    -r: number of organizations, default=2"
   echo "    -c: channel name, default=myc0"
   echo " "
   echo " example: "
   echo " ./multihost_test_launcher.sh -z 1 -k 5 -o 4 -r 2 -c myc0"
   exit
}

#defaults
nZookeeper=1
nKafka=5
nOrderer=4
nOrgs=2
channel="myc0"

while getopts ":z:k:o:r:c:" opt; 
do
	case $opt in
        	z)
	  	  nZookeeper=$OPTARG
        	;;
        	k)
          	  nKafka=$OPTARG
        	;;
        	o)
          	  nOrderer=$OPTARG
        	;;
        	r)
          	  nOrgs=$OPTARG
        	;;
        	c)
          	  channel=$OPTARG
        	;;
        	\?)
      		   echo "Invalid option: -$OPTARG" >&2
      		   printHelp
      		;;
    		:)
      		  echo "Option -$OPTARG requires an argument." >&2
          	  printHelp
      		;;
   	esac
done

echo "Launching zookeepers"
for (( i=0; i<$nZookeeper; i++ ))
do
	docker service create --name zookeeper$i \
	--network my-network \
	--restart-condition none \
	--constraint 'node.hostname == '$ZK_NODE \
	--publish 2181:2181 \
	hyperledger/fabric-zookeeper:x86_64-1.0.0-beta
done

echo "Launching kafka brokers"
for (( i=0, j=9092 ; i<$nKafka; i++, j++ ))
do
	docker service create --name kafka$i \
	--network my-network \
	--restart-condition none \
	--constraint 'node.hostname == '$KAFKA_NODE \
	--env KAFKA_BROKER_ID=$i \
	--env KAFKA_MESSAGE_MAX_BYTES=103809024 \
	--env KAFKA_REPLICA_FETCH_MAX_BYTES=103809024 \
	--env KAFKA_NUM_REPLICA_FETCHERS=$nKafka \
	--env KAFKA_ZOOKEEPER_CONNECT=$ZK_IP:2181 \
	--env KAFKA_DEFAULT_REPLICATION_FACTOR=$nKafka \
	--env KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE=false \
	--publish $j:9092 \
	hyperledger/fabric-kafka:x86_64-1.0.0-beta
done

sleep 10

echo "Launching Orderers"
for (( i=0, j=7050 ; i<$nOrderer ; i++, j=j+20 ))
do 
	docker service create --name orderer$i \
	--network my-network  \
	--restart-condition none \
        --hostname orderer$i \
	--host orderer0.example.com:10.0.0.13 \
        --host orderer1.example.com:10.0.0.15 \
        --host orderer2.example.com:10.0.0.17 \
        --host peer0.org1.example.com:10.0.0.19 \
        --host peer1.org1.example.com:10.0.0.21 \
        --host peer2.org1.example.com:10.0.0.23 \
        --host peer3.org1.example.com:10.0.0.25 \
        --host peer4.org1.example.com:10.0.0.27 \
        --host peer5.org1.example.com:10.0.0.29 \
        --host peer6.org1.example.com:10.0.0.31 \
        --host peer7.org1.example.com:10.0.0.33 \
        --host peer0.org2.example.com:10.0.0.35 \
        --host peer1.org2.example.com:10.0.0.37 \
        --host peer2.org2.example.com:10.0.0.39 \
        --host peer3.org2.example.com:10.0.0.41 \
        --host peer4.org2.example.com:10.0.0.43 \
        --host peer5.org2.example.com:10.0.0.45 \
        --host peer6.org2.example.com:10.0.0.47 \
        --host peer7.org2.example.com:10.0.0.49 \
        --host ca-org1:10.0.0.51 \
        --host ca-org2:10.0.0.53 \
	--constraint 'node.hostname == '$ORDERER_NODE \
	--env ORDERER_GENERAL_LOGLEVEL=DEBUG \
	--env ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
	--env ORDERER_GENERAL_GENESISMETHOD=file \
	--env ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/genesis.block \
	--env ORDERER_GENERAL_LOCALMSPID=OrdererMSP \
	--env ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp  \
        --env ORDERER_GENERAL_TLS_ENABLED=$TLS \
        --env ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key \
        --env ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt \
        --env ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt] \
	--workdir /opt/gopath/src/github.com/hyperledger/fabric  \
	--mount type=bind,src=/home/ibmadmin/multihost_test/channels/genesis.block,dst=/var/hyperledger/orderer/genesis.block  \
	--mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/ordererOrganizations/example.com/orderers/orderer$i.example.com/msp,dst=/var/hyperledger/orderer/msp \
        --mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/ordererOrganizations/example.com/orderers/orderer$i.example.com/tls,dst=/var/hyperledger/orderer/tls \
	--publish $j:7050 \
	hyperledger/fabric-orderer:x86_64-1.0.0-beta orderer
done

echo "Launching Peers"
total_orgs=$nOrgs

for (( i=0, port1=7051, tmp_port=7061 , tmp_ip=19 ; i<$total_orgs ; i++, port1=port1+80, tmp_port=tmp_port+80, tmp_ip=tmp_ip+16  )) 
do
        #tmp=$((i % 2))
        #case $tmp in 
        #     0) hostname1=$PEER_NODE1 ; ip1=$PEER_IP1 ;;
        #     1) hostname1=$PEER_NODE3 ; ip1=$PEER_IP3 ;;
        #esac
        echo $port1
	echo "Launching org${i}-peer0"
	docker service create --name org${i}-peer0 \
	--network my-network \
	--restart-condition on-failure \
        --host orderer0.example.com:10.0.0.13 \
        --host orderer1.example.com:10.0.0.15 \
        --host orderer2.example.com:10.0.0.17 \
        --host peer0.org1.example.com:10.0.0.19 \
        --host peer1.org1.example.com:10.0.0.21 \
        --host peer2.org1.example.com:10.0.0.23 \
        --host peer3.org1.example.com:10.0.0.25 \
        --host peer4.org1.example.com:10.0.0.27 \
        --host peer5.org1.example.com:10.0.0.29 \
        --host peer6.org1.example.com:10.0.0.31 \
        --host peer7.org1.example.com:10.0.0.33 \
        --host peer0.org2.example.com:10.0.0.35 \
        --host peer1.org2.example.com:10.0.0.37 \
        --host peer2.org2.example.com:10.0.0.39 \
        --host peer3.org2.example.com:10.0.0.41 \
        --host peer4.org2.example.com:10.0.0.43 \
        --host peer5.org2.example.com:10.0.0.45 \
        --host peer6.org2.example.com:10.0.0.47 \
        --host peer7.org2.example.com:10.0.0.49 \
        --host ca-org1:10.0.0.51 \
        --host ca-org2:10.0.0.53 \
	--constraint 'node.hostname == '$PEER_NODE1 \
	--env CORE_PEER_ADDRESSAUTODETECT=false \
	--env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
        --env CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=my-network \
        --env CORE_VM_DOCKER_HOSTCONFIG_EXTRAHOSTS=peer0.org`expr $i + 1`.example.com:10.0.0.$tmp_ip \
	--env CORE_LOGGING_LEVEL=DEBUG \
	--env CORE_PEER_TLS_ENABLED=$TLS \
	--env CORE_PEER_ENDORSER_ENABLED=true \
	--env CORE_PEER_GOSSIP_ORGLEADER=false \
	--env CORE_PEER_GOSSIP_USELEADERELECTION=false \
	--env CORE_PEER_PROFILE_ENABLED=true \
	--env CORE_PEER_ADDRESS=peer0.org`expr $i + 1`.example.com:7051 \
	--env CORE_PEER_ID=peer0.org`expr $i + 1`.example.com \
	--env CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp \
	--env CORE_PEER_LOCALMSPID=Org`expr $i + 1`MSP \
	--env CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_IP1:$port1 \
        --env CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org`expr $i + 1`.example.com:7051 \
        --env CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
        --env CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
        --env CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
        --env CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
	--workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
	--mount type=bind,src=/var/run/,dst=/host/var/run/ \
	--mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer0.org`expr $i + 1`.example.com/msp,dst=/etc/hyperledger/fabric/msp \
        --mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer0.org`expr $i + 1`.example.com/tls,dst=/etc/hyperledger/fabric/tls \
	--publish $port1:7051 \
	--publish `expr $port1 + 2`:7053 \
	hyperledger/fabric-peer:x86_64-1.0.0-beta peer node start --peer-defaultchain=false

        for (( p=1, port2=$tmp_port, ip=${tmp_ip}+2 ; p < 8 ; p++, port2=port2+10, ip=ip+2 ))	
        do
        	tmp1=$((p % 4))
        	case $tmp1 in
             	0) hostname2=$PEER_NODE1 ; ip2=$PEER_IP1 ; leader=false ;;
             	1) hostname2=$PEER_NODE2 ; ip2=$PEER_IP2 ; leader=true ;;
             	2) hostname2=$PEER_NODE3 ; ip2=$PEER_IP3 ; leader=false ;;
             	3) hostname2=$PEER_NODE4 ; ip2=$PEER_IP4 ; leader=false ;;
        	esac
        	echo $port2
		echo "Launching org${i}-peer$p"
		docker service create --name org${i}-peer${p} \
       		--network my-network \
       		--restart-condition on-failure \
        	--host orderer0.example.com:10.0.0.13 \
        	--host orderer1.example.com:10.0.0.15 \
        	--host orderer2.example.com:10.0.0.17 \
        	--host peer0.org1.example.com:10.0.0.19 \
        	--host peer1.org1.example.com:10.0.0.21 \
        	--host peer2.org1.example.com:10.0.0.23 \
        	--host peer3.org1.example.com:10.0.0.25 \
        	--host peer4.org1.example.com:10.0.0.27 \
        	--host peer5.org1.example.com:10.0.0.29 \
        	--host peer6.org1.example.com:10.0.0.31 \
        	--host peer7.org1.example.com:10.0.0.33 \
        	--host peer0.org2.example.com:10.0.0.35 \
        	--host peer1.org2.example.com:10.0.0.37 \
        	--host peer2.org2.example.com:10.0.0.39 \
        	--host peer3.org2.example.com:10.0.0.41 \
        	--host peer4.org2.example.com:10.0.0.43 \
        	--host peer5.org2.example.com:10.0.0.45 \
        	--host peer6.org2.example.com:10.0.0.47 \
        	--host peer7.org2.example.com:10.0.0.49 \
        	--host ca-org1:10.0.0.51 \
        	--host ca-org2:10.0.0.53 \
        	--constraint 'node.hostname == '$hostname2 \
       		--env CORE_PEER_ADDRESSAUTODETECT=false \
       		--env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
        	--env CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=my-network \
        	--env CORE_VM_DOCKER_HOSTCONFIG_EXTRAHOSTS=peer$p.org`expr $i + 1`.example.com:10.0.0.$ip \
       		--env CORE_LOGGING_LEVEL=DEBUG \
       		--env CORE_PEER_TLS_ENABLED=$TLS \
       		--env CORE_PEER_ENDORSER_ENABLED=true \
       		--env CORE_PEER_GOSSIP_ORGLEADER=$leader \
       		--env CORE_PEER_GOSSIP_USELEADERELECTION=false \
       		--env CORE_PEER_PROFILE_ENABLED=true \
       		--env CORE_PEER_ADDRESS=peer$p.org`expr $i + 1`.example.com:7051 \
       		--env CORE_PEER_ID=peer$p.org`expr $i + 1`.example.com \
       		--env CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp \
       		--env CORE_PEER_LOCALMSPID=Org`expr $i + 1`MSP \
       		--env CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org`expr $i + 1`.example.com:7051 \
        	--env CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
        	--env CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
        	--env CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
        	--env CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
        	--workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
       		--mount type=bind,src=/var/run/,dst=/host/var/run/ \
       		--mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer$p.org`expr $i + 1`.example.com/msp,dst=/etc/hyperledger/fabric/msp \
        	--mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer$p.org`expr $i + 1`.example.com/tls,dst=/etc/hyperledger/fabric/tls \
       		--publish $port2:7051 \
       		--publish `expr $port2 + 2`:7053 \
       		hyperledger/fabric-peer:x86_64-1.0.0-beta peer node start --peer-defaultchain=false
        done
done

echo "Launching CA"

        docker service create --name ca_org1 \
        --network my-network \
        --hostname ca-org1 \
        --restart-condition none \
        --constraint 'node.hostname == '$PEER_NODE1 \
        --env FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
        --env FABRIC_CA_SERVER_CA_NAME=ca-org1 \
        --env FABRIC_CA_SERVER_TLS_ENABLED=$TLS \
        --env FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem \
        --env FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/28fcb638f699fc7f19c83230014f763cc385d373ba7a78326344dfa9bd4f4665_sk \
        --env FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem \
        --env FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/28fcb638f699fc7f19c83230014f763cc385d373ba7a78326344dfa9bd4f4665_sk \
        --publish 7054:7054 \
        --mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/peerOrganizations/org1.example.com/ca/,dst=/etc/hyperledger/fabric-ca-server-config \
        hyperledger/fabric-ca:x86_64-1.0.0-beta sh -c 'fabric-ca-server start -b admin:adminpw' -d

        docker service create --name ca_org2 \
        --network my-network \
        --restart-condition none \
        --constraint 'node.hostname == '$PEER_NODE1 \
        --env FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
        --env FABRIC_CA_SERVER_CA_NAME=ca-org2 \
        --env FABRIC_CA_SERVER_TLS_ENABLED=$TLS \
        --env FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org2.example.com-cert.pem \
        --env FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/7b734f65e8ff6870853926d21457c05f13276688c822d557b61222f4b8e220be_sk \
        --env FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org2.example.com-cert.pem \
        --env FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/7b734f65e8ff6870853926d21457c05f13276688c822d557b61222f4b8e220be_sk \
        --publish 8054:7054 \
        --mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config/peerOrganizations/org2.example.com/ca/,dst=/etc/hyperledger/fabric-ca-server-config \
        hyperledger/fabric-ca:x86_64-1.0.0-beta sh -c 'fabric-ca-server start -b admin:adminpw' -d

#
sleep 15
#
echo "Launching CLI"
docker service create --name cli \
	--tty=true \
	--network my-network \
	--restart-condition none \
        --host orderer0.example.com:10.0.0.13 \
        --host orderer1.example.com:10.0.0.15 \
        --host orderer2.example.com:10.0.0.17 \
        --host peer0.org1.example.com:10.0.0.19 \
        --host peer1.org1.example.com:10.0.0.21 \
        --host peer2.org1.example.com:10.0.0.23 \
        --host peer3.org1.example.com:10.0.0.25 \
        --host peer4.org1.example.com:10.0.0.27 \
        --host peer5.org1.example.com:10.0.0.29 \
        --host peer6.org1.example.com:10.0.0.31 \
        --host peer7.org1.example.com:10.0.0.33 \
        --host peer0.org2.example.com:10.0.0.35 \
        --host peer1.org2.example.com:10.0.0.37 \
        --host peer2.org2.example.com:10.0.0.39 \
        --host peer3.org2.example.com:10.0.0.41 \
        --host peer4.org2.example.com:10.0.0.43 \
        --host peer5.org2.example.com:10.0.0.45 \
        --host peer6.org2.example.com:10.0.0.47 \
        --host peer7.org2.example.com:10.0.0.49 \
        --host ca-org1:10.0.0.51 \
        --host ca-org2:10.0.0.53 \
	--constraint 'node.hostname == manager' \
	--env GOPATH=/opt/gopath \
	--env CORE_PEER_ADDRESSAUTODETECT=false \
	--env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
	--env CORE_PEER_TLS_ENABLED=$TLS \
	--env CORE_LOGGING_LEVEL=DEBUG \
	--env CORE_PEER_ID=cli \
	--env CORE_PEER_ENDORSER_ENABLED=true \
	--env CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
	--env CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
	--env CORE_PEER_GOSSIP_IGNORESECURITY=true \
	--env CORE_PEER_LOCALMSPID=Org0MSP \
	--env CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
	--workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
	--mount type=bind,src=/var/run,dst=/host/var/run \
	--mount type=bind,src=/home/ibmadmin/multihost_test/crypto-config,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto \
	--mount type=bind,src=/home/ibmadmin/multihost_test/channels,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts \
	--mount type=bind,src=/home/ibmadmin/multihost_test/scripts,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts \
	--mount type=bind,src=/home/ibmadmin/multihost_test/chaincodes,dst=/opt/gopath/src/github.com/hyperledger/fabric/examples/chaincode \
	hyperledger/fabric-tools:x86_64-1.0.0-beta  /bin/bash -c './scripts/script.sh '$channel'; '
