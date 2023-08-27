#!/usr/bin/env python3

# callout
# https://github.com/righter83/checkmk-synology-activebackup/blob/main/check_ab.php
import sqlite3
from contextlib import closing
from datetime import datetime, timedelta
from cmk_helper import *

dbc_file = "/volume1/@ActiveBackup/config.db"
dba_file = "/volume1/@ActiveBackup/activity.db"
max_days_old = 3 #

# base var
abfb_task_list  = []
abfb_job_list   = []
max_old_date    = datetime.now() - timedelta(days=max_days_old)

# class
class abfb_task(object):
    def __init__(self, task_id:int, task_name:str):
        self.task_id = task_id
        self.task_name = task_name

    def __str__(self):
        return f"{self.task_id} {self.task_name}\n"

class abfb_result(object):
    def __init__(self, status:int, task_name:str, start_timestamp:int,
                 end_timestamp:int, config:str, succes_count:int,
                 warnung_count:int, error_count:int):
        self.status             = status
        self.task_name          = task_name
        self.start_time         = datetime.fromtimestamp(start_timestamp)
        self.end_time           = datetime.fromtimestamp(end_timestamp)
        self.config             = config
        self.succes_count       = succes_count
        self.warnung_count      = warnung_count
        self.error_count        = error_count

    def __str__(self):
        return f"{self.status} | {self.task_name} | {self.start_time} | {self.end_time} | {self.succes_count} | {self.warnung_count} | {self.error_count}\n"

# main
try:
    with closing(sqlite3.connect(dbc_file)) as con:
        con.row_factory = sqlite3.Row
        with closing(con.cursor()) as cur:
            rows_tasks = cur.execute("SELECT task_id,task_name FROM task_table").fetchall()
            for task in rows_tasks:
                abfb_task_list.append(abfb_task(task['task_id'],task['task_name']))

    with closing(sqlite3.connect(dba_file)) as con:
        con.row_factory = sqlite3.Row
        with closing(con.cursor()) as cur:
            for task in abfb_task_list:
                query_string = "SELECT * FROM result_table where task_id={} and job_action=1 order by result_id desc limit 1".format(task.task_id)
                rows_jobs = cur.execute(query_string).fetchall()
                abfb_job_list.append(abfb_result(rows_jobs[0]['status'],rows_jobs[0]['task_name'],rows_jobs[0]['time_start'],rows_jobs[0]['time_end'],rows_jobs[0]['task_config'],rows_jobs[0]['success_count'],rows_jobs[0]['warning_count'],rows_jobs[0]['error_count']))

    for j in abfb_job_list:
        status = cmkstatus.OK
        msg = "Start : {} Finished: {}".format(j.start_time,j.end_time)

        # is running
        if j.status == 1:
            msg    = "Started : {} and is currently running".format(j.start_time)
        # with warnings
        if j.status == 3:
            status = cmkstatus.WARN
        if j.start_time < max_old_date:
            status = cmkstatus.WARN
            msg    = "Last backup is older than {}".format(max_days_old)
        # with errors
        if j.error_count > 0:
            status = cmkstatus.CRIT
        cmkoutput = cmkservice.simple(status,"Synology ABfB: {}".format(j.task_name),msg)
        print(cmkoutput)
except:
    print(cmkservice.simple(cmkstatus.CRIT,"Synology ABfB","ERROR COULD NOT GET ANY DATA. CHECK YOUR VARS [dba_file] AND [dbc_file] IN 'LOCAL CHECK SCRIPT'"))