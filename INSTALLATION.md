# Installation directions

This instruction is for Mac OSX. Please kindly contribute for the Linux or Windows version.

## MacOSX (Yosemite)

### Apache, MySQL 

To set up locally the bawi-on-perl setting, first we need to setup the Apache and MySQL setup.
For convenience, we will use the user based directory instead of the DocumentRoot.

The following link is very useful:

http://coolestguidesontheplanet.com/get-apache-mysql-php-phpmyadmin-working-osx-10-10-yosemite/

* installed MySQL 5.6.27. (I just chose to automatically start on boot)
* Note that for mysql root set up, do not put the password on command line.
* Also uncomment LoadModule cgi_module libexec/apache2/mod_cgi.so in httpd.conf
* Edit /etc/apache2/users/[username].conf

```
<Directory "/Users/[username]/Sites/">
    AllowOverride All
    AddHandler cgi-script .cgi
    Options Indexes MultiViews SymLinksIfOwnerMatch Includes ExecCGI
    DirectoryIndex index.html index.cgi
    Require all granted
</Directory>
```

You can test whether perl based script is working by writing the code to Sites directory:

```
vi test.cgi

#!/usr/bin/perl -w

use strict;
use warnings;

print qq(Content-type: text/plain\n\n);

print "Hello Perl World!\n";
```


### GIT clone the code

Go to the user based directory
```
cd ~/Sites/
git clone https://github.com/bawi/bawi-on-perl.git
```

### (optional) synchronization
```
git branch -b local
git pull origin sync
```

Because the server run code has been updated considerably (will be merged, so this part will become obsolete), pull this code as well for update.

After synchronization, let us just set up configuration files.

```
cd ~/Sites/bawi-on-perl/conf
ls *.sample | awk '{print("mv "$1" "$1)}' | sed 's/.sample//2'
ls *.sample | awk '{print("mv "$1" "$1)}' | sed 's/.sample//2' | /bin/sh
```

Now we will set up the mysql databases and then define the configuration files.

### mysql database setup

TODO 

### Installing necessary perl modules

BTW, first, you need to set up some basic paths
```
cd ~/Sites/bawi-on-perl/
export BAWI_PERL_HOME=~/Sites/bawi-on-perl
export BAWI_DATA_HOME=~/Sites/bawi-on-perl
```

One way to check whether necessary perl modules are intact is to try to run one file.

```
cd ~/Sites/bawi-on-perl/main/
./index.cgi
```

For the first time, most of the perl modules will not be installed. So let us do one by one by testing the above cgi script and running it.

```
sudo cpan HTML::Template
sudo cpan Text::Iconv
sudo cpan DBI
```

For the first time, cpan wants to have the configuration setup. You are given the choice of installing perl modules locally (local::lib) option or doing with superuser. I have not explored the local library option which might be better.


DBI::mysql installation is very tricky and general consensus seems to suggest to install even one perl version not to make a broken update in OSX updates. Honestly I do not know, and follow the manual installation part.

See some informations:

* http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod#Mac_OS_X
* https://movabletype.org/documentation/installation/osx-10-9.html
* http://www.ensembl.info/blog/2013/09/09/installing-perl-dbdmysql-and-ensembl-on-osx/ 
* http://bixsolutions.net/forum/thread-8.html

Hope you can follow from here : 
```
# This is tricky part
# See: http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod#Mac_OS_X

sudo cpan DBI

perl -MCPAN -e 'shell'
cpan>get DBD::mysql
cpan>exit

cd ~/.cpan/build/DBD-mysql-4.032-6_SVJx/ # what ever the version is
perl Makefile.PL --mysql_config=/usr/local/mysql-5.6.16-osx10.7-x86_64/bin/mysql_config # whatever the version 
make
export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:/usr/local/mysql-5.6.16-osx10.7-x86_64/lib/  # what ever the version is
make test
sudo make install
```

At this point, when you run the index.cgi, you will have only two errors about DBI connect, because we do not have any db users.



### Set up the virtual hosting

Since bawi.org is also using virtual hosting service, better work on similar environment.

http://coolestguidesontheplanet.com/set-virtual-hosts-apache-mac-osx-10-10-yosemite/




