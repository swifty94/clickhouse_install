#!/bin/bash
###################################
#   Clickhouse installation  	  #
###################################
###################################
#   FT schema installation  	  #
###################################
#   Created by Kirill Rudenko	  #
###################################

prepare(){
	sudo yum install -y pygpgme yum-utils coreutils epel-release
	cat <<"EOF" | sudo tee /etc/yum.repos.d/altinity_clickhouse.repo
[altinity_clickhouse]
name=altinity_clickhouse
baseurl=https://packagecloud.io/altinity/clickhouse/el/7/$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/altinity/clickhouse/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300

[altinity_clickhouse-source]
name=altinity_clickhouse-source
baseurl=https://packagecloud.io/altinity/clickhouse/el/7/SRPMS
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/altinity/clickhouse/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
sudo yum -q makecache -y --disablerepo='*' --enablerepo='altinity_clickhouse'
}

setup(){
 sudo yum install clickhouse-server clickhouse-client -y
 sudo service clickhouse-server start > /dev/null 2>&1
 if [ $? != 0 ]
 then
 	echo "Clickhouse server can't be started. Check the logs in /var/log/clickhouse-server/"
 	exit 1
 fi
}

db_import(){
	if [ -f clickhouse.sql ]; then
		cat clickhouse.sql |clickhouse-client -mn
	else
		cat << "EOF" | sudo tee clickhouse.sql
		create database ftacs_qoe_ui_data;
        use ftacs_qoe_ui_data;
		create table `cpe_data` (`created` DateTime,`serial` String,`name_id` UInt32,`value` String,`periodic` UInt32) ENGINE MergeTree() PARTITION BY toDate(created) ORDER by (serial,name_id,created);
		create table `kpi_data` (`created` DateTime,`serial` String,`kpi_id` UInt32,`value` Float64,`periodic` UInt32) ENGINE MergeTree() PARTITION BY toDate(created) ORDER by (serial,kpi_id,created);
		create table `kpi_threshold_history` (`id` UUID default generateUUIDv4(), `created` DateTime, `updated` DateTime,`serial` String,`kpi_id` UInt32, `child_kpi_id` Nullable(UInt32),`value` Float64,`threshold_condition` String, `state` Int8, `level` Int8) ENGINE MergeTree() PARTITION BY toDate(created) ORDER by (serial,kpi_id,created);
		CREATE MATERIALIZED VIEW kpi_data_aggregated ENGINE = AggregatingMergeTree(date, (kpi_id, serial,intDiv(toRelativeMinuteNum(createdDate), 5)), 8192) POPULATE AS SELECT toDate(toStartOfFiveMinute(min(created))) as date, serial, kpi_id, toStartOfFiveMinute(min(created)) AS createdDate,avgState(value) AS avg, minState(value) AS min, maxState(value) AS max FROM kpi_data GROUP BY kpi_id,serial,intDiv(toRelativeMinuteNum(created), 5);
		create table `wifi_cpe_data` (`created` DateTime,`serial` String,`name_id` UInt32,`ssid` String,`channel` UInt8,`changing` Int8) ENGINE MergeTree() PARTITION BY toDate(created) ORDER by (serial,name_id,created);
		create table `wifi_collisions` (`created` DateTime,`serial` String,`name_id` UInt32,`ssid` String,`channel` UInt8,`signal` Int8) ENGINE MergeTree() PARTITION BY toDate(created) ORDER by (serial,name_id,created);
		create table `cpe_data_prev` (`created` DateTime,`serial` String,`name_id` UInt32,`value` String) ENGINE ReplacingMergeTree() PARTITION BY toDate(created) ORDER by (serial,name_id);
		create table `kpi_data_prev` (`created` DateTime,`serial` String,`kpi_id` UInt32,`value` Float64,`periodic` UInt32 default 7200) ENGINE ReplacingMergeTree() PARTITION BY toDate(created) ORDER by (serial,kpi_id);
		create table `cpe_monitor_history` (`started` DateTime, `finished` Nullable(DateTime) default null,`serial` String,`name_id` UInt32) ENGINE ReplacingMergeTree() PARTITION BY toDate(started) ORDER by (serial,name_id,started);
		create table `kpi_threshold_history_repl` (`id` UUID default generateUUIDv4(), `created` DateTime, `updated` DateTime,`serial` String,`kpi_id` UInt32, `child_kpi_id` UInt32 default 0,`value` Float64,`threshold_condition` String, `state` Int8, `level` Int8) ENGINE ReplacingMergeTree() PARTITION BY toDate(created) ORDER by (created,serial,kpi_id,child_kpi_id);  	
EOF
		sleep 2
		cat clickhouse.sql |clickhouse-client -mn
	fi


}

main(){
	prepare
	sleep 2
	setup
	sleep 2
	db_import
}

main
