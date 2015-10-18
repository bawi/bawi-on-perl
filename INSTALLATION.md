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
ls *.sample | awk '{print("cp "$1" "$1)}' | sed 's/.sample//2'
ls *.sample | awk '{print("cp "$1" "$1)}' | sed 's/.sample//2' | /bin/sh
```


Now we will set up the mysql databases and then define the configuration files.

### mysql database setup

```
mysql -u root -p
mysql>create database bawi;
mysql>create user 'bawi'@'localhost' identified by '[MySQL password]';
mysql>grant all privileges on *.* to 'bawi'@'localhost' with grant option;
mysql>exit

mysql -u bawi -p bawi < ~/Sites/bawi-on-perl/db/bawi.sql
```
(You can use different DBUser name or DB name, just change the configuration file accordingly)

Based on the MySQL database and user/password, now you can configure board.conf, main.conf, user.conf
Specifically, you need to change

```
DBName bawi
DBUser bawi
DBpasswd [your MySQL password]
```

### Installing necessary perl modules

We will eventually run the startup.pl in apache2/ folder for virtual hosting for mod_perl Apache, but to test whether all necessary Perl modules are installed in the system, let us run in shell the CGI scripts first. For that, you need to manually set up some environment variables (that works in only one shell session. You could put it in .bash_profile if you want)

```
cd ~/Sites/bawi-on-perl/
export BAWI_PERL_HOME=~/Sites/bawi-on-perl
export BAWI_DATA_HOME=~/Sites/bawi-on-perl
```

One way to check whether necessary perl modules are intact is to try to run one CGI script and see what error it emits.

```
cd ~/Sites/bawi-on-perl/main/
./index.cgi
```

For the first time, most of the perl modules will not be installed. So let us do one by one by testing the above cgi script and running it and installing it.

```
sudo cpan HTML::Template
sudo cpan Text::Iconv
sudo cpan DBI
sudo cpan Apache::DBI
```

For the first time, cpan wants to have the configuration setup. You are given the choice of installing perl modules locally (local::lib) option or doing with superuser. I have not explored the local library option which might be better.

Attention, DBI::mysql installation is very tricky and general consensus seems to suggest to install even one perl version not to make a broken update in OSX updates. Honestly I do not know whether it is necessary, and it is relatively easy why it could be broken. The strategy is to source install and soft link the code.

See some informations:

* http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod#Mac_OS_X
* https://movabletype.org/documentation/installation/osx-10-9.html
* http://www.ensembl.info/blog/2013/09/09/installing-perl-dbdmysql-and-ensembl-on-osx/ 
* http://bixsolutions.net/forum/thread-8.html

Hope you can follow from here : 
```
# This is tricky part
# See: http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod#Mac_OS_X
perl -MCPAN -e 'shell'
cpan>get DBD::mysql
cpan>exit

cd ~/.cpan/build/DBD-mysql-4.032-6_SVJx/ # what ever the version is probably different directory name. Use Tab to figure out

perl Makefile.PL --mysql_config=/usr/local/mysql-5.6.16-osx10.7-x86_64/bin/mysql_config # whatever the version it is. Mine is 5.6.27.

make

export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:/usr/local/mysql-5.6.27-osx10.8-x86_64/lib/  # what ever the version is

make test

sudo make install

# For us, it might be easier to just link the libmysqlclient.18.dylib (why we defined the DYLD_LIBRARY_PATH) by soft link.
sudo ln -s /usr/local/mysql/lib/libmysqlclient.18.dylib /usr/lib/libmysqlclient.18.dylib
```

This will set up the DBI::mysql to the proper mysql.


### Set up the virtual hosting

Now we are ready to set up the virtual hosting. That is to say, instead of running it like "http://localhost/~WWolf/index.cgi" we have a virtual domain name (only used by ourselves). For us, it is dev.bawi.org.

For this to work well, we want to have mod_perl installed in Apache. Follow the steps in the link, but a brief summary described below.

* See: http://blog.n42designs.com/blog/2014/10/23/compiling-mod-perl-for-apache-2-dot-4-on-os-x-10-dot-10-yosemite/

```
cd ~
svn checkout https://svn.apache.org/repos/asf/perl/modperl/trunk/ mod_perl-2.0
cd mod_perl-2.0
# assume you already have XCode6.1 installed
/usr/bin/apr-1-config --includedir /usr/include/apr-1
sudo ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/usr/include/apache2 /usr/include/apache2
sudo ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/usr/include/apr-1 /usr/include/apr-1
perl Makefile.PL MP_CCOPTS=-std=gnu89 ; make ; sudo make install
sudo vi /etc/apache2/httpd.conf
# now include the mod_perl line
# LoadModule perl_module libexec/apache2/mod_perl.so
sudo apachectl configtest
sudo apachectl restart
```

Now, we have to configure the virtual host setting. What we are going to do is to soft link the httpd-vhosts.conf file to the already set up file in apache2/ directory. Follow below.

```
cd /etc/apache2/extra
sudo mv httpd-vhosts.conf httpd-vhosts.conf.original
sudo ln -s ~/Sites/bawi-on-perl/apache2/bawi-spring httpd-vhosts.conf
```

Now, fix the apache2/bawi-spring file to have the correct path. Also, fix the startup.pl path (hold on for the data directory for a minute).

```
# For bawi-spring file in bawi-on-perl/apache2
Change everything that is bawi.org to dev.bawi.org
Change everything that is /home/bawi/bawi-spring/ to whatever your absolute path such as /Users/WWolf/Sites/bawi-on-perl/

# For startup.pl in bawi-on-perl/apache2
change the first line path to *absolute* path. This is totally necessary
change all the BAWI_PERL_HOME and BAWI_DATA_HOME path to your absolute path
```

When everything is done, restart the apache server
```
sudo apachectl restart
```

Then finally, change the hosts file
```
sudo vi /etc/hosts
# include one line with
127.0.0.1 dev.bawi.org
```

Now, type in on your browser dev.bawi.org.

Voila!

### Database sampler

Now we have the first page on-line. But we do not have 
