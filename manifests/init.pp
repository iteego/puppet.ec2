# iteego/puppet.s3fs: puppet recipes for use with the s3fs sofware
#                     in debian-based systems.
#
# Copyright 2012 Iteego, Inc.
# Author: Marcus Pemer <marcus@iteego.com>
#
# This file is part of iteego/puppet.s3fs.
#
# iteego/puppet.s3fs is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# iteego/puppet.s3fs is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with iteego/puppet.s3fs.  If not, see <http://www.gnu.org/licenses/>.
#

class ec2 {

    define elasticip ($instanceid, $ip,
                      $ec2PrivateKeyFile = '/etc/puppet/files/keys/pk.pem',
                      $ec2CertFile = '/etc/puppet/files/keys/cert.pem',
                      )
    {
        exec { "ec2-associate-address-$name":
            # Only do this when necessary
            onlyif      => "test $ip != $(curl -s -f http://169.254.169.254/latest/meta-data/public-ipv4)",

            logoutput   => on_failure,
            environment => [
                             "JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64",
                             "EC2_PRIVATE_KEY=$ec2PrivateKeyFile",
                             "EC2_CERT=$ec2CertFile",
                           ],
            path        => [ "/usr/bin", "/bin", "/usr/sbin", "/sbin" ],
            command     => "ec2assocaddr $ip -i $instanceid",
            require     => Package["ec2-api-tools"],
        }
    }

    define ebsvolume ($instanceid, $volumeid, $ebsdevicetomount, $localdevicetomount,
                      $mountpoint = '/mnt', $owner = 'root', $group = 'root',
                      $mode = '755', $fstype = 'ext3',
                      $mountoptions = 'defaults',
                      $ec2PrivateKeyFile = '/etc/puppet/files/keys/pk.pem',
                      $ec2CertFile = '/etc/puppet/files/keys/cert.pem',
                      )
    {
        exec { "ec2-attach-volume-$name":
            logoutput   => on_failure,
            environment => [
                             "JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64",
                             "EC2_PRIVATE_KEY=$ec2PrivateKeyFile",
                             "EC2_CERT=$ec2CertFile",
                           ],
            path        => [ "/usr/bin", "/bin", "/usr/sbin", "/sbin" ],
            command     => "timeout --kill-after=10 20 ec2detvol $volumeid -f
                            sleep 20
                            timeout --kill-after=10 20 ec2attvol $volumeid \
                                      -i $instanceid \
                                      -d $ebsdevicetomount
                            counter=0
                            until [ -b $localdevicetomount -o $counter -ge 60 ]
                            do
                              sleep 1
                              let counter=counter+1
                            done
                            retval=0
                            [ $counter -g1 120 ] && retval=1
                            exit $retval",
            # Only do this when necessary
            unless      => "test -b $localdevicetomount",
            timeout     => 120,
            tries       => 10,
            before      => Mount["$mountpoint"],
            require     => Package['ec2-api-tools'],
        }

        file { "$mountpoint":
            ensure  => directory,
            owner   => $owner,
            group   => $group,
            mode    => $mode,
        }

        mount { "$mountpoint":
            device  => $localdevicetomount,
            ensure  => mounted,
            fstype  => $fstype,
            options => $mountoptions,
            require => [ Exec["ec2-attach-volume-$name"],
                         File["$mountpoint"]
            ],
        }
    }

}
