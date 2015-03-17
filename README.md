Gas Price Predicition Using HP Vertica and HP Distributed R - Part 1: Installation
========================================

This is "Part 1: Installation" of a two-part blog post where we're going to use two products of HP Haven's Big Data Platform: "Vertica", a column-oriented analytical database and "Distributed R", distributed platform for running applications written in the "R" language. The goal is to build a predictive model in R for Gasoline prices in the USA using sample data provided and/or outside data. The output is a CSV file with inputs and the predicted output.

If you already have a running Vertica and Distributed R environment, you can skip directly to "Part 2: Building the Model".

INSTALLING VERTICA
---------------------

The easiest way is to use a virtual machine with Vertica pre-installed provided by HP based on CentOS 5.5. To download the VM you must create an account in http://my.vertica.com then proceed to "Downloads". We'll provide a step-by-step installation but you can check the [official documentaion](http://my.vertica.com/docs/7.1.x/HTML/index.htm) if you need more info or prefer to install it on your own VM. You can use any VM player you want that support either VMDK or OVF files. HP recommends VMware Player or vSphere.

Alternativelly you can download pre-build packages for RHEL/CentOS 5 or 6, Debian 6 / Ubuntu 14.04 LTS, or SUSE 11 from the my.vertica.com download site. You can then install it using your preffered package manager.

You'll need the Vertica VM to communicate to another VM we'll use for "Distributed R". This configuration is Virtual Machine player dependent but, as a rule, setting your VM network adapter to "Bridge Mode" should suffice.


CONFIGURING VERTICA
----------------------

After you boot Vertica's VM, you can login with "dbadmin" as  username and "password" as password. Fire the terminal (Applications -> Accessories -> Terminal) and run:

```bash
[dbadmin@vertica]$ admintools
```

Accept the EULA then open the "Configuration Menu". Select "Create Database" to create a new database called "gas" and with password "gaspwd". Assume all the defaults and after the database initialization you should see a "Database gas created successfully". Go back to the Main Menu and select "View Database Cluster State". You should see the gas database in the list with the state "UP".

That's it! You can use the `vsql` command-line tool to interact with you running instance. Those familiar with PostgreSQL's `psql` tool will feel at home.

**Note that by default Vertica DOES NOT AUTO-START at machine boot.** You need to run the `admintools` command and start the database on every virtual machine boot.

LOADING THE SAMPLE DATA
-----------------------

Now we should load the sql data in the local "assets/oil_data" folder into Vertica. You can copy this folder to your Vertica VM using SCP:

```
[user@yourmachine]$ cd gas_prediction
[user@yourmachine]$ scp assets/oil_data dbadmin@<vertica-vm-ip>:/tmp
```

Replace `<vertica-vm-ip>` with the IP of the VM running Vertica. Then you can use the `vsql` tool in your Vertica machine to load the data. From the terminal (or ssh session if you set it up), we'll load the DB schema and all data SQL files using a for loop:

```
[dbadmin@vertica]$ cd /tmp/oil_data
[dbadmin@vertica]$ vsql -d gas -w gaspwd -f schema.sql
[dbadmin@vertica]$ for f in sample_data/*.sql; do vsql -d gas -w gaspwd -f $f; done
```

You can run the `vsql` command `\dt` to list all tables and check if they ware loaded:

```
[dbadmin@vertica]$ vsql -d gas -w gaspwd -c '\dt'
```
```
                               List of tables
 Schema |                  Name                  | Kind  |  Owner  | Comment
--------+----------------------------------------+-------+---------+---------
 public | crude_oil_and_petroleum                | table | dbadmin |
 public | crude_oil_future_contract              | table | dbadmin |
 public | total_gasoline                         | table | dbadmin |
 public | total_gasoline_by_prime_supplier       | table | dbadmin |
 public | us_field_production_of_curde_oil       | table | dbadmin |
 public | us_regular_conventional_gasoline_price | table | dbadmin |
(6 rows)
```


INSTALLING DISTRIBUTED-R
---------------------------

"Distributed R" is a scalable distributed platform for running R scripts. First you'll need to download the latest binary distribution from http://my.vertica.com. In the "Download" section, search for "HP Vertica Distributed R" then select the "Distributed R 1.0.0 – Red Hat/CentOS" option. Agree to the EULA and wait for the download to complete.

For Distributed-R, we're going to install in a pristine CentOS 6.5 (64-bit) machine. You can install from CentOS official ISO files or you can search for a ready-made appliance. For the installation part, we'll the commands as `root`. Again, discover the IP of the new VM using `/sbin/ifconfig` and (optionally) add it to your local `/etc/hosts` file:

First, we need to make sure you have unixODBC and SSH running in the virtual machine. If it's not installed you can fix that by issuing:

```
[root@dist-r]# yum install openssh-server unixODBC
```

Now make sure you can ssh to your own user without a password. To setup a SSH password-less connection:

```
[root@dist-r]# ssh-keygen
[root@dist-r]# ssh-copy-id localhost
[root@dist-r]# ssh localhost              # test it!
```

After configuring the virtual machine, we can start installing the Distributed-R. Copy the downloaded file into the VM and extract the file into "/tmp". (Note: for some reason, I had to gunzip the file first before untarring). We'll install it in localhost in Single Node mode.

