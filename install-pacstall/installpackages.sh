#!/bin/bash
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$package - attempt to capture frames"
      echo " "
      echo "$package [options] application [arguments]"
      echo " "
      echo "options:"
      echo "-I, --Install               Installs package"
      echo "-S, --Search       Search for package"
      echo "-R, --Remove      Removes package"
      exit 0
      ;;
    -I)
      repo="Henryws"
      RED='\033[0;31m'
      CYAN='\033[0;36m'
      NC='\033[0m' # No Color
      if [ ! -d /tmp/pacstall ]; then
	  mkdir -p /tmp/pacstall;
      fi
      echo -e "${RED}input package name...${NC}"
      read package

      #This is the part where it searches your package on all repos and puts it in /tmp
      echo "Strings are equal, proceeding to install $package"
      echo "cleaning /tmp/pacstall"
      sudo rm -rf /tmp/pacstall
      sudo mkdir /tmp/pacstall
      cd /tmp/pacstall/
      echo "cleaning package folder"
      sudo rm -rf $package
      sudo mkdir $package

      wget -q --show-progress --progress=bar:force:noscroll https://github.com/$repo/test-pacstall/raw/master/packages/$package/$package.tar.xz
      echo -e "${RED}extracting...${NC}"
      tar -xf $package.tar.xz
      cd $package
      echo -e "${CYAN}Downloading and running install script for ${NC}$package"
      wget https://raw.githubusercontent.com/$repo/test-pacstall/master/packages/$package/install.sh | bash
      sudo chmod a+x install.sh
      sudo ./install.sh
      echo "Cleaning up..."
      cd /tmp/pacstall
      rm -rf $package*
      ;;
    -S)
     repo=Henryws
     echo what package do you want to search?
     read $package
     wget -q --spider https://github.com/$repo/test-pacstall/tree/master/packages/$package/$package.tar.xz
     if [ $? -eq 0 ]; then
        echo Package is available
     else
        echo Package is not available. Add another repo or check your spelling
     fi
      ;;
    -R)
      echo "what package should be removed?"
      read $package
      sudo dpkg -r $package
      if [ $? -eq 0 ]; then
          echo "$package has been succesfuly removed"
      else
          echo "$package could not be removed"
      fi
      ;;
    *)
      break
      ;;
  esac
done







