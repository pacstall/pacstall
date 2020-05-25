make
if checkinstall ; then
    echo "checkinstall succeded... Installing"
else
    echo "checkinstall failed... running make install"
    make install
fi
