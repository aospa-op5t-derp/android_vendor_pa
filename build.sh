#! /usr/bin/env bash

CLR_RST=$(tput sgr0)
CLR_GRN=$CLR_RST$(tput setaf 2)
CLR_CYA=$CLR_RST$(tput setaf 6)
CLR_BLD=$(tput bold)
CLR_BLD_RED=$CLR_RST$CLR_BLD$(tput setaf 1)
CLR_BLD_GRN=$CLR_RST$CLR_BLD$(tput setaf 2)
CLR_BLD_BLU=$CLR_RST$CLR_BLD$(tput setaf 4)

BUILD_TYPE="userdebug"

function showHelpAndExit()
{
	echo -e "${CLR_BLD_BLU}Usage: $0 <device> [options]${CLR_RST}"
	echo -e ""
	echo -e "${CLR_BLD_BLU}Options:${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -h, --help            Display this help message${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -c, --clean           Wipe the tree before building${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -i, --installclean    Dirty build - Use 'installclean'${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -r, --repo-sync       Sync before building${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -v, --variant         PA variant - Can be dev, alpha, beta or release${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -t, --build-type      Specify build type${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -j, --jobs            Specify jobs/threads to use${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -m, --module          Build a specific module${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -s, --sign-keys       Specify path to sign key mappings${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -p, --pwfile          Specify path to sign key password file${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -b, --backup-unsigned Store a copy of unsignied package along with signed${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -d, --delta           Generate a delta ota from the specified target_files zip${CLR_RST}"
	echo -e "${CLR_BLD_BLU}  -im, --image_zip      Generate fastboot flashable image zip from signed target_files${CLR_RST}"
	exit 1
}

long_opts="help,clean,installclean,repo-sync,variant:,build-type:,jobs:,module:,sign-keys:,pwfile:,backup-unsigned,delta:,image-zip"
getopt_cmd=$(getopt -o hcirv:t:j:m:s:p:b --long "$long_opts" \
	-n "$(basename "$0")" -- "$@") ||
	{
		echo -e "${CLR_BLD_RED}\nError: Getopt failed. Extra args\n${CLR_RST}"
		showHelpAndExit
		exit 1
	}

eval set -- "$getopt_cmd"

while true; do
	case "$1" in
	-h | --help | h | help) showHelpAndExit ;;
	-c | --clean | c | clean) FLAG_CLEAN_BUILD=y ;;
	-i | --installclean | i | installclean) FLAG_INSTALLCLEAN_BUILD=y ;;
	-r | --repo-sync | r | repo-sync) FLAG_SYNC=y ;;
	-v | --variant | v | variant)
		PA_VARIANT="$2"
		shift
		;;
	-t | --build-type | t | build-type)
		BUILD_TYPE="$2"
		shift
		;;
	-j | --jobs | j | jobs)
		JOBS="$2"
		shift
		;;
	-m | --module | m | module)
		MODULE="$2"
		shift
		;;
	-s | --sign-keys | s | sign-keys)
		KEY_MAPPINGS="$2"
		shift
		;;
	-p | --pwfile | p | pwfile)
		PWFILE="$2"
		shift
		;;
	-b | --backup-unsigned | b | backup-unsigned) FLAG_BACKUP_UNSIGNED=y ;;
	-d | --delta | d | delta)
		DELTA_TARGET_FILES="$2"
		shift
		;;
	-im | --image-zip | img | image-zip) FLAG_IMG_ZIP=y ;;
	--)
		shift
		break
		;;
	esac
	shift
done

