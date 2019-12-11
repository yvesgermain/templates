if (! (test-path c:\templates\devops)) {md c:\templates\devops}
set-location c:\templates\devops
git clone http://srvtfs01:8080/tfs/SOQUIJ/GuichetUnique/_git/DevOps
git pull
