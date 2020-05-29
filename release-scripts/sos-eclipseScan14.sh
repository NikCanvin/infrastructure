#!/bin/bash
#*******************************************************************************
# Licensed Materials - Property of IBM
# "Restricted Materials of IBM"
#
# Copyright IBM Corp. 2018 All Rights Reserved
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#*******************************************************************************

## in version 8, bolting on CONTAINER stuff at bottom (removed playtime, with mongo code)
## in version 9, FIXED missing node dependencies (new 'bundled' row found and now supported in package-lock.json files)
## in version 9, tweaking packageInventory to not require manual move/copies between releases (part of resolience)
## in version 9, fixed bug in the called csar.sh, to use the new URL of the webservice on Fyre
## in version 10, working on NPM audit data/fixes etc!
## in version 11, new case - support multiple Go proejcts in Codewind 
    ##due to in 0.9.0 a copy of deploy-pfe Go packages now in eclipse-che-plugin/codewind-che-sidecar, however my GO code below only supported 1 Gopkg.lock)
## in version 12, 
    ## INVESTIGATED support for node @dir/packages in wicked scan output (looks like Excel bug/change in 16.34) 
## in version 13, new case, added support for GO projects managed but GO MOD package manager (the strategic pack man, shipped in Go itself)
    ## go mod tidy + vendor, seems to do the trick!
## in version 14, added handle missing wicked dep csv (mod processing will revert to vanilla wicked csv)
##    also, fixed bug, when trying to delete 'go dep ensure' source packages (needed to removed grandparent/pkg sub dirs, where gopkg.locks found)


## pre-req installs::::
## install docker and git
## java node wicked csar
## brew ## use brew to install - wget tar 
## go and dep: https://github.com/eclipse/codewind-installer

echo ".."; echo $(date -u) "SOS ... STARTing ... ... ... ..."; echo "..";

filename="SOS-legals-input-codewind.txt";
cqBulkNodeLink="nextCQ"
release="0-13-0"
lastrelease="0-12-0"
offering="Codewind"
declare -a eclipseApprovedLicenses="Adobe-Glyph Apache-1.0 Apache-1.1 Apache-2.0 BSL-1.0 BSD-2-Clause BSD-3-Clause BSD-4-Clause CC-BY-2.5 CC-BY-3.0 CC-BY-4.0 CC-BY-SA-3.0 CC0-1.0 CDDL-1.0 CDDL-1.1 CPL-1.0 GFDL-1.3 GFDL-1.3-only GFDL-1.3-or-later IPL-1.0 ISC MIT MPL-1.1 MPL-2.0 NTP OpenSSL PHP-3.01 PostgreSQL OFL-1.1 Unicode-TOU Unicode-DFS-2015 Unicode-DFS-2016 W3C W3C-19980720 W3C-20150513 X11 Zlib"; #echo "SOS ... ref ... eclipseApprovedLicenses=$eclipseApprovedLicenses"
declare -a eclipseNonApprovedLicenses="GPL"; #echo "SOS ... ref ... eclipseNonApprovedLicenses=$eclipseNonApprovedLicenses"
declare -a eclipseCertainCasesApprovedLicenses="LGPL"; #echo "SOS ... ref ... eclipseCertainCasesApprovedLicenses=$eclipseCertainCasesApprovedLicenses"; #please contact license@eclipse.org for more information. 
    # ref https://www.eclipse.org/legal/licenses.php
    # ref https://spdx.org/licenses/

mkdir -p $offering
mkdir -p $offering/$release
mkdir -p $offering/$release/packages
mkdir -p $offering/$release/packages/src
mkdir -p $offering/$release/packages/containerExports
mkdir -p $offering/$release/containerTars

## finally setup logging for this script
#blockLogging=$1 ; ### logging blocked if runtime option specified
#if [[ -z $blockLogging ]]; then 
#   LOG_FILE=${offering}/sos-log.txt
#   rm ${LOG_FILE}; exec 3>&1 1>>${LOG_FILE} 2>&1
#fi

if [[ 0 == 0 ]]; then #global variables BLOCK
    ### setting GLOBAL variables###########################
    filename="${offering}/${filename}"
    declare -a potentialTags=( "" )
    declare -a SosLegalsInputRows=( "" )
    declare isreleaseInNextYear=""
    declare isreleaseComplete="unknown"
    declare foundNewExternalTag=""
    declare areAllPpc64leContainersTaggedForrelease=""
    declare areAllAmd64ContainersTaggedForrelease=""
    declare areAllZlinuxContainersTaggedForrelease=""
    unameOut="$(uname -s)"
    md5CheckDirLevels=2
    declare -i processPathNodeLevel=0
    declare -i md5NewCount=0
    declare -i md5DupCount=0
    declare -i difNewCount=0
    declare -i difDupCount=0
    declare -i newWarCount=0
    declare -i newZipCount=0
    declare -i newGzCount=0
    processNewArchive=no
fi

