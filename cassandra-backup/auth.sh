# Sourced by backup.sh and restore.sh.
#
# Passwords never go on a command line: argv is readable by every process in the container
# (/proc/<pid>/cmdline). cqlsh reads them from a --credentials file ([plain_text_auth]; cqlsh
# reads that password without % interpolation), nodetool from a -pwf password file. Both live
# in a private directory (mktemp -d is 0700, the files 0600) removed when the script exits.

CRED_DIR=$(mktemp -d /tmp/cassandra-auth.XXXXXX)
trap 'rm -rf "${CRED_DIR}"' EXIT

# cqlsh_auth USER PASSWORD
cqlsh_auth() {
  ( umask 077
    printf '[plain_text_auth]\nusername = %s\npassword = %s\n' "$1" "$2" > "${CRED_DIR}/credentials" )
}

# cql ARGS...: cqlsh against CASSANDRA_HOST:CASSANDRA_PORT with the cqlsh_auth credentials
cql() {
  cqlsh --credentials "${CRED_DIR}/credentials" --no-color "${CASSANDRA_HOST}" "${CASSANDRA_PORT}" "$@"
}

# nodetool_auth PASSWORD (JMX user "cassandra")
nodetool_auth() {
  ( umask 077; printf 'cassandra %s\n' "$1" > "${CRED_DIR}/jmx.password" )
}

# nt ARGS...: nodetool against the local node with the nodetool_auth password
nt() {
  nodetool -u cassandra -pwf "${CRED_DIR}/jmx.password" "$@"
}