if [ $# -eq 0 ]; then
	echo -e "${CLR_BLD_RED}Error: No device specified${CLR_RST}"
	showHelpAndExit
fi

export DEVICE="$1"
shift

ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
if [ "$ARCH" != "64" ]; then
	echo -e "${CLR_BLD_RED}error: unsupported arch (expected: 64, found: $ARCH)${CLR_RST}"
	exit 1
fi

cd "$(dirname "$0")" || exit 1
DIR_ROOT=$(pwd)

if [ ! -d "$DIR_ROOT/vendor/pa" ]; then
	echo -e "${CLR_BLD_RED}error: insane root directory ($DIR_ROOT)${CLR_RST}"
	exit 1
fi

if [ "$PA_VARIANT" ]; then
	PA_VARIANT=$(echo "$PA_VARIANT" | tr "[:upper:]" "[:lower:]")
	if [ "${PA_VARIANT}" = "release" ]; then
		export PA_BUILDTYPE=RELEASE
	elif [ "${PA_VARIANT}" = "alpha" ]; then
		export PA_BUILDTYPE=ALPHA
	elif [ "${PA_VARIANT}" = "beta" ]; then
		export PA_BUILDTYPE=BETA
	elif [ "${PA_VARIANT}" = "dev" ]; then
		unset PA_BUILDTYPE
	else
		echo -e "${CLR_BLD_RED} Unknown PA variant - use alpha, beta or release${CLR_RST}"
		exit 1
	fi
fi

echo -e "${CLR_BLD_BLU}Setting up the environment${CLR_RST}"
echo -e ""
. build/envsetup.sh
echo -e ""

CMD=""
if [ "$JOBS" ]; then
	CMD+=" -j$JOBS"
fi

if [ -z "$JOBS" ]; then
	if [ "$(uname -s)" = 'Darwin' ]; then
		JOBS=$(sysctl -n machdep.cpu.core_count)
	else
		JOBS=$(cat /proc/cpuinfo | grep -c '^processor')
	fi
fi

if [ "$(command -v 'mka')" ]; then
	if [ -z "${CMD}" ]; then
		MAKE="mka"
	else
		MAKE="make"
	fi
else
	MAKE="make"
fi

PA_DISPLAY_VERSION="$(cat "$DIR_ROOT/vendor/pa/config/version.mk" | grep 'PA_VERSION_FLAVOR := *' | sed 's/.*= //') \
$(cat "$DIR_ROOT/vendor/pa/config/version.mk" | grep 'PA_VERSION_CODE := *' | sed 's/.*= //')"

if [ "$FLAG_CLEAN_BUILD" = 'y' ]; then
	echo -e "${CLR_BLD_BLU}Cleaning output files left from old builds${CLR_RST}"
	echo -e ""
	${MAKE} clobber"$CMD"
fi

if [ "$FLAG_INSTALLCLEAN_BUILD" = 'y' ]; then
	echo -e "${CLR_BLD_BLU}Cleaning compiled image files left from old builds${CLR_RST}"
	echo -e ""
	${MAKE} installclean"$CMD"
fi

if [ "$FLAG_SYNC" = 'y' ]; then
	echo -e "${CLR_BLD_BLU}Downloading the latest source files${CLR_RST}"
	echo -e ""
	repo sync -j"$JOBS" -c --no-clone-bundle --current-branch --no-tags
fi

TIME_START=$(date +%s.%N)

echo -e "${CLR_BLD_GRN}Building AOSPA $PA_DISPLAY_VERSION for $DEVICE${CLR_RST}"
echo -e "${CLR_GRN}Start time: $(date)${CLR_RST}"
echo -e ""

echo -e "${CLR_BLD_BLU}Lunching $DEVICE${CLR_RST} ${CLR_CYA}(Including dependencies sync)${CLR_RST}"
echo -e ""
PA_VERSION=$(lunch "pa_$DEVICE-$BUILD_TYPE" | grep 'PA_VERSION=*' | sed 's/.*=//')
lunch "pa_$DEVICE-$BUILD_TYPE"
echo -e ""

RETVAL=0

echo -e "${CLR_BLD_BLU}Starting compilation${CLR_RST}"
echo -e ""

if [ "${MODULE}" ]; then
	${MAKE} "$MODULE""$CMD"

elif [ "${KEY_MAPPINGS}" ]; then
	if [ "${PWFILE}" ]; then
		export ANDROID_PW_FILE=$PWFILE
	fi

	if [ "$FLAG_BACKUP_UNSIGNED" = 'y' ]; then
		${MAKE} bacon"$CMD"
		mv "$OUT/pa-${PA_VERSION}.zip" "$DIR_ROOT/pa-${PA_VERSION}-unsigned.zip"
	else
		${MAKE} dist"$CMD"
	fi

	echo -e "${CLR_BLD_BLU}Signing target files apks${CLR_RST}"
	./build/tools/releasetools/sign_target_files_apks -o -d "$KEY_MAPPINGS" \
		"out/dist/pa_$DEVICE-target_files-*.zip" \
		"pa-$PA_VERSION-signed-target_files.zip"
	echo -e "${CLR_BLD_BLU}Generating signed install package${CLR_RST}"
	./build/tools/releasetools/ota_from_target_files -k "$KEY_MAPPINGS/releasekey" \
		--block --backup=true "${INCREMENTAL}" \
		"pa-$PA_VERSION-signed-target_files.zip" \
		"pa-$PA_VERSION.zip"

	if [ "$DELTA_TARGET_FILES" ]; then
		if [ ! -f "$DELTA_TARGET_FILES" ]; then
			echo -e "${CLR_BLD_RED}Delta error: base target files don't exist ($DELTA_TARGET_FILES)${CLR_RST}"
			exit 1
		fi

		./build/tools/releasetools/ota_from_target_files -k "$KEY_MAPPINGS/releasekey" \
			--block --backup=true --incremental_from "$DELTA_TARGET_FILES" \
			"pa-$PA_VERSION-signed-target_files.zip" \
			"pa-$PA_VERSION-delta.zip"
	fi

	if [ "$FLAG_IMG_ZIP" = 'y' ]; then
		./build/tools/releasetools/img_from_target_files \
			"pa-$PA_VERSION-signed-target_files.zip" \
			"pa-$PA_VERSION-signed-image.zip"
	fi

else
	${MAKE} bacon"$CMD"
	ln -sf "$OUT/pa-${PA_VERSION}.zip" "$DIR_ROOT"
fi

RETVAL=$?
echo -e ""

if [ $RETVAL -ne 0 ]; then
	echo "${CLR_BLD_RED}Build failed!${CLR_RST}"
	echo -e ""
fi

TIME_END=$(date +%s.%N)

echo -e "${CLR_BLD_GRN}Total time elapsed:${CLR_RST} ${CLR_GRN}$(echo "($TIME_END - $TIME_START) / 60" | bc) minutes ($(echo "$TIME_END - $TIME_START" | bc) seconds)${CLR_RST}"
echo -e ""

exit $RETVAL
