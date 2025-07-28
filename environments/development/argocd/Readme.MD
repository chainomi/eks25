# Github app setup
1. Go to create github app
2. Enter the name - must be unique to the world
3. Enter the homepage and webhook urls
   1. homepage - http://<atlantis-domain>
4. No need to enable webhooks, uncheck it and leave field blank
5. Enable the following under Repoository and Org permissions see example - https://medium.com/@wadexu007/unlocking-the-power-of-argocd-mastering-app-of-apps-for-seamless-application-management-9c8bc78242fd

   1. Contents	Read 
   2.  Metadata	Read-only (default)
6.  Click on create Github app
7.  Next generate private key - the key will be created and download by your browser
8.  Click on install app, you can install on account or org
9.  Select repositories needed or all repositories
10. Installation ID can be found in - https://github.com/settings/installations
    1.  Click on configure next to the app the url will have the install id e.g. https://github.com/settings/installations/<ID> 
