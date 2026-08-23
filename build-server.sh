#!/usr/bin/env bash

if [ $EUID = 0 ] && [ -z "$ALLOW_ROOT" ]; then
	echo "Do not run this script as root!"
	echo
	echo "If you really need to run it as root and you know what you are doing,"
	echo "set the ALLOW_ROOT environment variable."

	exit 1
fi

unset mysqld_root_arg
if [ $EUID = 0 ]; then
    mysqld_root_arg="--user=root"
fi

export CFLAGS="-march=x86-64 -O3"
export CXXFLAGS="${CFLAGS}"
export COMPILATION_THREADS="$(nproc)"

export scriptdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

mysql_server="https://dev.mysql.com/get/Downloads/MySQL-9.7/mysql-9.7.2-linux-glibc2.28-x86_64-minimal.tar.xz"
game_data="https://github.com/Kron4ek/AzerothCore-portable-builds/releases/download/data/data.7z"
azerothcore_repo="https://github.com/Grimfeather/azerothcore-wotlk.git"

modules_list=(https://github.com/mod-playerbots/mod-playerbots.git
              https://github.com/Grimfeather/mod-individual-progression.git
              https://github.com/azerothcore/mod-autobalance.git
              https://github.com/azerothcore/mod-ale.git
              https://github.com/NathanHandley/mod-ah-bot-plus.git
              https://github.com/azerothcore/mod-account-achievements.git
              https://github.com/azerothcore/mod-solo-lfg.git
              https://github.com/azerothcore/mod-random-enchants.git
              https://github.com/dunjeon/mod-TimeIsTime.git
              https://github.com/hermensbas/mod_weather_vibe.git)

temp_build_dir="${scriptdir}/azerothcore-build-temp"
acore_build_result="${scriptdir}/azerothcore-wotlk-bin"
acore_install_path="/tmp/acore"

copy_system_libs () {
    libs_dir="${acore_build_result}"/libs
    
    mkdir -p "${libs_dir}"

    find "${acore_build_result}" -type f | while read -r file; do
        if file "$file" | grep -q "ELF"; then
            ldd "$file" 2>/dev/null | grep -o '/usr/[^ ]*' | while read -r lib; do
                if [ -f "$lib" ]; then
                    cp -L "$lib" "${libs_dir}"
                fi
            done
        fi
    done

    cp -L "${acore_build_result}"/mysql/lib/libmysqlclient.so.24 "${libs_dir}"
    cp -L /usr/lib/libncursesw.so.6 "${libs_dir}"/libncurses.so.6
}

required_programs=(gcc grep sed 7z tar xz wget git cmake)

for program in "${required_programs[@]}"; do
    if ! command -v "${program}" 1>/dev/null; then
        echo "${program} is required"
        exit 1
    fi
done

cd "${scriptdir}" || exit 1

if [ ! -d azerothcore-wotlk ]; then
    if git clone "${azerothcore_repo}" azerothcore-wotlk; then
        if cd azerothcore-wotlk/modules; then
            for module in "${modules_list[@]}"; do
                git clone "${module}"
            done

            cd "${scriptdir}"
        fi
    else
        echo "Failed to clone azerothcore repo"
        exit 1
    fi
fi

if [[ ! -d mysql ]]; then
    if ! wget -O mysql.tar.xz "${mysql_server}"; then
        echo "Failed to download mysql server"
        rm -f mysql.tar.xz
        exit 1
    fi

    mkdir -p temp
    tar -C temp -xf "${scriptdir}"/mysql.tar.xz
    mv temp/* mysql
    rm -rf temp mysql.tar.xz
fi

if [ ! -f data.7z ]; then
    if ! wget -O data.7z "${game_data}"; then
        echo "Failed to download game data"
        rm -f data.7z
        exit 1
    fi
fi

git -C azerothcore-wotlk pull

for module in "${scriptdir}"/azerothcore-wotlk/modules/*/; do
    git -C "${module}" pull
done

mkdir -p "${temp_build_dir}"/build
cd "${temp_build_dir}"/build || exit 1

mv "${acore_build_result}" "${acore_build_result}_$(date)" 2>/dev/null
mkdir -p "${acore_build_result}"
rm -f "${acore_install_path}"
ln -s "${acore_build_result}" "${acore_install_path}"

cmake "${scriptdir}"/azerothcore-wotlk \
      -DCMAKE_BUILD_TYPE=Release \
      -DTOOLS_BUILD=all \
      -DCMAKE_INSTALL_PREFIX="${acore_install_path}" \
      -DMYSQL_INCLUDE_DIR="${scriptdir}"/mysql/include \
      -DMYSQL_LIBRARY="${scriptdir}"/mysql/lib/libmysqlclient.so

make -j${COMPILATION_THREADS} install

rm -rf "${temp_build_dir}"

cd "${acore_build_result}" || exit 1

echo
echo "Copying files"

if [[ ! -d data ]]; then
    7z x "${scriptdir}"/data.7z &>/dev/null
fi

if [[ ! -d mysql ]]; then
    cp -r "${scriptdir}"/mysql .
fi

cp -r "${scriptdir}"/azerothcore-wotlk/modules/mod-individual-progression/optional .
cp "${scriptdir}"/start-server.sh .

copy_system_libs

cd etc
for config in *.dist; do
    mv "${config}" "$(basename "${config}" .dist)"
done

cd modules
for config in *.dist; do
    mv "${config}" "$(basename "${config}" .dist)"
done

cd "${acore_build_result}"/etc

sed -i 's|3306|3308|g' authserver.conf
sed -i 's|3306|3308|g' worldserver.conf
sed -i 's|3306|3308|g' modules/playerbots.conf
sed -i 's|AiPlayerbot.RandomBotAutologin = 1|AiPlayerbot.RandomBotAutologin = 0|g' modules/playerbots.conf
sed -i "s|DataDir = \".\"|DataDir = \"${acore_install_path}/data\"|g" worldserver.conf
sed -i "s|MySQLExecutable = \"\"|MySQLExecutable = \"${acore_install_path}/mysql/bin/mysql\"|g" worldserver.conf
sed -i "s|SourceDirectory = \"\"|SourceDirectory = \"${scriptdir}/azerothcore-wotlk\"|g" worldserver.conf

cd "${acore_build_result}"
rm -f *.log

mkdir -p "${acore_build_result}"/libs_temp
cp -L /usr/lib/libncursesw.so.6 "${acore_build_result}"/libs_temp/libncurses.so.6
export LD_LIBRARY_PATH="${acore_build_result}/mysql/lib:${acore_build_result}/libs_temp"

echo
echo "Creating database"

"${scriptdir}"/mysql/bin/mysqld --no-defaults --initialize-insecure --datadir="${acore_build_result}/database" &>/dev/null
"${scriptdir}"/mysql/bin/mysqld --no-defaults ${mysqld_root_arg} --skip-log-bin --port 3308 --socket /tmp/mysql_acore.sock --mysqlx=OFF --datadir="${acore_build_result}/database" &>mysqld.log &
mysqld_pid=$!

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

"${scriptdir}"/mysql/bin/mysql --no-defaults --socket=/tmp/mysql_acore.sock -u root < "${scriptdir}"/azerothcore-wotlk/data/sql/create/create_mysql.sql
"${scriptdir}"/mysql/bin/mysql --no-defaults --socket=/tmp/mysql_acore.sock -u root < "${scriptdir}"/azerothcore-wotlk/modules/mod-playerbots/data/sql/playerbots/create/create_mysql.sql

echo
echo "Filling and updating the database"

/tmp/acore/bin/worldserver &
worldserver_pid=$!

counter=1
while true; do
    sleep 1

    if grep "World Initialized In" Server.log &>/dev/null; then
        break
    fi

    if [[ "${counter}" -ge 2400 ]]; then
        echo "Failed to run worldserver"
        exit 1
    fi

    counter=$((counter + 1))
done

kill ${worldserver_pid}
sleep 3
kill ${mysqld_pid}
sleep 3

rm -r "${acore_build_result}"/libs_temp
rm -f *.log

cd "${acore_build_result}"/etc

sed -i 's|Updates.EnableDatabases = 1|Updates.EnableDatabases = 0|g' authserver.conf
sed -i 's|Updates.EnableDatabases = 7|Updates.EnableDatabases = 0|g' worldserver.conf
sed -i 's|Playerbots.Updates.EnableDatabases = 1|Playerbots.Updates.EnableDatabases = 0|g' modules/playerbots.conf

echo
echo "Done"
echo "AzerothCore was installed to ${acore_build_result}"
