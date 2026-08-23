#!/usr/bin/env bash

if [ $EUID = 0 ] && [ -z "$ALLOW_ROOT" ]; then
	echo "Do not run this script as root!"
	echo
	echo "If you really need to run it as root and you know what you are doing,"
	echo "set the ALLOW_ROOT environment variable."

	exit 1
fi

required_programs=(grep pgrep pidof)

for program in "${required_programs[@]}"; do
    if ! command -v "${program}" 1>/dev/null; then
        echo "${program} is required"
        exit 1
    fi
done

export scriptdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

mysqld_only=false
if [[ "${1}" = "mysqld_only" ]]; then
    mysqld_only=true
fi

acore_install_path="/tmp/acore"
rm -f "${acore_install_path}"
ln -s "${scriptdir}" "${acore_install_path}"

run_ld () {
    "${scriptdir}"/libs/ld-linux-x86-64.so.2 \
    --library-path "${scriptdir}"/libs \
    "${@}"
}

cd "${acore_install_path}" || exit 1

if [[ ! -S /tmp/mysql_acore.sock ]]; then
    if [[ "${mysqld_only}" = "true" ]]; then
        run_ld "${scriptdir}"/mysql/bin/mysqld --no-defaults --skip-log-bin --port 3308 --socket /tmp/mysql_acore.sock --mysqlx=OFF --datadir="${scriptdir}/database"
        exit
    fi

    rm -f *.log

    run_ld "${scriptdir}"/mysql/bin/mysqld --no-defaults --skip-log-bin --port 3308 --socket /tmp/mysql_acore.sock --mysqlx=OFF --datadir="${scriptdir}/database" &>mysqld.log &

    counter=1
    while true; do
        sleep 1

        if grep "ready for connections" mysqld.log &>/dev/null; then
            break
        fi

        if [[ "${counter}" -ge 120 ]]; then
            echo "Failed to run mysqld"
            exit 1
        fi

        counter=$((counter + 1))
    done

    mysqld_pid="$(pidof "${scriptdir}"/libs/ld-linux-x86-64.so.2)"
else
    echo "mysqld is already running"
    exit 1
fi

run_ld "${acore_install_path}"/bin/authserver &>/dev/null &
sleep 2
authserver_pid=$(pgrep -xf "${scriptdir}/libs/ld-linux-x86-64.so.2 --library-path ${scriptdir}/libs ${acore_install_path}/bin/authserver")

run_ld "${acore_install_path}"/bin/worldserver

kill ${authserver_pid}
sleep 3
kill ${mysqld_pid}
