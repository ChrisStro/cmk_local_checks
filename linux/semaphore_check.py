import requests
from cmk_helper import *
import json
import inspect

semaphore_base_url  = "https://mysemaphore.web.net/api"
user      =   "mon_account"
pwd       =   "mon_pwd"
project_list = ["Project 1", "Demo"]

#region functions
def semapore_req(url, method, **kwargs):
    full_url = semaphore_base_url + "/" + url
    r = requests.request(method, full_url, **kwargs)
    return r

def semaphore_login(user, pwd):
    login = { "auth": f"{user}", "password": f"{pwd}" }
    r = semapore_req("auth/login", "POST", json = login )
    return r

def semaphore_new_token(user, pwd):
    c = semaphore_login(user, pwd)
    r = semapore_req("user/tokens", "POST", cookies = c.cookies)
    return r

def semaphore_get_token(user, pwd):
    c = semaphore_login(user, pwd)
    r = semapore_req("user/tokens", "GET", cookies = c.cookies)
    return r

def semaphore_expire_token(token_id):
    auth_header = { "Authorization": f"Bearer {token_id}" }
    r = semapore_req(f"user/tokens/{token_id}", "DELETE", headers = auth_header)
    return r

def semaphore_get_projects(token_id):
    auth_header = { "Authorization": f"Bearer {token_id}" }
    r = semapore_req(f"projects", "GET", headers = auth_header)
    return r.json()

def semaphore_get_templates(token_id, project_id):
    auth_header = { "Authorization": f"Bearer {token_id}" }
    r = semapore_req(f"project/{project_id}/templates", "GET", headers = auth_header)
    return r.json()

#endregion

token = semaphore_new_token(user,pwd)
token_id = token.json()['id']

# get/filter needed projects
all_projects = semaphore_get_projects(token_id)
filtered_projects =[project for project in all_projects if project['name'] in project_list ]

# get all templates
all_templates = []
for p in filtered_projects:
    templates_in_project = semaphore_get_templates(token_id, p['id'])
    for t in templates_in_project:
        all_templates.append(t)

# checkmk output for last task run
for t in all_templates:
    try:
        if t['last_task'] != None:
            cmk_status  = cmkstatus.OK
            task        = t['last_task']
            task_start  = task['start']  if task['start']   else "no execution"
            task_end    = task['end']    if task['end']     else "no execution"
            task_status = task['status'] if task['status']  else "error"
            project     = [project for project in all_projects if project['id'] == t['project_id']][0]['name']
            msg         = "Start: {} End: {}".format(task_start,task_end)

            if task_status == 'error':
                cmk_status = cmkstatus.CRIT
            cmkoutput   = cmkservice.simple(cmk_status,"Semaphore: {} : {}".format(project,t['name']),msg)
            print(cmkoutput)
    except Exception as e:
        print(cmkservice.simple(cmkstatus.CRIT,"Semaphore","ERROR COULD NOT GET ANY DATA. CHECK YOUR VARS !"))