if [[ 0 == 0 ]]; then #functions BLOCK
    #################################
    ###  start of functions #########
    #################################
    
    
    function calculateIsreleaseInNextYear {
        echo $(date -u) "SOS ... ......................................."
        echo $(date -u) "SOS ... function called: calculateIsreleaseInNextYear"
    read YYYY MM DD <<<$(date +'%Y %m %d')
    ####MM="12";   ##hardcoded as December, for testing only
    if (( MM == 12 )); then
        isreleaseInNextYear="yes"
    else
        isreleaseInNextYear="no"
    fi 
    }


    function calculatereleaseNumber {
    ##############################
    lastrelease=$1
    #lastrelease=19-09;     ##hard code, for testing '0' numbers and also '>7' octal base numbers
    #lastrelease=19-25;    ##hard code, for testing
    IFS='-' read -ra releasePart <<< "$lastrelease"
    declare -i lastreleaseYear=${release}}}Part[0]}
    if [ $isreleaseInNextYear == "yes" ]; then
        declare -i lastreleaseYearPlusOne=1+${release}}}Part[0]}
        release="${lastreleaseYearPlusOne}-01"
    else
        declare -i lastreleaseNumber=${release}}}Part[1]#0};  ### '#0' converts to base10
        #lastreleaseNumber=${lastreleaseNumber#0}
        declare -i tempNumber=1+$lastreleaseNumber
        if [[ $tempNumber -lt 10 ]]; then
            ### if <10, then convert to string and add leading '0' ###
            lastreleaseNumberPlusOne="0${tempNumber}"
        else
            ### else leave 10, 11, 12... etc, as number 
            lastreleaseNumberPlusOne=$tempNumber
        fi
        release="${lastreleaseYear}-${lastreleaseNumberPlusOne}"
    fi
    echo "SOS ... release = $release"
    }


    function calculatePotentialTags {
    ##############################
    ## this function: take in the last known artifactory tag
    ## then calculates a set of potential next tags (to attempt to pull)
        lastreleaseTag=$1
            echo $(date -u) "SOS ... ......................................."
            echo $(date -u) "SOS ... function called: calculatePotentialTags"
            echo $(date -u) "SOS ... lastreleaseTag=$lastreleaseTag"
        IFS='_' read -ra tagPart <<< "$lastreleaseTag"
        tagYear=${tagPart[0]}
        if [ $isreleaseInNextYear == "yes" ]; then 
            declare -i nextTagYear=1+$tagYear
            potentialTags=( "${nextTagYear}_M1_E" "${nextTagYear}_M2_E" "${nextTagYear}_M3_E")
            #potentialTags=( "${nextTagYear}_M1_E" )
        else
            tagNumberWithM=${tagPart[1]}
            tagNumberString=${tagNumberWithM:1};  ### strip off leading 'M'
            declare -i tagNumber=${tagNumberString#0};   ### '#0' converts to base10
            declare -i tagNumberPlusOne=1+$tagNumber
            declare -i tagNumberPlusTwo=2+$tagNumber          
            declare -i tagNumberPlusThree=3+$tagNumber
            declare -i tagNumberPlusFour=4+$tagNumber
            potentialTags=( "${tagYear}_M${tagNumberPlusOne}_E" "${tagYear}_M${tagNumberPlusTwo}_E" "${tagYear}_M${tagNumberPlusThree}_E" "${tagYear}_M${tagNumberPlusFour}_E" )
            #potentialTags=( "${tagYear}_M${tagNumberPlusTwo}_E" )
        fi
    }


    function pullDockerContainers {
    ############################
    # try docker pulls, if tag matched then (update out.txt line) else pull latest and set isreleaseComplete=no
    # then export 'platform tars' to tribe/release
        echo $(date -u) "SOS ... ......................................."
        echo $(date -u) "SOS ... function called: pullDockerContainers"
    isreleaseComplete=""
    cat ~/getIn.txt | docker login --username nik_canvin@uk.ibm.com --password-stdin sys-mcs-docker-local.artifactory.swg-devops.com
    while read -r line;  ### get all headers from '$filename' above
    do
        IFS='-' read -ra CONTAINERS <<< "$line"
        if [[ ! -z ${CONTAINERS[2]} ]]; then     ##if $filename line contains a '-'
            if [[ ${CONTAINERS[3]} == "sticky" ]]; then
                container=${CONTAINERS[0]}-${CONTAINERS[1]}
                platform=${CONTAINERS[1]}
                tag=${CONTAINERS[2]}
                isSticky="sticky"
            elif [[ ! -z ${CONTAINERS[3]} ]]; then   # container name has a '-' in it, like file-watcher 
                container=${CONTAINERS[0]}-${CONTAINERS[1]}-${CONTAINERS[2]}
                #platform=${CONTAINERS[2]}
                tag=${CONTAINERS[3]}
                isSticky="no"
            else
                container=${CONTAINERS[0]}-${CONTAINERS[1]}
                #platform=${CONTAINERS[1]}
                tag=${CONTAINERS[2]}
                isSticky="no"
            fi

            #if [ $platform == "amd64" ]; then
                #docker rm -f $container-$platform
                if [[ $isSticky == "sticky" ]]; then
                    echo $(date -u) "SOS ... processing ... $lastrelease $container ... tagged as $tag (it's sticky, so the TAG does not change)"
                    newRowText="$line"
                    docker run -d --name $container sys-mcs-docker-local.artifactory.swg-devops.com/${container}:${tag} ls
                    if [[ $platform == "amd64" ]]; then
                    docker container export $container -o ${offering}/${release}/containerTars/$container.tar
                        echo $(date -u) "SOS created $container.tar file"
                    elif [[ $platform == "ppc64le" ]]; then
                        echo $(date -u) "SOS ... SKIPPING this ${container} container on this non-ppc64 box"
                    fi
                else
                    echo $(date -u) "SOS ... processing ... $lastrelease $container ... last tagged as $tag"
                    ####need to test container at each potential tag level, else latest####
                    testTag=""
                    potentialTagFound=""
                    for potentialTag in "${potentialTags[@]}"; do
                    if [[ $potentialTagFound == "" ]]; then
                        echo $(date -u) "SOS ... checking artifactory for: ${container}:${potentialTag}"
                        #docker run -d --name ${container}-${platform} sys-mcs-docker-local.artifactory.swg-devops.com/${container}:${potentialTag} ls
                        docker run -d --name ${container} sys-mcs-docker-local.artifactory.swg-devops.com/${container}:${potentialTag} ls
                        dockerRunResult=$?
                        if [[ ${dockerRunResult} == "125" ]]; then
                            echo $(date -u) "SOS .. ${container}:${potentialTag} ... is NOT in artifactory"
                        else
                            echo $(date -u) "SOS ... ${container}:${potentialTag} ... IS in artifactory"
                            potentialTagFound=${potentialTag}
                            foundNewExternalTag=${potentialTag}
                            newRowText="${container}-${potentialTag}" ; ## this will go into an updated SOS-legals-input.txt file, later below...
                            #if [[ $platform == "amd64" ]]; then
                                #docker container export ${container}-${platform} -o ${offering}/${release}/containerTars/$container.tar
                                docker container export ${container} -o ${offering}/${release}/containerTars/$container.tar
                                echo $(date -u) "SOS created $container.tar file"
                            #fi
                            TAG=${potentialTag}
                            newTAG=${potentialTag}
                        fi
                    fi
                    done
                    ####  once all potential tags checked, then:
                    if [[ $potentialTagFound == "" ]]; then
                    newTAG="latest"
                    echo $(date -u) "SOS ... release incomplete, so still pulling 'latest' from artifactory"
                    docker run -d --name ${container} sys-mcs-docker-local.artifactory.swg-devops.com/${container}:latest ls
                    newRowText="$line"
                    isreleaseComplete="no"
                    if [[ $platform == "amd64" ]]; then
                        docker container export $container -o ${offering}/${release}/containerTars/$container.tar
                            echo $(date -u) "SOS created $container.tar file"
                    fi
                    fi
                fi
            #fi
            SosLegalsInputRows=( "${SosLegalsInputRows[@]}" "${newRowText}")
        fi
    done < "$filename"
    if [[ ${isreleaseComplete} == "no" ]]; then
        echo "SOS ... release is NOT complete"
    else
        isreleaseComplete="yes"
        echo "SOS ... release IS COMPLETE"
    fi
    }


    function calculateNextrelease {
    ############################
    ## this function: take in the last release and figure out what the next will be called
    lastrelease=$1
    if [ $isreleaseInNextYear == "yes" ]; then
        # previous YY+1 '-01'
        declare -i nextreleaseYear=1+$previousreleaseYY
        echo "${nextreleaseYear}-01"
    else
        # previous 'YY-' Num+1
        declare -i nextreleaseNum=1+$previousreleaseNum
        if (( $nextreleaseNum < 10 )); then
            # add a leading '0' to the release number
            nextreleaseNumString="0$nextreleaseNum"
        else
            nextreleaseNumString="$nextreleaseNum"
        fi
        echo "${previousreleaseYY}-${nextreleaseNumString}"
    fi
    }


    function removePrevSeenFiles {
    ###########################
    #echo "DEBUG - removePrevSeenFiles - STARTED"
    nodePath=$1
    #echo "DEBUG - STARTED processing: $nodePath"

    last4CharsOfNodePath=${nodePath: -4}

    if [[ -n $(readlink -n ${nodePath}) ]]; then  ##remove symlinks
            mv -f ${nodePath} ${removedSymlinkFilesDir}
    elif [[ ${last4CharsOfNodePath} == ".gif" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/gifs
    elif [[ ${last4CharsOfNodePath} == ".jpg" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/jpgs
    elif [[ ${last4CharsOfNodePath} == ".png" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/pngs
    elif [[ ${last4CharsOfNodePath} == ".svg" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/svgs
    elif [[ -d ${nodePath} ]]; then
        #echo "SOS ... processing directory: ${nodePath}"
        for nodePathChild in ${nodePath}/*; do
            removePrevSeenFiles ${nodePathChild}
        done
        for nodePathChild in ${nodePath}/.*; do
            #echo "DEBUG ... ... checking if prev seen: $nodePathChild"
            removePrevSeenFiles ${nodePathChild}
        done
    elif [[ -f ${nodePath} ]]; then
        last13CharsOfNodePath=${nodePath: -13}
        if [[ $last13CharsOfNodePath == "/package.json" ]]; then
            # use DIFF to check if previously seen
            diffFileAgainstPrevSeenFiles ${nodePath}
        else
            # use md5 value to check if previously seen
            md5CheckIfFilePrevSeen ${nodePath}
        fi
    else
        :
    fi
    #echo "DEBUG - ENDED processing: $nodePath"
    #echo "DEBUG - removePrevSeenFiles - ENDED"
    }


    function removePrevSeenFilesInArchive {
    ####################################
    if [[ $debug == "yes" ]]; then echo "DEBUG - removePrevSeenFilesInArchive - STARTED"; fi
    if [[ $debug == "yes" ]]; then echo "DEBUG - STARTED processing: $nodePath"; fi

    nodePath=$1
    last4CharsOfNodePath=${nodePath: -4}

    if [[ ${nodePath} == *".."* ]]; then
        echo "DEBUGGER nodePath= $nodePath"
    elif [[ -n $(readlink -n ${nodePath}) ]]; then  ##remove symlinks
            mv -f ${nodePath} ${removedSymlinkFilesDir}
    elif [[ ${last4CharsOfNodePath} == ".gif" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/gifs
    elif [[ ${last4CharsOfNodePath} == ".jpg" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/jpgs
    elif [[ ${last4CharsOfNodePath} == ".png" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/pngs
    elif [[ ${last4CharsOfNodePath} == ".svg" ]]; then
            mv -f ${nodePath} ${removedImageFilesDir}/svgs
    elif [[ -d ${nodePath} ]]; then
        #echo "DEBUG ... processing directory: ${nodePath}"
        for nodePathChild in ${nodePath}/*; do
            removePrevSeenFilesInArchive ${nodePathChild}
        done
        for nodePathChild in ${nodePath}/.*; do
            removePrevSeenFilesInArchive ${nodePathChild}
        done
    elif [[ -f ${nodePath} ]]; then
        diffFileAgainstPrevSeenFiles ${nodePath}
    else
        :
    fi
    if [[ $debug == "yes" ]]; then echo "DEBUG - ENDED processing: $nodePath"; fi
    if [[ $debug == "yes" ]]; then echo "DEBUG - removePrevSeenFilesInArchive - ENDED"; fi
    }


    function md5CheckIfFilePrevSeen {
    ##############################
    ### returns 'isInHistory" if node is in the md5 history file
    ### else returns the new MD5 value and adds it to the MD5 history file
    ##########
    if [[ $debug == "yes" ]]; then echo "DEBUG - md5CheckIfFilePrevSeen - STARTED"; fi
    filePath=$1
    flattenPath="$(echo "${filePath}" | sed 's/\//'-'/g' )"

    if [[ $unameOut == "Linux" ]]; then
        md5Value="$(md5sum ${filePath})"
        md5Value=${md5Value:0:32}
    else
        md5Value="$(md5 -q ${filePath})"
    fi
    if grep -Fq "$md5Value" ${md5Seen}; then
        filePrevSeen md5-compare ${filePath} ${flattenPath}
    else
        echo "${md5Value} ${filePath} ${packagesDir}" >> ${md5SeenDetails}
        echo "${md5Value}" >> ${md5Seen}
        newFileFound md5-compare ${filePath} ${flattenPath}
    fi

    if [[ $debug == "yes" ]]; then echo "DEBUG - md5CheckIfFilePrevSeen - ENDED"; fi
    }


    function diffFileAgainstPrevSeenFiles {
    ####################################
    thisPathFile=$1
    #echo "DEBUG - diffFileAgainstPrevSeenFiles - STARTED"
    #echo "DEBUG - var value - diffCompareDir=${diffCompareDir}"
    #echo "DEBUG - var value - thisPathFile=${thisPathFile}"
    
    ##replace . with - wihtin thisFile (should work for .. to -- too)
    thisPathFileWithoutDoubleDots="$(echo "${thisPathFile}" | sed 's/\.\./'dot-dot'/g' )"
    #echo "DEBUG - var value - thisPathFileWithoutDoubleDots=${thisPathFileWithoutDoubleDots}"
    thisPathFileWithoutDots="$(echo "${thisPathFileWithoutDoubleDots}" | sed 's/\./'-'/g' )"
    #echo "DEBUG - var value - thisPathFileWithoutDots=${thisPathFileWithoutDots}"

    ## make dir to store diff file history
    grandParentDir=$(basename $(dirname $(dirname $thisPathFileWithoutDots))); mkdir -p ${diffCompareDir}/${grandParentDir}
    #echo "DEBUG - var value - grandParentDir=${grandParentDir}"
    parentDir=$(basename $(dirname $thisPathFileWithoutDots))
    #echo "DEBUG - var value - parentDir=${parentDir}"

    prevSeenPath=${diffCompareDir}/${grandParentDir}/${parentDir}
    #echo "DEBUG - var value - prevSeenPath=${prevSeenPath}"
    mkdir -p ${prevSeenPath} 
    touch ${prevSeenPath}/dummy.txt ; ## compare needs at least 1 file to find, so this dummy is temp created

    ## in it, need to store flat path - - - - - file.ext
    flattenThisPathFile="$(echo "${thisPathFileWithoutDots}" | sed 's/\//'-'/g' )"
    #echo "DEBUG - var value - flattenThisPathFile=${flattenThisPathFile}" 
    
    fullHistoryPathFile=${prevSeenPath}/${flattenThisPathFile}
    #echo "DEBUG - var value - fullHistoryPathFile=${fullHistoryPathFile}"

    isFilePreviouslySeen=""
    for prevFile in ${prevSeenPath}/*; do
        #echo "DEBUG - var value - prevFile=${prevFile}"
        if [[ $prevFile == "${prevSeenPath}/dummy.txt" ]]; then
            rm ${prevSeenPath}/dummy.txt
            #echo "DEBUG - removed dummy.txt"
        else
            if [[ -f ${fullHistoryPathFile} ]]; then
                echo "DEBUG - unable to diff - as one of the files does not exist in history for the comparison!!"
            else
                fileDiffContent="$(diff -q ${thisPathFile} ${prevFile})" 
                if [[ -z $fileDiffContent ]]; then
                isFilePreviouslySeen=yes
                #echo "DEBUG - diff MATCHED for - ${prevFile}"
                else
                #echo "DEBUG - diff NOT matched for - ${prevFile}"
                :
                fi   
            fi
        fi
    done
    if [[ $isFilePreviouslySeen == "yes" ]]; then
        filePrevSeen dif-compare ${thisPathFile} ${flattenThisPathFile}
    else
        newFileFound dif-compare ${thisPathFile} ${flattenThisPathFile}
        ## copy file to files previously seen
        cp -r ${thisPathFile} ${fullHistoryPathFile}
        #echo "DEBUG - copied - ${thisPathFile}  --to--  ${fullHistoryPathFile}"
    fi
    #echo "DEBUG - diffFileAgainstPrevSeenFiles - ENDED"

    }


    function filePrevSeen {
    ####################
    if [[ $debug == "yes" ]]; then echo "DEBUG - filePrevSeen - STARTED"; fi
    processedBy=$1
    handleFile=$2
    flattenThisPathFile=$3

    if [[ ${processedBy} == "md5-compare" ]]; then
        mv ${handleFile} ${removedDupFilesDir}/by-Md5/${flattenThisPathFile}
        #echo "DEBUG:         mv ${handleFile} ${removedDupFilesDir}/by-Md5/${flattenThisPathFile}"
        md5DupCount=1+$md5DupCount
    elif [[ ${processedBy} == "dif-compare" ]]; then
        mv ${handleFile} ${removedDupFilesDir}/by-Diff/${flattenThisPathFile}
        #echo "DEBUG:         mv ${handleFile} ${removedDupFilesDir}/by-Diff/${flattenThisPathFile}"
        difDupCount=1+$difDupCount
    else
        echo "ISSUE"
    fi
    echo "SOS ... DUP file - ${processedBy}: ${handleFile}"
    if [[ $debug == "yes" ]]; then echo "DEBUG - filePrevSeen - ENDED"; fi
    }


    function newFileFound {
    ####################
    if [[ $debug == "yes" ]]; then echo "DEBUG - newFileFound - STARTED"; fi
    processedBy=$1
    handleFile=$2
    if [[ ${processedBy} == "md5-compare" ]]; then
        md5NewCount=1+$md5NewCount
    elif [[ ${processedBy} == "dif-compare" ]]; then
        difNewCount=1+$difNewCount
    else
        echo "ISSUE"
    fi
    echo "SOS ... NEW file - ${processedBy}: ${handleFile}"

    ## start special case for archive files ##
    last3CharsOfHandleFile=${handleFile: -3}
    last7CharsOfHandleFile=${handleFile: -7}
    if [[ $last3CharsOfHandleFile == "war" ]]; then
        archiveFileType=war
        newWarCount=1+$newWarCount
        handleNewArchive $handleFile $archiveFileType
    elif [[ $last3CharsOfHandleFile == "zip" ]]; then
        archiveFileType=zip
        newZipCount=1+$newZipCount
        handleNewArchive $handleFile $archiveFileType
    elif [[ $last7CharsOfHandleFile == ".tar.gz" ]]; then
        archiveFileType=tarGz
        newGzCount=1+$newGzCount
        handleNewArchive $handleFile $archiveFileType
    elif [[ $last3CharsOfHandleFile == ".gz" ]]; then
        archiveFileType=gz
        newGzCount=1+$newGzCount
        handleNewArchive $handleFile $archiveFileType
    else
        :
    fi
    ## end special case for archive files ##
    if [[ $debug == "yes" ]]; then echo "DEBUG - newFileFound - ENDED"; fi
    }


    function handleNewArchive {
    ########################
    #echo "DEBUG - handleNewArchive - STARTED"
    #echo "DEBUG - newArchive=$newArchive"
    newArchive=$1
    archiveFileType=$2
    archiveDir=$(dirname "${newArchive}")
    fileName=$(basename $newArchive)

    flattenArchiveDir="$(echo "${archiveDir}" | sed 's/\//'-'/g' )"
    flattenFileName="$(echo "${fileName}" | sed 's/\./'-'/g' )"
        mkdir -p ${archiveDir}/${flattenFileName}; ## << makes new dir in release/pacakges, to store newly unpacked files under


    ## go ##
    if [[ $archiveFileType == "war" ]]; then
        unzip $newArchive -d $archiveDir/$flattenFileName
        mkdir -p ${removedUnpackedArchivesDir}/wars/${flattenArchiveDir}
        mv ${newArchive} ${removedUnpackedArchivesDir}/wars/${flattenArchiveDir}/${fileName}
    elif [[ $archiveFileType == "zip" ]]; then
        unzip $newArchive -d $archiveDir/$flattenFileName
        mkdir -p ${removedUnpackedArchivesDir}/zips/${flattenArchiveDir}
        mv ${newArchive} ${removedUnpackedArchivesDir}/zips/${flattenArchiveDir}/${fileName}
    elif [[ $archiveFileType == "tarGz" ]]; then
        tar -xvf $newArchive -C $archiveDir/$flattenFileName
        mkdir -p ${removedUnpackedArchivesDir}/gzs/${flattenArchiveDir}
        mv ${newArchive} ${removedUnpackedArchivesDir}/gzs/${flattenArchiveDir}/${fileName} 
    elif [[ $archiveFileType == "gz" ]]; then
        gunzip -dkvf $newArchive 
        mv ${newArchive::${#newArchive}-3} $archiveDir/$flattenFileName
        mkdir -p ${removedUnpackedArchivesDir}/gzs/${flattenArchiveDir}
        mv ${newArchive} ${removedUnpackedArchivesDir}/gzs/${flattenArchiveDir}/${fileName}    
    else
        :
    fi
    ## loop through new archive, find and remove any .. dirs, as it causes recursion issues during file diffing
    ## does not WORK - find ${archiveDir}/${flattenFileName} -name ".." -exec rm -rf "{}" \;
    for extractedNode in ${archiveDir}/${flattenFileName}/*; do
        if [[ ${extractedNode} == *".."* ]]; then
            echo "DEBUGGER nodePath= $nodePath"
        else
            removePrevSeenFilesInArchive $extractedNode
        fi
    done
                                            ## note * and .* diff cases
    for extractedNode in ${archiveDir}/${flattenFileName}/.*; do
        if [[ ${extractedNode} == *".."* ]]; then
            echo "DEBUGGER nodePath= $nodePath"
        else
            removePrevSeenFilesInArchive $extractedNode
        fi
    done  
    #echo "DEBUG - handleNewArchive - ENDED"
    }

    ########### end of functions #####################
    ##################################################
fi


## START of processing SOURCE
if [[ "process-source" == "process-source" ]]; then

        if [[ "leave" == "leave" ]]; then # just scan repos, that go into eclipse redistriutables
            ReposToScan="
            https://github.com/eclipse/codewind
            https://github.com/eclipse/codewind-che-plugin
            https://github.com/eclipse/codewind-filewatchers
            https://github.com/eclipse/codewind-appsody-extension
            https://github.com/eclipse/codewind-vscode
            https://github.com/eclipse/codewind-intellij
            https://github.com/eclipse/codewind-installer
            https://github.com/eclipse/codewind-eclipse
            https://github.com/eclipse/codewind-odo-extension
            https://github.com/RuntimeTools/appmetrics-codewind
            https://github.com/eclipse/codewind-operator
            "
        elif [[ 1 == 10 ]]; then # scan ALL codewind repos (including language-profilers and open-apis)
            ReposToScan="
            https://github.com/eclipse/codewind
            https://github.com/eclipse/codewind-che-plugin
            https://github.com/eclipse/codewind-filewatchers
            https://github.com/kabanero-io/appsodyExtension
            https://github.com/eclipse/codewind-vscode
            https://github.com/eclipse/codewind-installer
            https://github.com/eclipse/codewind-eclipse
            https://github.com/eclipse/codewind-java-profiler
            https://github.com/eclipse/codewind-node-profiler
            https://github.ibm.com/eclipse/chai-openapi-response-validator
            https://github.com/eclipse/codewind-openapi-vscode
            https://github.com/eclipse/codewind-openapi-eclipse
            https://github.com/eclipse/codewind-operator
            "
        else 
            ##rm -rf $offering/$release
            ReposToScan="
            https://github.com/eclipse/codewind-installer
            https://github.com/eclipse/codewind-operator
            "
        fi


        if [[ 1 == 1 ]]; then # clone source repos (clone repo's for source + clean re-install actual field node modules used)
            if [[ 1 == 1 ]]; then # either clone repos (or reset from backup to avoid re-cloning where applicable)
                if [[ -d $offering/$release/packages/src-copy ]]; then #restore from backup
                    echo "SOS ... START restoring src clones fromn backup"
                    rm -rf $offering/$release/packages/src
                    cp -r $offering/$release/packages/src-copy $offering/$release/packages/src
                    echo "SOS ... ENDED restoring src clones fromn backup"
                else #download (clone) repos
                    rm -rf $offering/$release; 
                    mkdir -p $offering/$release
                    mkdir -p $offering/$release/packages
                    mkdir -p $offering/$release/packages/src
                    for Repo in $ReposToScan; 
                    do
                        fbname=$(basename "$Repo"); mkdir $offering/$release/packages/src/${fbname}
                        if git clone --single-branch --branch $release $Repo $offering/$release/packages/src/${fbname}; then 
                            echo "SOS ... CLONED branch"
                        else
                            #git clone --single-branch --branch 0.7.0 $Repo $offering/$release/packages/src/${fbname}; 
                            git clone $Repo $offering/$release/packages/src/${fbname}; 
                            echo "SOS ... CLONED latest !!"
                        fi
                        echo "sos .. git cloning command: git clone --single-branch --branch $release $Repo $offering/$release/packages/src/${fbname};"
                        ##                        rm -rf $offering/$release/packages/src/${fbname}/LICENSE
                        ##                        rm -rf $offering/$release/packages/src/${fbname}/NOTICE.md
                    done
                    rm -rf $offering/$release/packages/src-copy; mkdir -p $offering/$release/packages/src-copy
                    cp -r $offering/$release/packages/src/* $offering/$release/packages/src-copy
                    echo "ENDED .. cloning Repos"
                fi
            fi
            if [[ 1 == 1 ]]; then #install any Node sub-dependencies}
                echo "... before Node sub-dependencies install:"; du -s -h $offering/$release/packages/src
                rm -rf ~/$offering/$release/npm-audit.txt; rm -rf ~/$offering/$release/npm-audit-short.txt;
                for packageJsonFilepath in $(find $offering/$release/packages/src -name 'package.json' ); do
                    echo "DEBUG ... packageJsonFilepath = $packageJsonFilepath"
                    packageLockJsonParentDir=$(dirname "${packageJsonFilepath}"); #echo "SOS ... BEFORE npm ci:"; du -s -h $packageLockJsonParentDir
                    rm -rf $packageLockJsonParentDir/node_modules/*
                    #rm -rf $packageLockJsonParentDir/package-lock.json
                    if [[ $packageJsonFilepath == *"/test/"* ]]; then #ignore paths with /test/ in them
                        echo "SOS ... ... IGNORing due to '/test/' devDependency rule: $packageJsonFilepath"
                    else
                        #sed -i '' '/file:/d' $packageJsonFilepath; #removes relative linked local npm modules, from package.json (as they break npm i)
                        potentialPackageLockFilePath=$packageLockJsonParentDir/package-lock.json; echo "SOS DEBUD ... ... checking if exists: $potentialPackageLockFilePath"
                        if [[ -f $potentialPackageLockFilePath ]]; then #package-lock.json exists, then do a clean install form it
                            echo "DEBUG ...  running: (cd $packageLockJsonParentDir && npm ci --production)"
                            (cd $packageLockJsonParentDir && npm ci --production --unsafe-perm); #echo "SOS ... AFTER npm ci:"; du -s -h $packageLockJsonParentDir
                        else #package-lock.json DOES NOT exist, then install form package.json
                            echo "DEBUG ...  running: (cd $packageLockJsonParentDir && npm i --production)"
                            (cd $packageLockJsonParentDir && npm i --production --unsafe-perm); # --loglevel verbose) unsafe-perm added due to appmetrics build failure workaround
                        fi
                        echo "SOS ... processing: $packageLockJsonParentDir" >> ~/$offering/$release/node-tree.txt
                        (cd $packageLockJsonParentDir && npm ls >> ~/$offering/$release/node-tree.txt)
                        echo "npm audit details for: $packageJsonFilepath" >> ~/$offering/$release/npm-audit.txt
                        (cd $packageLockJsonParentDir && npm audit >> ~/$offering/$release/npm-audit.txt)
                    fi
                done 
                echo "... after Node sub-dependencies install:"; du -s -h $offering/$release/packages/src
                rm -rf $offering/$release/packages/src-afterNode-copy; #mkdir -p $offering/$release/packages/src-afterNode-copy
                #cp -r $offering/$release/packages/src/* $offering/$release/packages/src-afterNode-copy
            fi
            if [[ 1 == never ]]; then #attempt NPM audit fix
                rm -rf ~/$offering/$release/npm-audit.txt; rm -rf ~/$offering/$release/npm-audit-short.txt
                rm -rf ~/$offering/$release/npm-audit-fix.txt; rm -rf ~/$offering/$release/npm-audit-fix-short.txt
                for packageJsonFilepath in $(find $offering/$release/packages/src -name 'package.json' ); do
                    packageLockJsonParentDir=$(dirname "${packageJsonFilepath}")
                    (cd $packageLockJsonParentDir && npm i --production --package-lock-only)
                    echo "npm audit details for: $packageJsonFilepath" >> ~/$offering/$release/npm-audit.txt
                    echo "npm audit details for: $packageJsonFilepath" >> ~/$offering/$release/npm-audit-fix.txt
                    (cd $packageLockJsonParentDir && npm audit >> ~/$offering/$release/npm-audit.txt)
                    (cd $packageLockJsonParentDir && npm audit fix --force)
                    (cd $packageLockJsonParentDir && npm audit >> ~/$offering/$release/npm-audit-fix.txt)
                    (cd $packageLockJsonParentDir && rm -rf node_modules)
                done
                while read -r line;
                do
                    echo "DEBUG - $line"
                    if [[ $line == "npm audit details"* ]]; then
                        echo "$line" >> ~/$offering/$release/npm-audit-short.txt
                    elif [[ $line == "found "* ]]; then
                        echo "-- $line" >> ~/$offering/$release/npm-audit-short.txt
                    elif [[ $line == *"vulnerability require"* ]]; then
                        echo "-- -- $line" >> ~/$offering/$release/npm-audit-short.txt
                    fi
                done < ~/$offering/$release/npm-audit.txt
                while read -r line;
                do
                    if [[ $line == "npm audit details"* ]]; then
                        echo "$line" >> ~/$offering/$release/npm-audit-fix-short.txt
                    elif [[ $line == "found "* ]]; then
                        echo "-- $line" >> ~/$offering/$release/npm-audit-fix-short.txt
                    elif [[ $line == *"vulnerability require"* ]]; then
                        echo "-- -- $line" >> ~/$offering/$release/npm-audit-fix-short.txt
                    fi
                done < ~/$offering/$release/npm-audit-fix.txt
            fi
            if [[ 1 == 1 ]]; then # GO PACKAGES using DEP - need hunting for sub-depndencies, then downloading
                rm -f $offering/$release/go-subpackages-dep-ensure.log; touch $offering/$release/go-subpackages-dep-ensure.log
                #rm -f $offering/$release/go-modules.log; touch $offering/$release/go-modules.log
                for filepath in $(find $offering/$release/packages/src -name 'Gopkg.lock' );
                do
                    echo "... GO filepath=$filepath"
                    if [[ 1 == 1 ]]; then #this assumes GO and DEP installed on the machine, and installers all sub-dependencies in a Vendor folder
                        goProjectDirName="$(dirname $filepath)"; goDirName="$(dirname $goProjectDirName)"; goDirName="$(dirname $goDirName)";echo "... GO dir=$goDirName"
                        #copy GO source to go home dir, install dependencies, then copy it back
                        echo "... before set GOPATH=$GOPATH"; export GOPATH="$HOME/go:$HOME/$goDirName"; echo "... after set GOPATH=$GOPATH"
                        #echo "export GOPATH=\"$GOPATH:$HOME/$goDirName\""
                        echo "... GO filepath=$filepath" >> ~/$offering/$release/go-subpackages-dep-ensure.log
                        (cd $goProjectDirName && dep ensure -v && dep status >> ~/$offering/$release/go-subpackages-dep-ensure.log)
                    fi
                    echo "DEBUG start cat go-subpackages-dep-ensure.log"
                    cat ~/$offering/$release/go-subpackages-dep-ensure.log
                    echo "DEBUG ended cat go-subpackages-dep-ensure.log"
                    #echo "DEBUG --- $goProjectDirName"
                    goProjectDirParent="$(dirname $goProjectDirName)"; echo "DEBUG --- $goProjectDirParent"; goProjectDirGrandParent="$(dirname $goProjectDirParent)"; echo "DEBUG --- $goProjectDirGrandParent"
                    rm -rf $goProjectDirGrandParent/pkg/
                done
                rm -rf $offering/$release/packages/src-afterNode-and-Go-copy
                #cp -r $offering/$release/packages/src $offering/$release/packages/src-afterNode-and-Go-copy
            fi
            if [[ 1 == 1 ]]; then # GO PACKAGES using 'go mod' - need hunting for sub-depndencies, then downloading
                rm -f $offering/$release/go-mod-list.log; touch $offering/$release/go-mod-list.log
                for filepath in $(find $offering/$release/packages/src -name 'go.mod' );
                do
                    goProjectDirName="$(dirname $filepath)"; goDirName="$(dirname $goProjectDirName)"; goDirName="$(dirname $goDirName)";echo "... GO dir=$goDirName"
                    echo "... before set GOPATH=$GOPATH"; export GOPATH="$HOME/go:$HOME/$goDirName"; echo "... after set GOPATH=$GOPATH"
                    (cd $goProjectDirName && go mod tidy)
                    (cd $goProjectDirName && go mod vendor)
                    (cd $goProjectDirName && go list -m all >> ~/$offering/$release/go-mod-list.log)
                done
            fi
            if [[ 1 == 1 ]]; then # JAVA PACKAGES need hunting for sub-depndencies, then downloading
                rm -rf $offering/$release/packages/src/JavaDependencies
                ## IGNORE following FOR loop
                for javaPomXmlFile in $(find $offering/$release/packages/src -name 'IGNOREpom.xml' ); do
                    echo "SOS ... found Java pom.xml file: $javaPomXmlFile"
                    parentDir=$(dirname "${javaPomXmlFile}")
                    ( cd $parentDir && mvn install )
                    while read -r line; do
                        if [[ $line == *"lib/"*".jar"* ]]; then
                            mkdir -p $offering/$release/packages/src/JavaDependencies
                            IFS=',' read -a lineSplitByComma <<< "$line"; IFS="/" read -a lineSplitBySlash <<< "${lineSplitByComma[0]}"; #trim trailing comma if exists
                            packageFileName=${lineSplitBySlash[1]}
                            if [[ $prevSeenJars == *"${lineSplitBySlash[1]}"* ]]; then
                                echo "ignore prev seen: ${lineSplitBySlash[1]}"
                            else                            
                                IFS="-" read -a fileNameSplitByDash <<< "${lineSplitBySlash[1]}"
                                IFS="_" read -a fileNameSplitByUnderscore <<< "${fileNameSplitByDash[@]:(-1)}"
                                startOfVersion=${fileNameSplitByUnderscore[@]: (-1)}; #echo "$startOfVersion"
                                version=${startOfVersion%????}
                                echo "VERSION = ${version}"
                                downloadUrl="";
                                if [[ ${fileNameSplitByDash[0]} == "jetty" ]]; then
                                    downloadUrl="https://repo1.maven.org/maven2/org/eclipse/jetty/${fileNameSplitByDash[0]}-${fileNameSplitByDash[1]}/${version}/${packageFileName}"
                               elif [[ ${fileNameSplitByDash[0]} == *"websocket"* ]]; then
                                    downloadUrl="https://repo1.maven.org/maven2/org/eclipse/jetty/websocket/${fileNameSplitByDash[0]}-${fileNameSplitByDash[1]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"
                                elif [[ ${lineSplitBySlash[1]} == *"org.json"* ]]; then
                                    downloadUrl="https://builds.gradle.org:8001/eclipse/update-site/mirror/orbit-oxygen-1a/plugins/${packageFileName}"
                                    echo "URL = ${downloadUrl}"                                     
                                elif [[ ${lineSplitBySlash[1]} == *".io-"* ]]; then
                                    downloadUrl="https://repo1.maven.org/maven2/io/socket/${fileNameSplitByDash[0]}-${fileNameSplitByDash[1]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"   
                                elif [[ ${lineSplitBySlash[1]} == *"okhttp"* ]]; then  
                                    downloadUrl="https://repo1.maven.org/maven2/com/squareup/${fileNameSplitByDash[0]}3/${fileNameSplitByDash[0]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"                                  
                                elif [[ ${lineSplitBySlash[1]} == *"okio"* ]]; then
                                    echo "squareup case: ${lineSplitBySlash[1]}" 
                                    downloadUrl="https://repo1.maven.org/maven2/com/squareup/${fileNameSplitByDash[0]}/${fileNameSplitByDash[0]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"
                                else
                                    echo "OTHER case: ${lineSplitBySlash[1]}"
                                fi
                                if [[ ${downloadUrl} == "" ]]; then
                                    :
                                else
                                    dependencyDir="$(echo "${packageFileName}" | sed 's/\./-/g' )"; #echo "DEBUG - ${dependencyDir}"
                                    dependencyDir=$offering/$release/packages/src/JavaDependencies/${dependencyDir}
                                    mkdir -p ${dependencyDir}
                                    wget ${downloadUrl} -P ${dependencyDir}
                                    unzip ${dependencyDir}/${packageFileName} -d ${dependencyDir}

                                fi
                            fi
                            prevSeenJars=${lineSplitBySlash[1]}+$prevSeenJars ## IGNORE if prev seen this jar
                        fi
                    done < $IGNOREjavaPomXmlFile
                done
                for javaManifestFile in $(find $offering/$release/packages/src -name 'MANIFEST.MF' ); do
                    echo "SOS ... found Java manifest file: $javaManifestFile"
                    while read -r line; do
                        if [[ $line == *"lib/"*".jar"* ]]; then
                            mkdir -p $offering/$release/packages/src/JavaDependencies
                            IFS=',' read -a lineSplitByComma <<< "$line"; IFS="/" read -a lineSplitBySlash <<< "${lineSplitByComma[0]}"; #trim trailing comma if exists
                            packageFileName=${lineSplitBySlash[1]}
                            if [[ $prevSeenJars == *"${lineSplitBySlash[1]}"* ]]; then
                                echo "ignore prev seen: ${lineSplitBySlash[1]}"
                            else                            
                                IFS="-" read -a fileNameSplitByDash <<< "${lineSplitBySlash[1]}"
                                IFS="_" read -a fileNameSplitByUnderscore <<< "${fileNameSplitByDash[@]:(-1)}"
                                startOfVersion=${fileNameSplitByUnderscore[@]: (-1)}; #echo "$startOfVersion"
                                version=${startOfVersion%????}
                                echo "VERSION = ${version}"
                                downloadUrl="";
                                if [[ ${fileNameSplitByDash[0]} == "jetty" ]]; then
                                    downloadUrl="https://repo1.maven.org/maven2/org/eclipse/jetty/${fileNameSplitByDash[0]}-${fileNameSplitByDash[1]}/${version}/${packageFileName}"
                               elif [[ ${fileNameSplitByDash[0]} == *"websocket"* ]]; then
                                    downloadUrl="https://repo1.maven.org/maven2/org/eclipse/jetty/websocket/${fileNameSplitByDash[0]}-${fileNameSplitByDash[1]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"
                                elif [[ ${lineSplitBySlash[1]} == *"org.json"* ]]; then
                                    #downloadUrl="https://builds.gradle.org:8001/eclipse/update-site/mirror/orbit-oxygen-1a/plugins/${packageFileName}"
                                    #note this specical version on JAR has license modification acceptable to Eclipse IP
                                    downloadUrl="https://download.eclipse.org/tools/orbit/downloads/drops/R20190726180751/repository/plugins/org.json_1.0.0.v201011060100.jar"
                                    echo "URL = ${downloadUrl}"                                     
                                elif [[ ${lineSplitBySlash[1]} == *".io-"* ]]; then
                                    downloadUrl="https://repo1.maven.org/maven2/io/socket/${fileNameSplitByDash[0]}-${fileNameSplitByDash[1]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"   
                                elif [[ ${lineSplitBySlash[1]} == *"okhttp"* ]]; then  
                                    downloadUrl="https://repo1.maven.org/maven2/com/squareup/${fileNameSplitByDash[0]}3/${fileNameSplitByDash[0]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"                                  
                                elif [[ ${lineSplitBySlash[1]} == *"okio"* ]]; then
                                    echo "squareup case: ${lineSplitBySlash[1]}" 
                                    downloadUrl="https://repo1.maven.org/maven2/com/squareup/${fileNameSplitByDash[0]}/${fileNameSplitByDash[0]}/${version}/${packageFileName}"
                                    echo "URL = ${downloadUrl}"
                                else
                                    echo "OTHER case: ${lineSplitBySlash[1]}"
                                fi
                                if [[ ${downloadUrl} == "" ]]; then
                                    :
                                else
                                    dependencyDir="$(echo "${packageFileName}" | sed 's/\./-/g' )"; #echo "DEBUG - ${dependencyDir}"
                                    dependencyDir=$offering/$release/packages/src/JavaDependencies/${dependencyDir}
                                    mkdir -p ${dependencyDir}
                                    wget ${downloadUrl} -P ${dependencyDir}; echo "DEBUG ... running: wget ${downloadUrl} -P ${dependencyDir}"
                                    #unzip ${dependencyDir}/${packageFileName} -d ${dependencyDir}

                                fi
                            fi
                            prevSeenJars=${lineSplitBySlash[1]}+$prevSeenJars ## IGNORE if prev seen this jar
                        fi
                    done < $javaManifestFile
                done
            fi
        fi

        if [[ 1 == never ]]; then # DOCKER file analysis - WORK IN PROGRESS
            rm -rf $offering/$release/dockerDependencies; mkdir -p $offering/$release/dockerDependencies
            echo "sos ... STARTED - Codewind Docker work"
                dockerFileAnalysis="$offering/$release/dockerFileAnalysis.log"; rm -rf $dockerFileAnalysis
                dockerFileHttpRefs="$offering/$release/dockerFileHttpReferences.log"; rm -rf $dockerFileHttpRefs
                CodewindDockerImages="
                codewind-java-project-cache
                codewind-pfe-amd64
                codewind-performance-amd64
                codewind-che-sidecar
                codewind-initialize-amd64
                codewind-java-profiler-language-server"
                #OutScopeDockerImages="codewind-che codewind-operator codewind-test codewind-ui"
                for dockerFile in $(find $offering/$release/packages/src -name 'Dockerfile*' ); do 
                    if [[ $dockerFile == *"file-watcher"* ]] || [[ $dockerFile == *"iterative-dev"* ]]; then
                        :
                    else
                        echo "$dockerFile"; echo "$dockerFile" >> $dockerFileAnalysis
                        while read -r line;
                        do
                            if [[ $line == *"#"* ]]; then
                                :
                            else
                                if [[ $line == *"FROM "* ]] || [[ $line == *"wget "* ]] || [[ $line == *"install "* ]] || [[ $line == *"http"* ]] || [[ $line == *"apk"* ]]; then
                                    if [[ $line != *"FROM codewind"* ]]; then
                                        echo "... $line"; echo "... $line" >> $dockerFileAnalysis
                                        for linePart in $line; do
                                            if [[ $linePart == "http"* ]]; then
                                                echo "... ... $linePart"; echo "$linePart" >> $dockerFileHttpRefs
                                                wget $linePart -P $offering/$release/dockerDependencies
                                            fi
                                        done
                                    fi
                                else
                                    :
                                fi
                            fi
                        done < "$dockerFile"
                    fi
                done
            echo "sos ... ENDED - Codewind Docker work"
        fi

        if [[ 1 == 1 ]]; then # create node bulk delta packages cq artifacts
            echo "STARTING sos analysis"
            #rm -rf $offering/$release/*Package-lock.json
            tempBeforeCommasPackageLockJsonFile=$offering/$release/tempBeforeCommasPackage-lock.json
            tempBeforeIndentsPackageLockJsonFile=$offering/$release/tempBeforeIndentsPackage-lock.json
            packageLockJsonFile=$offering/$release/package-lock.json
            if [[ 1 == 1 ]]; then # for new/unique each module, in package-lock.json, add it to an output file
                rm -rf $tempBeforeCommasPackageLockJsonFile
                rm -rf $offering/packageInventory-after-$release.txt
                cp $offering/packageInventory-after-$lastrelease.txt $offering/packageInventory-after-$release.txt
                packageInventory=$offering/packageInventory-after-$release.txt
                #rm -rf $packageInventory; cp $offering/packageInventory.txt $offering/$release
                ###thisreleasePackageInventory=$offering/$release/$release-packageInventory.txt
                deltaNodeModulesSource=$offering/$release/deltaNodeModulesSource; 
                rm -rf $deltaNodeModulesSource
                mkdir -p $deltaNodeModulesSource

                echo "{" >> $tempBeforeCommasPackageLockJsonFile
                echo "    \"name\": \"$offering\"" >>  $tempBeforeCommasPackageLockJsonFile
                echo "    \"version\": \"$release\"" >>  $tempBeforeCommasPackageLockJsonFile
                echo "    \"lockfileVerion\": 1" >>  $tempBeforeCommasPackageLockJsonFile
                echo "    \"requires\": true" >>  $tempBeforeCommasPackageLockJsonFile
                echo "    \"dependencies\": {" >>  $tempBeforeCommasPackageLockJsonFile

                for packageLockJsonFilepath in $(find $offering/$release/packages/src -name 'package-lock.json' ); do
                    echo "DEBUG ... processing lock file: $packageLockJsonFilepath "
                    dependenciesStarted="no"; isNewPackageId="unknown"; 
                    packageName="unknown"; packageVersion=""; packageResolved=""; packageIntegrity=""; isDevDependency="";
                    printedLineOnce="no"
                    while read -r line;
                    do
                        echo "DEBUG line in $packageLockJsonFilepath processing: $line"
                        line=$(echo ${line} | sed 's/,//g'); #remove trailing comma, if it exists
                        if [[ $dependenciesStarted == "no" ]]; then #ignore rows before dependencies start
                            if [[ $line == *"\"dependencies\":"* ]]; then dependenciesStarted="yes"; fi
                        else
                            if [[ $isNewPackageId == "unknown" ]]; then
                                if [[ $packageName == "unknown" ]]; then 
                                    if [[ $line != *"}"* ]]; then 
                                        packageName=$( echo $line | cut -d\" -f2 ); 
                                    fi #echo "DEBUG ... packageNme=$packageName"
                                elif [[ $line == *"\"version\":"* ]]; then packageVersion=$( echo $line | cut -d\" -f4 ); #echo "DEBUG ... packageVersion=$packageVersion"
                                elif [[ $line == *"\"resolved\":"* ]]; then packageResolved=$( echo $line | cut -d\" -f4 ); #echo "DEBUG ... packageResolved=$packageResolved"
                                elif [[ $line == *"\"bundled\":"* ]]; then packageBundled=$( echo $line | cut -d\" -f4 ); #echo "DEBUG ... packageResolved=$packageResolved"
                                elif [[ $line == *"\"integrity\":"* ]]; then packageIntegrity=$( echo $line | cut -d\" -f4 ); #echo "DEBUG ... packageIntegrity=$packageIntegrity"
                                else
                                    if [[ $line == *"\"dev\": true"* ]]; then 
                                        isDevDependency="true"; 
                                        #echo "DEBUG ... isDevDependency=true";
                                    fi
                                    if grep -Fq ":$packageName:$packageVersion:" $packageInventory; then
                                        isNewPackageId="no";
                                        #echo "DEBUG ... ... NOT new: $packageName:$packageVersion"
                                    else
                                        isNewPackageId="yes";
                                        #echo "DEBUG ... ...  is NEW: $packageName:$packageVersion"
                                    fi
                                    if [[ $isDevDependency == "true" ]]; then #do not put it into the bulkNodeCQ (pretending it's not NEW, is a hack)
                                        isNewPackageId="no";
                                        #echo "DEBUG ... ... ... ignoring (from bulkNodeCq) this devSubDep: $packageName:$packageVersion"
                                    fi
                                    #if grep -Fq ":$packageName:$packageVersion:" $packageInventory; then
                                    #    :
                                    #else
                                    #    echo ":$packageName:$packageVersion:$isDevDependency:$packageResolved:" >> $packageInventory
                                    #fi                            
                                fi
                            fi
                            if [[ $line == *"\"dependencies\":"* ]]; then 
                                isNewPackageId="unknown"; 
                                packageName="unknown"; packageVersion=""; packageResolved=""; packageIntegrity=""; 
                                printedLineOnce="no"; isRequiresBlock=""; isDevDependency="";
                            fi
                            if [[ $isNewPackageId == "yes" ]]; then
                                echo "-- isNewPackageId: \"$line\""
                                if [[ $packageName == *"codewind"* ]]; then # ignore packages with 'codewind' in the name
                                    echo "DEBUG - found package: $packageName"
                                else
                                    if [[ $packageResolved == "" ]]; then
                                        packageResolved="https://registry.npmjs.org/$packageName/-/$packageName-$packageVersion.tgz"
                                    fi
                                    #echo "NEW DEBUG ... $packageName in lock file: $packageLockJsonFilepath - isDevDependency: $isDevDependency"
                                    #echo "              $line"
                                    if [[ $printedLineOnce == "no" ]]; then
                                        echo "        \"$packageName\": {" >>  $tempBeforeCommasPackageLockJsonFile
                                        echo "            \"version\": \"$packageVersion\"" >>  $tempBeforeCommasPackageLockJsonFile
                                        echo "            \"resolved\": \"$packageResolved\"" >>  $tempBeforeCommasPackageLockJsonFile
                                        echo "            \"integrity\": \"$packageIntegrity\"" >>  $tempBeforeCommasPackageLockJsonFile 
                                        if [[ $isDevDependency == "true" ]]; then echo "            \"dev\": true" >>  $tempBeforeCommasPackageLockJsonFile; isDevDependency=""; fi
                                        printedLineOnce="yes";
                                        echo "DEBUG ... ... processing: $packageName:$packageVersion - from - $packageResolved"
                                    fi
                                    if [[ $line == *"requires"* ]]; then 
                                        #echo "requires {"
                                        echo "            $line" >>  $tempBeforeCommasPackageLockJsonFile
                                        isRequiresBlock="yes";
                                    elif [[ $isRequiresBlock == "yes" ]]; then
                                        if [[ $line == *"}"* ]] || [[ $line == *"},"* ]] ; then # handle last line of requires block
                                            isRequiresBlock="";
                                            echo "            }" >>  $tempBeforeCommasPackageLockJsonFile
                                            echo "        }" >>  $tempBeforeCommasPackageLockJsonFile                  

                                            echo ":$packageName:$packageVersion:$isDevDependency:$packageResolved:$cqBulkNodeLink" >> $packageInventory
                                            if [[ 1 == 1 ]]; then
                                                ############################
                                                # download and unpack source
                                                deltaNodeModulesSourcePackage=$deltaNodeModulesSource/$packageName--$packageVersion;  
                                                mkdir -p $deltaNodeModulesSourcePackage
                                                echo "DEBUG ... running: wget $packageResolved -P $deltaNodeModulesSource"
                                                wget $packageResolved -P $deltaNodeModulesSource
                                                tar -xvf $deltaNodeModulesSource/*.tgz -C $deltaNodeModulesSourcePackage
                                                rm -rf $deltaNodeModulesSource/*.tgz
                                                ############################
                                            fi
                                            isNewPackageId="unknown"; 
                                            packageName="unknown"; packageVersion=""; packageResolved=""; packageIntegrity=""; isDevDependency="";
                                            printedLineOnce="no"; isRequiresBlock="no";


                                        else # add required package to the output json file
                                            echo "                $line" >>  $tempBeforeCommasPackageLockJsonFile
                                        fi
                                    else
                                        if [[ $line == *"}"* ]] || [[ $line == *"},"* ]]; then
                                            lastLineIntempBeforeCommasPackageLockJsonFile=$( tail -n 1 $tempBeforeCommasPackageLockJsonFile )
                                            if [[ $lastLineIntempBeforeCommasPackageLockJsonFile != "        }" ]]; then
                                                echo "        }" >>  $tempBeforeCommasPackageLockJsonFile
                                            fi
                                            echo ":$packageName:$packageVersion:$isDevDependency:$packageResolved:$cqBulkNodeLink" >> $packageInventory
                                            if [[ 1 == 1 ]]; then
                                                ############################
                                                # download and unpack source
                                                deltaNodeModulesSourcePackage=$deltaNodeModulesSource/$packageName--$packageVersion;  
                                                mkdir -p $deltaNodeModulesSourcePackage
                                                echo "DEBUG ... running: wget $packageResolved -P $deltaNodeModulesSource"
                                                wget $packageResolved -P $deltaNodeModulesSource
                                                tar -xvf $deltaNodeModulesSource/*.tgz -C $deltaNodeModulesSourcePackage
                                                rm -rf $deltaNodeModulesSource/*.tgz
                                                ############################
                                            fi
                                            isNewPackageId="unknown"; 
                                            packageName="unknown"; packageVersion=""; packageResolved=""; packageIntegrity=""; isDevDependency="";
                                            printedLineOnce="no"; isRequiresBlock="no";
                                        fi
                                    fi
                                fi
                            elif [[ $isNewPackageId == "no" ]]; then #this block works out when the final } is, of a non-new package, before reseting packageId
                                #echo "DEBUG - processing NOT new package code"
                                ##echo "-- isNOTNewPackageId: \"$line\""
                                if [[ $line == *"requires"* ]]; then
                                    isRequiresBlock="yes"; #echo "DEBUG ... ... ... has a requires block"
                                elif [[ $isRequiresBlock == "yes" ]]; then
                                    if [[ $line == *"}"* ]]; then isRequiresBlock=""; fi
                                else
                                    if [[ $line == *"}"* ]]; then
                                        isNewPackageId="unknown"; 
                                        packageName="unknown"; packageVersion=""; packageResolved=""; packageIntegrity=""; isDevDependency="";
                                        printedLineOnce="no";
                                    fi
                                fi
                            else
                                :
                            fi
                        fi
                        previousLine="$line";
                        previousPreviousLine="$previousLine";
                    done < "$packageLockJsonFilepath"
                done

                echo "    }" >>  $tempBeforeCommasPackageLockJsonFile
                echo "}" >>  $tempBeforeCommasPackageLockJsonFile
                
                # now ZIP up, then remove, the deltaNodeModules source packages
                (cd $offering/$release && zip -r node_modules.zip deltaNodeModulesSource);
            fi
            ##
            if [[ 1 == 1 ]]; then # add commas in the correct places
                rm -rf $tempBeforeIndentsPackageLockJsonFile
                echo "SOS ... STARTED fixing COMMAs into new: $tempBeforeIndentsPackageLockJsonFile"
                previousLine=""; line=""; lastChar="";
                while read -r line; do
                    if [[ $previousLine == "" ]]; then
                        :; # ignore first line, we only print lines to file, when we can compare to previous line, to determine is need ot add ','
                    else
                        lastCharInThisLine=$( echo -n $line | tail -c 1 ); #echo "DEBUG ... last Char of ... $line ... is ... $lastCharInLine"            
                        lastCharInLastLine=$( echo -n $previousLine | tail -c 1 ); #echo "DEBUG ... last Char of ... $line ... is ... $lastCharInLine"
                        if [[ $lastCharInLastLine == "{" ]]; then
                            lastChar=""
                        else
                            if [[ $lastCharInThisLine == "}" ]]; then
                                lastChar=""
                            else
                                lastChar=","
                            fi
                        fi
                        if [[ $lastChar == "," ]]; then
                            echo "$previousLine," >> $tempBeforeIndentsPackageLockJsonFile;
                        else
                            echo "$previousLine" >> $tempBeforeIndentsPackageLockJsonFile;  
                        fi
                    fi
                    previousLine="$line"
                done < $tempBeforeCommasPackageLockJsonFile
                echo "}" >> $tempBeforeIndentsPackageLockJsonFile;
                rm -rf $tempBeforeCommasPackageLockJsonFile
                echo "SOS ... ENDED fixing COMMAs into new: $tempBeforeIndentsPackageLockJsonFile"
            fi
            ##
            if [[ 1 == 1 ]]; then #add INDENTS to file
                rm -rf $packageLockJsonFile
                echo "SOS ... STARTED adding INDENTs into new: $packageLockJsonFile"
                indent=""; previousLine=""; lastCharInLastLine="";
                while read -r line;
                do
                    if [[ $previousLine == *"{"* ]]; then
                        indent=$( echo "$indent    " )
                    elif [[ ${#indent} -gt 3 ]]; then
                        if [[ $previousLine == *"}" ]]; then
                            indent=$( echo "${indent:0:${#indent}-4}" )
                        elif [[ $lastCharInLastLine != "," ]]; then
                            indent=$( echo "${indent:0:${#indent}-4}" )
                        else
                            :
                        fi
                    fi
                    echo "$indent$line" >> $packageLockJsonFile
                    previousLine=$line;
                    lastCharInLastLine=$( echo -n $previousLine | tail -c 1 );
                done < $tempBeforeIndentsPackageLockJsonFile
                rm -rf $tempBeforeIndentsPackageLockJsonFile
                echo "SOS ... ENDED adding INDENTs into new: $packageLockJsonFile"
            fi
        fi

        if [[ 1 == NEVER ]]; then #CSAR scan bulk Node stuff
            rm -rf $offering/$release/csar; mkdir -p $offering/$release/csar
            echo "SOS ... STARTING csar scan of bulk Node delta packages for Eclipse CQ"
            ~/CSAR_Home/bin/scan.sh -z -p ~/$offering/$release/csar ~/$offering/$release/deltaNodeModulesSource
            ./SOS-csar-scan.sh ~/$offering/$release/csar/scanner-0.xml ~/$offering/$release/csar/deltaNodePackage-Results.xml
            echo "SOS ... ... tip: ~/CSAR_Home/csar.sh.command ~/$offering/$release/csar/deltaNodePackage-Results.xml"
            echo "SOS ... ENDED csar scan of bulk Node delta packages for Eclipse CQ"
            #rm -rf $offering/$release/deltaNodeModulesSource
        fi

        if [[ 1 == 1 ]]; then #full copyrights scan
            rm -rf ${offering}/${release}/copyrights.txt
            echo $(date -u) "SOS ... start creating ${offering}/${release}/copyrights.txt"
            sh ./sh/sosGetCopyrights.sh $offering/$release/packages src consolidate 
            #sed -i -e "s|$offering/$release/packages/src/||g" $offering/$release/packages/src-copyrights.txt
            echo $(date -u) "SOS ... ended creating ${offering}/${release}/copyrights.txt"
        fi

        if [[ 1 == NEVER ]]; then #remove prev seen files
            echo "SOS ... started doRemovePrevSeenFiles"
            filesPrevSeenDir="filesPrevSeen"; prevSeenScope="whole-release"; #prevSeenScope="ever-until"
            packagesDir=${offering}/${release}/packages/src

            if [ ! -d $packagesDir-all ]; then #backup packages dir
                echo "SOS ... started creating packages-all"; cp -r $packagesDir $packagesDir-all
                :
            else #restore from backup
                echo "SOS ... removing potentially modified 'packages-dir'"; rm -rf $packagesDir
                echo "SOS ... restoring 'packages' from backup"; cp -r $packagesDir-all $packagesDir; echo "SOS ... ... (done)"
                :
            fi 

            rm -rf ${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}*; mkdir -p ${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}
            ## (now doing WHOLE release) cp -r ${offering}/${filesPrevSeenDir}/${prevSeenScope}/${lastrelease}/* ${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}
            diffCompareDir=${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}/byDiffCompare; mkdir -p ${diffCompareDir}
            md5CompareDir=${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}/byMd5Compare; mkdir -p ${md5CompareDir}
            md5SeenDetails=${md5CompareDir}/md5-Seen-Details.txt; touch ${md5SeenDetails} 
            md5Seen=${md5CompareDir}/md5-Seen.txt; touch ${md5Seen}

            removedPackageFilesDir=${offering}/${release}/removedPackageFiles; rm -rf ${removedPackageFilesDir}; mkdir -p ${removedPackageFilesDir}
            removedDupFilesDir=${removedPackageFilesDir}/dupFiles; rm -rf ${removedDupFilesDir}
            mkdir -p ${removedDupFilesDir}; mkdir -p ${removedDupFilesDir}/by-Diff; mkdir -p ${removedDupFilesDir}/by-Md5
            removedImageFilesDir=${removedPackageFilesDir}/images; rm -rf ${removedImageFilesDir}; 
            mkdir -p ${removedImageFilesDir}; mkdir -p ${removedImageFilesDir}/gifs; mkdir -p ${removedImageFilesDir}/jpgs
            mkdir -p ${removedImageFilesDir}/pngs; mkdir -p ${removedImageFilesDir}/svgs
            removedSymlinkFilesDir=${removedPackageFilesDir}/symlinks; rm -rf ${removedSymlinkFilesDir}; mkdir -p ${removedSymlinkFilesDir}
            #removedDotDotDir=${removedPackageFilesDir}/dot-dot; rm -rf ${removedDotDotDir}; mkdir -p ${removedDotDotDir}
            removedUnpackedArchivesDir=${removedPackageFilesDir}/unpackedArchives; rm -rf ${removedUnpackedArchivesDir}; 
            mkdir -p ${removedUnpackedArchivesDir}; mkdir -p ${removedUnpackedArchivesDir}/wars; mkdir -p ${removedUnpackedArchivesDir}/zips; mkdir -p ${removedUnpackedArchivesDir}/gzs 

            #allFilesCount="$(find $packagesDir -type f | wc -l)"

            ## ----------------------------

                removePrevSeenFiles $packagesDir

            ## ----------------------------

            packagesSize="$(du -s -h ./${packagesDir})"
            echo $(date -u) "SOS ... starting MD5 scan for ${release}: files size after processing: ${packagesSize} (${packagesSizeAfterTarsUnpacked})"

            declare -i totalNewCount=$md5NewCount+$difNewCount
            declare -i totalDupCount=$md5DupCount+$difDupCount
            echo $(date -u) "SOS ... results: $totalNewCount new files  ($md5NewCount via md5;  $difNewCount via diff) ($newWarCount new WARs; $newZipCount new ZIPs; $newGzCount new GZs)"
            echo $(date -u) "SOS ... results: $totalDupCount dup files  ($md5DupCount via md5;  $difDupCount via diff)"

            echo "SOS ... ended doRemovePrevSeenFiles"
        fi

        if [[ 1 == 1 ]]; then #wicked scan all the packages in the release (add GO subDependencies version data which was generated above)
            rm -rf $offering/$release/packages/src/*/LICENSE
            rm -rf $offering/$release/packages/src/*/NOTICE.md
            if [[ 1 == 1 ]]; then
                mkdir -p ${offering}/${release}/wickedScans; mkdir -p ${offering}/${release}/wickedScans/wholerelease
                echo "node --max-old-space-size=4096 /usr/local/bin/wicked-cli -s ${offering}/${release}/packages/src -o ${offering}/${release}/wickedScans/wholerelease"
                node --max-old-space-size=4096 /usr/local/bin/wicked-cli -s ${offering}/${release}/packages/src -o ${offering}/${release}/wickedScans/wholerelease
            fi
            if [[ 1 == NEVER-NOT-FINISHED ]]; then # tweak @node/modules, as Excel break it
            echo "... START attempting to fix @ node module ERRRORs in the wicked CSV"
                rm -rf ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-fixedNodeAt.csv
                touch ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-fixedNodeAt.csv
                # for each wicked entry
                while read -r line;
                do
                    IFS='"' read -a linePart <<< "$line"
                    #echo "linePart[3]: ${linePart[3]}"
                    if [[ ${linePart[0]} == *"@"* ]]; then #if VERSION is unknown
                        echo "${line}"; 
                    else #pass through wicked line (as version known)
                        echo "$line"
                        echo "$line" >> ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-fixedNodeAt.csv
                    fi
                done < ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report.csv
                echo "... ENDED attempting to fix @ node module ERRRORs in the wicked CSV"
            fi
            if [[ -f $offering/$release/go-subpackages-dep-ensure.log ]]; then
                echo "... START attempting to fill GO DEP sub-dependency version gaps in wicked output"
                rm -rf ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-Go-dep-versions-added.csv
                # for each wicked entry
                while read -r line;
                do
                    IFS='"' read -a linePart <<< "$line"
                    #echo "linePart[3]: ${linePart[3]}"
                    if [[ ${linePart[3]} == "unknown" && ${linePart[17]} == *"/vendor/"* ]]; then #if VERSION is unknown
                        echo "${linePart[3]} ---- ${linePart[17]}"; 
                        matched=""; enhancedWickedLine=""
                        while read -r depEnsureLine;
                        do
                            IFS=' ' read -a depEnsureLinePart <<< "$depEnsureLine"
                            if [[ ${linePart[17]} == *"${depEnsureLinePart[0]}"* ]]; then
                                matched="yes"
                                if [[ ${depEnsureLinePart[1]} == ${depEnsureLinePart[2]} ]]; then
                                    enhancedWickedLine="\"${depEnsureLinePart[0]}\",\"${depEnsureLinePart[1]}\",\"${linePart[5]}\",\"${linePart[7]}\",\"${linePart[9]}\",\"${linePart[11]}\",\"${linePart[13]}\",\"${linePart[15]}\",\"${linePart[17]}\""
                                else
                                    enhancedWickedLine="\"${depEnsureLinePart[0]}\",\"${depEnsureLinePart[1]} ${depEnsureLinePart[2]}\",\"${linePart[5]}\",\"${linePart[7]}\",\"${linePart[9]}\",\"${linePart[11]}\",\"${linePart[13]}\",\"${linePart[15]}\",\"${linePart[17]}\""
                                fi
                                #echo "$enhancedWickedLine" #>> ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-Go-dep-versions-added.csv
                            fi
                        done < $offering/$release/go-subpackages-dep-ensure.log
                        if [[ $matched == "yes" ]]; then
                            echo "$enhancedWickedLine"
                            echo "$enhancedWickedLine" >> ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-Go-dep-versions-added.csv
                        fi
                    else #pass through wicked line (as version known)
                        echo "$line"
                        echo "$line" >> ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-Go-dep-versions-added.csv 
                    fi
                done < ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report.csv
                echo "... ENDED attempting to fill GO DEP sub-dependency version gaps in wicked output"
            fi
            if [[ -f $offering/$release/go-mod-list.log ]]; then
                echo "... START attempting to fill GO MOD sub-dependency version gaps in wicked output"
                rm -rf ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-ALL-Go-versions-added.csv
                if [[ -f ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-Go-dep-versions-added.csv ]]; then
                    inputWickedFile=${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-Go-dep-versions-added.csv
                else
                    inputWickedFile=${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report.csv
                    echo "--- using VANNILA wicked file (as dep csv not found)"
                fi
                # for each wicked entry
                while read -r line;
                do
                    IFS='"' read -a linePart <<< "$line"
                    if [[ ${linePart[3]} == "unknown" && ${linePart[17]} == *"/vendor/"* ]]; then #if VERSION is unknown
                        echo "${linePart[17]}"; matched=""; enhancedWickedLine="";
                        while read -r goModLine;
                        do
                            IFS=' ' read -a depEnsureLinePart <<< "$goModLine"
                            if [[ ${linePart[17]} == *"${depEnsureLinePart[0]}"* ]]; then
                                if [[ $matched != "yes" ]]; then #only want to write found version number once in new CSV file                              
                                    if [[ ${depEnsureLinePart[1]} == ${depEnsureLinePart[2]} ]]; then
                                        enhancedWickedLine="\"${depEnsureLinePart[0]}\",\"${depEnsureLinePart[1]}\",\"${linePart[5]}\",\"${linePart[7]}\",\"${linePart[9]}\",\"${linePart[11]}\",\"${linePart[13]}\",\"${linePart[15]}\",\"${linePart[17]}\""
                                    else
                                        enhancedWickedLine="\"${depEnsureLinePart[0]}\",\"${depEnsureLinePart[1]} ${depEnsureLinePart[2]}\",\"${linePart[5]}\",\"${linePart[7]}\",\"${linePart[9]}\",\"${linePart[11]}\",\"${linePart[13]}\",\"${linePart[15]}\",\"${linePart[17]}\""
                                    fi
                                    #echo "$enhancedWickedLine" >> ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-ALL-Go-versions-added.csv
                                fi
                                matched="yes"
                            fi
                        done < $offering/$release/go-mod-list.log
                        if [[ $matched == "yes" ]]; then
                            echo "$enhancedWickedLine" >> ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-ALL-Go-versions-added.csv
                        fi
                    else #pass through wicked line as it was
                        echo "$line" >> ${offering}/${release}/wickedScans/wholerelease/src_scan-results/Scan-Report-ALL-Go-versions-added.csv 
                    fi
                done < $inputWickedFile
                echo "... ENDED attempting to fill GO MOD sub-dependency version gaps in wicked output"
            fi

        fi

else
    echo "--- XXX --- NOT processing SOURCE --- XXX ---"
fi
## END of processing SOURCE



######## CONTAINER STUFF below
##############################
##############################
##############################

## START of processing CONTAINERS
if [[ "process-containers" == "process-containers-NO" ]]; then

        packagesDir=${offering}/${release}/packages/containerExports
        if [[ -d $packagesDir-copy ]]; then # restore from containerExports-copy if it exists
            if [[ "ignore-restore" == "ignore-restore-XX" ]]; then
                rm -rf $packagesDir; mkdir -p $packagesDir
                echo "SOS ... restoring from containerExports-all ... "; cp -r $packagesDir-copy/* $packagesDir
            fi
        else # containers to get
            containers="codewind-java-project-cache codewind-java-profiler-language-server codewind-che-sidecar codewind-pfe-amd64 codewind-performance-amd64"
            #containers="codewind-initialize-amd64"
            echo $(date -u) "SOS ...clear out docker images/containers, to ensure we pull fresh docker stuff"
            docker container stop $(docker container ls -a -q) && docker system prune -a -f --volumes
            echo $(date -u) "SOS ... started pulling new tagged containers or latest, exporting amd64s too"
            rm -rf $offering/$release/containerTars/*
            #cat ~/getIn.txt | docker login --username nik_canvin@uk.ibm.com --password-stdin sys-mcs-docker-local.artifactory.swg-devops.com
            for container in $containers; do
                echo "ibmcom/$container"
                docker run -d --name $container ibmcom/$container:latest ls 
                docker container export $container -o ${offering}/${release}/containerTars/$container.tar
            done
            echo $(date -u) "SOS ... ended pulling new tagged containers or latest, exporting amd64s too"
            ## unpack container exports
            echo $(date -u) "SOS ... start unpacking TARs into packages folder"
            rm -rf ${offering}/${release}/packages/containerExports/*
            for tarFile in ${offering}/${release}/containerTars/*; do
                containerTarWithExt=$(basename $tarFile)
                containerTar=${containerTarWithExt/.tar/}
                containerPackagesTargetDir=${offering}/${release}/packages/containerExports/${containerTar}
                echo "SOS ... processing ... ${containerPackagesTargetDir}"
                mkdir -p ${containerPackagesTargetDir}
                tar -xvf $tarFile -C $containerPackagesTargetDir
            done
            ## remove files not wanting to scan
            echo $(date -u) "SOS ... start removing symlinks/openJDKs/code-license/notices files, before legals scanning"
            rm -rf $offering/$release/packages/containerExports/codewind-java-profiler-language-server/dev/*; echo "WARNING - SOS removed: codewind-java-profiler-language-server/dev/*"
            for container in ${offering}/${release}/packages/containerExports/*; do
                rm -rf $container/*.md ## remove LICENSE.md and NOTICE.md
                if [[ -f $container/opt/java/jre/openj9-openjdk-notices ]]; then ## if version of java is open JDK then
                    rm -rf $container/opt/java/jre ## remove OPEN JDK
                fi
                rm -rf $container/opt/ibm/java/*
                find $container -type l | xargs rm
            done
            echo $(date -u) "SOS ... ended removing symlinks/openJDKs/code-license/notices files, before legals scanning"
            rm -rf ${offering}/${release}/packages/containerExports-copy; mkdir -p ${offering}/${release}/packages/containerExports-copy
            cp -r ${offering}/${release}/packages/containerExports/* ${offering}/${release}/packages/containerExports-copy
            echo $(date -u) "SOS ... ended making COPY of containerExports"
        fi

        if [[ 1 == 10 ]]; then ## remove files previously cleared..

            echo "SOS ... started doRemovePrevSeenFiles"
            filesPrevSeenDir="filesPrevSeen"; prevSeenScope="containers-all"
            fileSizeBefore="$(du -s -h ./${packagesDir})"

            rm -rf ${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}*; mkdir -p ${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}
            cp -r ${offering}/${filesPrevSeenDir}/temp-forContainerInput/* ${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}
            diffCompareDir=${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}/byDiffCompare; mkdir -p ${diffCompareDir}
            md5CompareDir=${offering}/${filesPrevSeenDir}/${prevSeenScope}/${release}/byMd5Compare; mkdir -p ${md5CompareDir}
            md5SeenDetails=${md5CompareDir}/md5-Seen-Details.txt; touch ${md5SeenDetails} 
            md5Seen=${md5CompareDir}/md5-Seen.txt; touch ${md5Seen}

            removedPackageFilesDir=${offering}/${release}/removedPackageFiles; rm -rf ${removedPackageFilesDir}; mkdir -p ${removedPackageFilesDir}
            removedDupFilesDir=${removedPackageFilesDir}/dupFiles; rm -rf ${removedDupFilesDir}
            mkdir -p ${removedDupFilesDir}; mkdir -p ${removedDupFilesDir}/by-Diff; mkdir -p ${removedDupFilesDir}/by-Md5
            removedImageFilesDir=${removedPackageFilesDir}/images; rm -rf ${removedImageFilesDir}; 
            mkdir -p ${removedImageFilesDir}; mkdir -p ${removedImageFilesDir}/gifs; mkdir -p ${removedImageFilesDir}/jpgs
            mkdir -p ${removedImageFilesDir}/pngs; mkdir -p ${removedImageFilesDir}/svgs
            removedSymlinkFilesDir=${removedPackageFilesDir}/symlinks; rm -rf ${removedSymlinkFilesDir}; mkdir -p ${removedSymlinkFilesDir}
            #removedDotDotDir=${removedPackageFilesDir}/dot-dot; rm -rf ${removedDotDotDir}; mkdir -p ${removedDotDotDir}
            removedUnpackedArchivesDir=${removedPackageFilesDir}/unpackedArchives; rm -rf ${removedUnpackedArchivesDir}; 
            mkdir -p ${removedUnpackedArchivesDir}; mkdir -p ${removedUnpackedArchivesDir}/wars; mkdir -p ${removedUnpackedArchivesDir}/zips; mkdir -p ${removedUnpackedArchivesDir}/gzs 

            #allFilesCount="$(find $packagesDir -type f | wc -l)"

            ## ----------------------------

                removePrevSeenFiles $packagesDir

            ## ----------------------------

            packagesSize="$(du -s -h ./${packagesDir})"
            echo $(date -u) "SOS ... starting MD5 scan for ${release}: files size before processing: ${fileSizeBefore}"
            echo $(date -u) "SOS ... starting MD5 scan for ${release}: files size after processing: ${packagesSize} (${packagesSizeAfterTarsUnpacked})"

            declare -i totalNewCount=$md5NewCount+$difNewCount
            declare -i totalDupCount=$md5DupCount+$difDupCount
            echo $(date -u) "SOS ... results: $totalNewCount new files  ($md5NewCount via md5;  $difNewCount via diff) ($newWarCount new WARs; $newZipCount new ZIPs; $newGzCount new GZs)"
            echo $(date -u) "SOS ... results: $totalDupCount dup files  ($md5DupCount via md5;  $difDupCount via diff)"

            echo "SOS ... ended doRemovePrevSeenFiles"

        fi
        if [[ 1 == 1 ]]; then ## wicked scan
            #rm -rf ${offering}/${release}/wickedScans; mkdir -p ${offering}/${release}/wickedScans
            rm -rf ${offering}/${release}/packages/tempWickedExtract; mkdir -p ${offering}/${release}/packages/tempWickedExtract
            node --max-old-space-size=4096 /usr/local/bin/wicked-cli -s ${offering}/${release}/packages/containerExports -o ${offering}/${release}/wickedScans -z ${offering}/${release}/packages/tempWickedExtract
        fi
        if [[ 1 == 10 ]]; then ## copyrights
            rm -rf ${offering}/${release}/copyrights.txt
            echo $(date -u) "SOS ... start creating ${offering}/${release}/copyrights.txt"
            sh ./sh/sosGetCopyrights.sh $offering/$release/packages src consolidate 
            echo $(date -u) "SOS ... ended creating ${offering}/${release}/copyrights.txt"
        fi
fi
## END of processing CONTAINERS
echo ".."; echo $(date -u) "SOS ... ENDED ... ... ... ..."; echo "..";
#echo "node --max-old-space-size=4096 /usr/local/bin/wicked-cli -s ${offering}/${release}/packages/src -o ${offering}/${release}/wickedScans/wholerelease"

