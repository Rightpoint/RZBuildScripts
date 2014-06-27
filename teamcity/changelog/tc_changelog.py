#
#   Generate a TeamCity changelog for a particular build number
#   Nick Donaldson 
#   Raizlabs
#   2014/05/20
#
#   Arguments:
#   -e <server_endpoint>   
#   -u <username>
#   -p <password> (optional, will prompt if not provided)
#   -o <output_file> (optional, defaults to tc_changes_<build_id>)
#   -s (optional, silent failure and no password prompt)
#   [build id]

import os, sys, getopt, getpass
import urlparse
import requests
from requests.auth import HTTPBasicAuth

#
# Utility functions
#

def print_help():
    print "Generate teamcity changelog"
    print "Usage: tc_changelog.py -e <server_endpoint> -u <username> [build id]"
    print "Optional:"
    print "    -o <output_file> - Defaults to tc_changes_<build_id>"
    print "    -p <password> - Will prompt if not provided and not in silent mode."
    print "    -s - Silent mode. Does not prompt for password if not provided, just fails."

def check_success(req):
    if req.status_code >= 400:
        print "HTTP Error {code}".format(code=req.status_code)
        sys.exit(1)

# 
# Parse arguments
#

silent   = False
endpoint = None
username = None
password = None
out_file = None
build_num = None

try:
    opts, args = getopt.getopt(sys.argv[1:],'hse:u:p:o:')
except getopt.GetoptError:
    print_help()
    sys.exit(2)
if len(opts) == 0 or len(args) == 0:
    print_help()
    sys.exit(2)
for opt, arg in opts:
    if opt == '-h':
        print_help()
        sys.exit()
    elif opt == '-e':
        endpoint = arg
    elif opt == '-u':
        username = arg
    elif opt == '-p':
        password = arg
    elif opt == '-o':
        out_file = arg
    elif opt == '-s':
        silent = True
            

build_num = args[0]

if not password and not silent:
    password = getpass.getpass("Password: ")
                
# validate that we have all arguments
if not (endpoint and username and password and build_num):
    print_help()
    sys.exit(2)      

if not out_file:
    out_file = "tc_changes_{build_num}".format(build_num=build_num)
    print "Output file not specified. Outputting to {out_file}".format(out_file=out_file)

# get commit hashes for this build
url = urlparse.urljoin(endpoint, 'httpAuth/app/rest/changes')
params = {'build': "id:{build_num}".format(build_num=build_num)}
auth = HTTPBasicAuth(username, password)
headers = {'Accept': 'application/json'}
req = requests.get(url, params=params, headers=headers, auth=auth)

check_success(req)
    
changes = req.json().get('change')

change_log = ""

if not changes:
    print "No changes since last build"
    sys.exit()

for change in changes:
    
    url = urlparse.urljoin(endpoint, "httpAuth/app/rest/changes/id:{cid}".format(cid=change['id']))
    req = requests.get(url, headers=headers, auth=auth)
    
    check_success(req)
    
    comment = req.json().get('comment')
    comment = comment.strip()
    change_log.join("- {comment}\n".format(comment=comment.encode("utf-8")))
    
# Write to file
with open(out_file, 'w') as f:
    f.write(change_log)