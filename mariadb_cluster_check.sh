#!/bin/bash

# Variáveis de configuração
MYSQL_USER="root"
MYSQL_PASSWORD="password"
MYSQL_HOST="localhost"

# Obtém o estado do cluster
CLUSTER_STATUS=$(mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -h $MYSQL_HOST -e "SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME='wsrep_local_state_comment';" | awk '{print $1}' | sed -n "2p")

# Verifica se o cluster está sincronizado
if [ "$CLUSTER_STATUS" == "Synced" ]; then
  echo "Cluster está sincronizado"
  exit 0
else
  echo "Cluster Não está sincronizado"
  exit 2
fi

# Obtém o número de nós no cluster
CLUSTER_NODES=$(mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -h $MYSQL_HOST -e "SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME='wsrep_cluster_size';" | awk '{print $1}' | sed -n "2p")

# Obtém o hostname do servidor atual
CURRENT_SERVER=$(hostname)

# Loop para verificar o status de cada nó
for ((i=1;i<=CLUSTER_NODES;i++)); do
  # Obtém o hostname do nó atual
  NODE_HOSTNAME=$(mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -h $MYSQL_HOST -e "SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(VARIABLE_VALUE, ',', -1*$i), ',', 1) FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME='wsrep_incoming_addresses';" | awk '{print $1}' | sed -n "2p")

  # Obtém o status do nó atual
  NODE_STATUS=$(mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -h $MYSQL_HOST -e "SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME='wsrep_local_state_comment' AND VARIABLE_VALUE NOT LIKE 'Synced' AND VARIABLE_VALUE NOT LIKE 'Donor/Desynced';" | awk '{print $1}' | sed -n "$i"p)

  # Obtém o status do nó master
  NODE_MASTER=$(mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -h $MYSQL_HOST -e "SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME='wsrep_cluster_status';" | awk '{print $1}' | sed -n "$i"p)

  # Exibe o status do nó atual
  if [ "$NODE_HOSTNAME" == "$CURRENT_SERVER" ]; then
    if [ "$NODE_MASTER" == "Primary" ]; then
      echo "Node $i: $NODE_HOSTNAME - $NODE_STATUS (Current Server - Master)"
    else
      echo "Node $i: $NODE_HOSTNAME - $NODE_STATUS (Current Server - Not Master)"
    fi
  else
    echo "Node $i: $NODE_HOSTNAME - $NODE_STATUS"
  fi
done
