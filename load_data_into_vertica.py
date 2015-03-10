#! /usr/bin/env python2.7
# coding: utf-8
""" Load SQL data into a Vertica VM """

import sys
import subprocess
import os
import re
# update PYTHONPATH to use custom libraries
DIR = os.path.abspath(os.path.dirname(__file__))
LIB_DIR = DIR + "/lib/py"
sys.path.append(LIB_DIR)

# load custom libs
import pexpect
from pexpect import pxssh

DBNAME = "gas"
DBPASS = "gaspwd"
USERNAME = "dbadmin"
PASSWORD = "password"

if not len(sys.argv) > 1:
    print 'Please provide the IP of the Vertica VM as the only argument'
    sys.exit(1)

HOST = sys.argv[1]

try:
    # send data
    print 'Copying files to Vertica VM'
    data_dir = DIR + '/assets/oil_data'
    tmp_dir = '/tmp/oil_data'
    destination = "{user}@{host}:{dest}".format(user=USERNAME, host=HOST, dest=tmp_dir)

    p = pexpect.spawn("scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oPubkeyAuthentication=no -r %s %s" %(data_dir, destination))

    p.expect(["assword:"], timeout=5)
    p.sendline(PASSWORD)
    p.expect(pexpect.EOF)
    p.close()

    # ssh connect
    p = pxssh.pxssh()
    p.login(HOST, USERNAME, PASSWORD)

    def load_file(f):
        print 'Loading data: %s' % f
        sqlfile = tmp_dir + '/' + f
        cmd = "vsql -q -o /dev/null -d {dbname} -w {dbpass} -f {sqlfile}".format(dbname=DBNAME, dbpass=DBPASS, sqlfile=sqlfile)
        p.sendline(cmd)
        p.prompt(timeout=5*60)
        err = p.before
        p.sendline("echo RETCODE:$?")
        p.prompt()
        ret = p.before.strip()
        retcode = int(re.search("RETCODE:(\\d+)", ret).group(1))
        if retcode != 0:
            raise Exception("Error loading file: \n" + err)

    load_file('schema.sql')
    load_file('sample_data/data_crude_oil_and_petroleum.sql')
    load_file('sample_data/data_crude_oil_future_contract.sql')
    load_file('sample_data/data_total_gasoline.sql')
    load_file('sample_data/data_total_gasoline_by_prime_supplier.sql')
    load_file('sample_data/data_us_field_production_of_curde_oil.sql')
    load_file('sample_data/data_us_regular_conventional_gasoline_price.sql')
    p.close()

except Exception as e:
    print "An error occurred:"
    print e

