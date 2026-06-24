This README exists in the Build folder of the lwdaq10.7 branch of our LWDAQ repositor.
It lists the actions a developer must take to merge Tcl and Pascal files from the 
master branch into this branch. The lwdaq10.7 branch preserves compatibility with
older MacOS computers running 10.9+. 

git switch lwdaq10.7
git restore --source master -- '*.pas' '*.tcl'
git status
git add -A
git commit -m "Update Pascal and Tcl sources from master"

Now edit Init.tcl to change the version to 10.7.x. Edit lwdaq.pas to change the library
version to 10.7. Build libraries for MacOS, Windows, and Linux. That should be all.