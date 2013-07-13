# Accessing the Build Server
http://yauniks.suroot.com:8080/

# Authenticating to the Build Server
You must login to the build server with GitHub once. After that contact me and send me and send me your GitHub username.

# Using the Build Server
Click the "android" job.  
Configure what you want to build.  
Build it.  

# Modifying the local_manifest.xml
Edit ics.xml (the ics local_manifest.xml) and submit a pull request.  
Or edit gingerbread.xml (the gingerbread local_manifest.xml) and submit a pull request.  

# Jenkins Job Setup
The job uses the following script:

```bash
curl -O https://raw.github.com/yanniks/hudson/master/job.sh
. ./job.sh
```
