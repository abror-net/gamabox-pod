#!/usr/bin/env bash

function run_test_case () {
  _helm_diff_and_install ${_TEST_DIR}/gold/basic.gold  \
    hdfs-k8s  \
    -n abror-hdfs  \
    --values ${_TEST_DIR}/values/common.yaml  \
    --values ${_TEST_DIR}/values/custom-hadoop-config.yaml  \
    --set "global.dataNodeHostPath={/home/liga/data/hdfs-data0,/home/liga/data/hdfs-data1}"

  if [[ "${DRY_RUN_ONLY:-false}" = "true" ]]; then
    return
  fi

  k8s_single_pod_ready -l app=zookeeper,release=abror-hdfs
  k8s_all_pods_ready 3 -l app=hdfs-journalnode,release=abror-hdfs
  k8s_all_pods_ready 2 -l app=hdfs-namenode,release=abror-hdfs
  k8s_single_pod_ready -l app=hdfs-datanode,release=abror-hdfs
  k8s_single_pod_ready -l app=hdfs-client,release=abror-hdfs
  _CLIENT=$(kubectl get pods -l app=hdfs-client,release=abror-hdfs -o name |  \
      cut -d/ -f 2)
  echo Found client pod: $_CLIENT

  echo All pods:
  kubectl get pods

  echo All persistent volumes:
  kubectl get pv

  _run kubectl exec $_CLIENT -- hdfs dfsadmin -report
  _run kubectl exec $_CLIENT -- hdfs haadmin -getServiceState nn0
  _run kubectl exec $_CLIENT -- hdfs haadmin -getServiceState nn1

  _run kubectl exec $_CLIENT -- hadoop fs -rm -r -f /tmp
  _run kubectl exec $_CLIENT -- hadoop fs -mkdir /tmp
  _run kubectl exec $_CLIENT -- sh -c  \
    "(head -c 100M < /dev/urandom > /tmp/random-100M)"
  _run kubectl exec $_CLIENT -- hadoop fs -copyFromLocal /tmp/random-100M /tmp
}

function cleanup_test_case() {
  helm delete --purge abror-hdfs || true
}
