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

The above installation instructions does not care about perl scripts being run. So we need to check this.

Go to the user based directory
```
cd ~/Sites/
git clone https://github.com/bawi/bawi-on-perl.git
```

One way to check whether necessary perl modules are intact is to try to run one file.

```
cd ~/Sites/bawi-on-perl/main/
./index.cgi
```

### Installing necessary perl modules

For the first time, most likely HTML::Template and Text::Iconv momdules are missing. Typically, if you can run perl, then cpan should be present.

```
sudo cpan HTML::Template
sudo cpan Text::Iconv
```

For the first time, cpan wants to have the configuration setup. You are given the choice of installing perl modules locally (local::lib) option or doing with superuser. I have not explored the local library option which might be better.





### Set up the virtual hosting

Since bawi.org is also using virtual hosting service, better work on similar environment.

http://coolestguidesontheplanet.com/set-virtual-hosts-apache-mac-osx-10-10-yosemite/