```
[root@dist-r]# cd /tmp/vertica-distributedR-1.0.0-0/helpers
[root@dist-r]# ./distributedR_install_dependencies localhost
```

Install all missing dependencies when asked. It should take a while. Once finished, run the installation script as instructed:

```
[root@dist-r]# cd /tmp/vertica-distributedR-1.0.0-0/        # note we descended one directory
[root@dist-r]# ./distributedR_install localhost
```

When asked:

* Select the localhost as the master `[1]`
* Set all nodes as workers `[1]`
* Do not specify custom port ranges `[n]`
* Install Vertica RODBC support `[Y]`
* Run the test to make sure everything is OK `[Y]`

Distributed R is now installed. To test it, from the dist-r VM:

    [root@dist-r]# R        # start the R session

    > library(distributedR)
    ... should load the dependencies

    > distributedR_start()
    Workers registered - 1/1.
    All 1 workers are registered.
    Master address:port - localhost:50000

You can add a command to the bottom of the `/etc/rc.local` file to auto-start R-Studio on machine boot:

```
[root@dist-r]# echo 'sleep 3 && rstudio-server start >> /etc/rc.local
```

CONFIGURING VERTICA vRODBC
--------------------------

To make Distributed R connect we'll use Vertica RODBC. The libraries were already installed by Distributed R installation script so we just need to configure the connection parameters. Like all ODBC-flavored drivers, add the configuration to an *odbc.ini* file. We'll create it at `/etc/odbc.ini` with the following content:

```
[ODBC Data Sources]

[VerticaGasDSN]
Description = Gas DSN for Vertica
Driver = /opt/hp/odbc/lib64/libverticaodbc.so
Database = gas
Servername = <ip-of-vertica-vm>
UserName = dbadmin
Password = gaspwd
Port = 5433
ConnSettings =
Locale = en_US

[Driver]
ODBCInstLib=/usr/lib64/libodbcinst.so
ErrorMessagesPath=/opt/hp/odbc/lib64/
DriverManagerEncoding=UTF-16
LogPath=/tmp
LogNameSpace=
LogLevel=0
```

Replace the `<ip-of-vertica-vm>` string with the IP of the VM you previously installed Vertica. Try to `ping` it to check for connectivity from inside the Distributed R VM.

Now create a *vertica.ini* file for additional Vertica configuration at `/etc/vertica.ini` and paste the content below:

```
[Driver]
ODBCInstLib=/usr/lib64/libodbcinst.so
ErrorMessagesPath=/opt/hp/odbc/lib64/
DriverManagerEncoding=UTF-16
LogPath=/tmp
LogNameSpace=
LogLevel=0
```

You need to set the location of the two files in `VERTICAINI` and `ODBCINI` environment variables. To do this permanently create a file at `/etc/profile.d/vertica-odbc.sh` containing:

```
export ODBCINI=/usr/local/etc/odbc.ini
export VERTICAINI=/usr/local/etc/vertica.ini
```

Check if you can connect to vertica server using unixODBC `isql` tool:

```
[root@dist-r]# source /etc/profile.d/vertica-odbc.sh    # Load the environment variables into current session
[root@dist-r]# isql -v VerticaGasDSN
```


INSTALLING R-STUDIO SERVER
--------------------------

Now we're going to install on the Distributed R Virtual Machine the "R-Studio Server" environment. This enables us to run R scripts on the virtual machine's R installation from the comfort of our local machine using a neat desktop-like interface. We'll follow the instructions for the CentOS 6.x.

```
[root@dist-r]# yum install openssl098e wget
[root@dist-r]# wget http://download2.rstudio.org/rstudio-server-0.98.1102-x86_64.rpm
[root@dist-r]# yum install --nogpgcheck rstudio-server-0.98.1102-x86_64.rpm
[root@dist-r]# rstudio-server verify-installation     # check installation
```

We'll need login credentials to access R Studio so let's create them now using standard Linux tools. For every user, we'll also need to setup password-less ssh connection to localhost.

```
[root@dist-r]# useradd user
[root@dist-r]# passwd user
[root@dist-r]# su - user
[user@dist-r]$ ssh-keygen
[user@dist-r]$ ssh-copy-id localhost
[user@dist-r]$ ssh localhost           # test it!
```

To connect Vertica, we'll also need to setup R-Studio Server startup environment. We do that by creating a `.Renviron` file in our new user's home directory and adding the required variables.

```
[root@dist-r]# su - user
[user@dist-r]$ echo "ODBCINI=/usr/local/etc/odbc.ini" >> ~/.Renviron
[user@dist-r]$ echo "VERTICAINI=/usr/local/etc/vertica.ini" >> ~/.Renviron
```

From your local computer, access the R Studio web interface in the address `http://dist-r:8787/` Replace `dist-r` for the IP of the Distributed R VM if you did not added it to your local hosts file. Use the login credentials we just created. You should see a beautilful R Studio interface. Let's test again just to be sure:
```r
> library(distributedR)
... should load the dependencies

> distributedR_start()
Workers registered - 1/1.
All 1 workers are registered.
Master address:port - localhost:50000

> library(vRODBC)
> odbcConnect('VerticaGasDSN')
vRODBC Connection 1
Details:
  case=nochange
  DSN=VerticaGasDSN
```

NEXT STEPS
---------

Our environment is set up and working and we can start building our prediction model. Check out the next part of this
series "Part 2: Building the Model".