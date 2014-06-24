#!/bin/bash
Green="\033[0;32m"
Blue="\033[1;34m"
Normal="\033[0m"
Red="\033[1;31m"
workDir=$(dirname "$0")
cd "$workDir"
kextDir="$workDir"/Kexts
EfiDir="$workDir"/Efi
KextFullPath=/"${PWD##/}"/Kexts
echo $WDir
ffsDir="$workDir"/Ffs
OzmDir="$workDir"/Ozm
binDir="$workDir"/bin
kexts=$(ls "$kextDir")
efi=$(ls "$EfiDir")
ozm=$(ls "$OzmDir")

hex() { echo $1 16op | dc; }

function kext2ffs(){
	b=$(basename $1 .kext)
    c=$(basename $1 .kext)Compress
    
	searchString="does not exist"
    name=$(defaults read "$KextFullPath"/$1/Contents/Info "CFBundleName" 2>&1 )
    version=$(defaults read "$KextFullPath"/$1/Contents/Info "CFBundleShortVersionString" 2>&1 ) 
    case $version in
        *"$searchString")
            version=$b".Rev-?"
        ;;
        *)
            version=$b".Rev-"$version
        ;;
	esac
    result=$(defaults write "$KextFullPath"/$1/Contents/Info "CFBundleName" -string $version 2>&1 )
    plutil -convert xml1 "$kextDir"/$1/Contents/Info.plist
	cat "$kextDir"/$1/Contents/Info.plist NullTerminator "$kextDir"/$1/Contents/MacOS/$b > $b.bin 2>/dev/null
  
    "$binDir"/GenSec -s EFI_SECTION_PE32 -o $b.pe32 $b.bin
    "$binDir"/GenSec -s EFI_SECTION_USER_INTERFACE -n $version -o $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g DADE100$2-1B31-4FE4-8557-26FCEFC78275 -o "$ffsDir"/Kext/$b.ffs -i $b.pe32 -i $b-1.pe32
	"$binDir"/GenSec -s EFI_SECTION_COMPRESSION -o $b-2.pe32 $b.pe32 $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g DADE100$2-1B31-4FE4-8557-26FCEFC78275 -o "$ffsDir"/Kext/Compress/$c.ffs -i $b-2.pe32

	echo -e $Blue $1 "  \t" will be Ffs $2 $Red name in boot.log will be $version
}

function efi2ffs(){
    b=$(basename $1 .efi)
    c=$(basename $1 .efi)Compress

    "$binDir"/GenSec -s EFI_SECTION_PE32 -o $b.pe32 "$EfiDir"/$b.efi
    "$binDir"/GenSec -s EFI_SECTION_USER_INTERFACE -n $b -o $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g DADE10$2-1B31-4FE4-8557-26FCEFC78275 -o "$ffsDir"/Efi/$b.ffs -i $b.pe32 -i $b-1.pe32
    "$binDir"/GenSec -s EFI_SECTION_COMPRESSION -o $b-2.pe32 $b.pe32 $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g DADE10$2-1B31-4FE4-8557-26FCEFC78275 -o "$ffsDir"/Efi/Compress/$c.ffs -i $b-2.pe32

    echo -e $Blue $1 "  \t" will be Ffs $2 $Red name in boot.log will be $b
}


function ozm2ffs(){
    b=$(basename $1 .plist)
    c=$(basename $1 .plist)Compress

    "$binDir"/GenSec -s EFI_SECTION_PE32 -o $b.pe32 "$OzmDir"/$b.plist
    "$binDir"/GenSec -s EFI_SECTION_USER_INTERFACE -n $b -o $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g 99F2839C-57C3-411E-ABC3-ADE5267D960D -o "$ffsDir"/Ozm/$b.ffs -i $b.pe32 -i $b-1.pe32
    "$binDir"/GenSec -s EFI_SECTION_COMPRESSION -o $b-2.pe32 $b.pe32 $b-1.pe32
    "$binDir"/GenFfs -t EFI_FV_FILETYPE_DRIVER -g 99F2839C-57C3-411E-ABC3-ADE5267D960D -o "$ffsDir"/Ozm/Compress/$c.ffs -i $b-2.pe32

    echo -e $Blue $1 "  \t" will be Ffs $2 $Red name in boot.log will be $b
}

function generateKext(){
    [ -d "$ffsDir"/Kext ] && rm -rf "$ffsDir"/Kext
    mkdir "$ffsDir"/Kext
    mkdir "$ffsDir"/Kext/Compress
    x=6
    for a in $kexts; do

        if [ $a == FakeSMC.kext ]; then
            kext2ffs $a  1
            else
                if [ $a == Disabler.kext ]; then
                    kext2ffs $a 2
                else
                    if [ $a == Injector.kext ]; then
                        kext2ffs $a 3
                    else
                        kext2ffs $a $(hex $x)
                    let x++
                fi
            fi
        fi
    done
}

function generateEfi(){
    [ -d "$ffsDir"/Efi ] && rm -rf "$ffsDir"/Efi
    mkdir "$ffsDir"/Efi
    mkdir "$ffsDir"/Efi/Compress

    x=20
    for a in $efi; do
        efi2ffs $a $(hex $x)
        let x++
    done
}

function generateOzm(){
    [ -d "$ffsDir"/Ozm ] && rm -rf "$ffsDir"/Ozm
    mkdir "$ffsDir"/Ozm
    mkdir "$ffsDir"/Ozm/Compress

    for a in $ozm; do
        ozm2ffs $a 0
    let x++
    done
}

echo -e $Green
echo "*********************************"
echo "* Convert Kext to FFS type file *"
echo "*********************************"
echo
dd if=/dev/zero of=NullTerminator bs=1 count=1 1>/dev/null 2>&1


case $1 in
    *Kext)
        generateKext
    ;;
    *Efi)
        generateEfi
    ;;
    *Ozm)
    generateOzm
    ;;

    *)
        generateKext
        generateEfi
        generateOzm
    ;;
esac


echo -e $Normal

rm NullTerminator 1>/dev/null 2>&1
rm *.pe32 1>/dev/null 2>&1
rm *.bin 1>/dev/null 2>&1



exit