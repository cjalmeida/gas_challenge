TopCoder Gas Price Predicition Challenge
========================================

```bash
# echo hello world
```

This is a submission project for TopCoder's "Gasoline Price Predictive Analytics Tutorial with HP Haven" challenge. We're going to use two products of HP Haven's Big Data Platform: "Vertica", a column-oriented analytical database and "Distributed R", distributed platform for running applications written in the "R" language. The goal is to build a predictive model in R for Gasoline prices in the USA using sample data provided and/or outside data. The output is a CSV file with inputs and the predicted output.

1. INSTALLING VERTICA
---------------------

We'll use a virtual machine with Vertica pre-installed. The VM is regular CentOS 5.5 distribution. To download the VM you must create an account in http://my.vertica.com then proceed to "Downloads". We'll provide a step-by-step installation but you can check the [official documentaion](http://my.vertica.com/docs/7.1.x/HTML/index.htm) if you need more info.You can use any VM player you want that support either VMDK or OVF files. HP recommends VMware Player or vSphere.


2. CONFIGURING VERTICA
----------------------

After you boot Vertica's VM, you can login with "dbadmin" as  username and "password" as password. Fire the terminal (Applications -> Accessories -> Terminal) and run:

```bash
[dbadmin@vertica]$ admintools
```

Accept the EULA then open the "Configuration Menu". Select "Create Database" to create a new database called "gas" and with password "gaspwd". Assume all the defaults and after the database initialization you should see a "Database gas created successfully". Go back to the Main Menu and select "View Database Cluster State". You should see the gas database in the list with the state "UP".

Now we should load the sql data in the local "assets/oil_data" folder into Vertica. We've built a Python script to automate this (you need Python 2.7 installed). First, you should find your VM's IP address by issuing the following command in the terminal:

```bash
[dbadmin@vertica]$ /sbin/ifconfig eth0 | grep 'inet '
```

It will tell you the the IP address of the VM. Write it down because will need it later or, better yet, append it to your local machine `/etc/hosts` file:

```bash
[user@yourmachine]$ echo '<IP-of-Vertica> verticavm' | sudo tee -a /etc/hosts
```

Now you just have to run on local machine, in this project's root folder:

```bash
[user@yourmachine]$ ./load_data_into_vertica.py verticavm
```

The script will upload the data to the server. It should take a few minutes. (Note: it assumes you haven't changed the default password. If you did, edit the script file.)


3. INSTALLING DISTRIBUTED-R
---------------------------

"Distributed R" is a scalable distributed platform for running R scripts. First you'll need to download the latest binary distribution from http://my.vertica.com. In the "Download" section, search for "HP Vertica Distributed R" then select the "Distributed R 1.0.0 – Red Hat/CentOS" option. Agree to the EULA and wait for the download to complete.

For Distributed-R, we're going to install in a pristine CentOS 6.5 (64-bit) machine. You can install from CentOS official ISO files or you can search for a ready-made appliance. For the installation part, we'll the commands as `root`. Again, discover the IP of the new VM and add it to your local hosts file:

```bash
[root@dist-r]# /sbin/ifconfig eth0 | grep 'inet '
```
```bash
[user@yourmachine]$ echo '<IP-of-VM> dist-r-vm' | sudo tee -a /etc/hosts
```


First, make sure you have SSH running in the virtual machine. If it's not installed you can fix that by issuing:

```bash
[root@dist-r]# yum install openssh-server
```

Now make sure you can ssh to your own user without a password. To setup a SSH password-less connection:

```bash
[root@dist-r]# ssh-keygen
[root@dist-r]# ssh-copy-id localhost
[root@dist-r]# ssh localhost           # test it!
```

After configuring the virtual machine, we can start installing the Distributed-R. Copy the downloaded file into the VM and extract the file into "/tmp". (Note: for some reason, I had to gunzip the file first before untarring) We'll install it in localhost in Single Node mode.

```bash
[root@dist-r]# cd /tmp/vertica-distributedR-1.0.0-0/helpers
[root@dist-r]# ./distributedR_install_dependencies localhost
```

Install all missing dependencies when asked. It should take a while. Once finished, run the installation script as instructed:

```bash
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

4. INSTALLING R-STUDIO SERVER
-----------------------------

Now we're going to install on the Distributed R Virtual Machine the "R-Studio Server" environment. This enables us to run R scripts on the virtual machine's R installation from the comfort of our local machine. We'll follow the instructions for the CentOS 6.x.

```bash
[root@dist-r]# yum install openssl098e wget
[root@dist-r]# wget http://download2.rstudio.org/rstudio-server-0.98.1102-x86_64.rpm
[root@dist-r]# yum install --nogpgcheck rstudio-server-0.98.1102-x86_64.rpm
[root@dist-r]# rstudio-server verify-installation     # check installation
```

You can add the command `rstudio-server start` to the end of the `/etc/rc.local` file to have the R Studio Server start on machine boot. We'll need login credentials to access R Studio so let's create them now using standard Linux tools. For every user, we'll also need to setup password-less ssh connection to localhost.

```bash
[root@dist-r]# useradd user
[root@dist-r]# passwd user
```

```bash
[root@dist-r]# su - user
[user@dist-r]$ ssh-keygen
[user@dist-r]$ ssh-copy-id localhost
[user@dist-r]$ ssh localhost           # test it!
```
From your local computer, access the R Studio web interface in the address `http://dist-r:8787/` Replace `dist-r` for the IP of the Distributed R VM if you did not added it to your local hosts file. Use the login credentials we just created. You should see a beautilful R Studio interface. Let's test again just to be sure:
```r
    > library(distributedR)
    ... should load the dependencies

    > distributedR_start()
    Workers registered - 1/1.
    All 1 workers are registered.
    Master address:port - localhost:50000
```
5. RUNNING THE MODEL
--------------------

We created the model in a single R file called `gas_prediction.r` Also we created a dynamic "R Markdown" file called `gas_prediction.Rmd` explaining what, how and why we did it. For the uninitiated, this is a format where you can
publish a document with runnable R code.
