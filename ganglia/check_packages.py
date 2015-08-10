#!/bin/env python
"""
Script to check for exact ganglia and httpd package version installed
If not found - install them
If found but version doesn't match - remove and install correct versions
"""

# the following imports were copied from yum-cli/cli.py module - to make API work
# there are some side effects that make YumBaseCli().getOptionsConfig() method work
import sys
sys.path.insert(0, '/usr/share/yum-cli')

import os
import os.path
import sys
import logging
import time
import errno

from yum import Errors
from yum import plugins
from yum import logginglevels
from yum import _
from yum.i18n import to_unicode, utf8_width
import yum.misc
import cli
from utils import suppress_keyboard_interrupt_message, show_lock_owner, exception2msg


yb = cli.YumBaseCli()
# point yum to older version of Amazon repo and disable updates repo to point yum to ganglia 3.3.7
args = ["--releasever=2013.03", "--disablerepo=amzn-updates*", "--skip-broken", "list", "ganglia"]
yb.getOptionsConfig(args)

installed_packages_dict = dict([(p.name, p) for p in yb.rpmdb.returnPackages()])

operations_log = []

def remove_package(**kwargs):
    """

    :param kwargs: dict
        accepted keys: name and version, pattern
    :return:
    """
    yb.remove(**kwargs)
    yb.resolveDeps()
    yb.buildTransaction()
    yb.processTransaction()


def install_package(**kwargs):
    """

    :param kwargs: dict
        accepted keys: name and version, pattern
    :return:
    """
    yb.install(**kwargs)
    yb.resolveDeps()
    yb.buildTransaction()
    yb.processTransaction()


# check httpd version
# if doesn't match uninstall and install httpd2.2

if "httpd" in installed_packages_dict:
    httpd_po = installed_packages_dict["httpd"]
    if httpd_po:
        if not httpd_po.version.startswith("2.2."):
            remove_package(pattern="httpd*")
            install_package(pattern="httpd*2.2.*")
else:
    install_package(pattern="httpd*2.2.*")

# check ganglia version
# if doesn't match - uninstall php* and ganglia*

if "ganglia" in installed_packages_dict:
    ganglia_po = installed_packages_dict["ganglia"]
    if not ganglia_po.version.startswith("3.3."):
        operations_log.append("Invalid ganglia version: %s != %s" % (ganglia_po.version, "3.3.*"))
        print "Removing packages: php*"
        remove_package(pattern="php*")
        operations_log.append("Removed packages: %s" % ("php*"))
        print "Removing packages: ganglia*"
        remove_package(pattern="ganglia*")
        operations_log.append("Removed packages: ganglia*")
        print "Installing ganglia"
        install_package(pattern="ganglia*")
        operations_log.append("Installed package: ganglia")
else:
    install_package(pattern="ganglia*")
    operations_log.append("installed ganglia packages")


print "Report:"
if operations_log:
    print "\n".join(operations_log)
else:
    print "All ganglia related packages have been already installed"
