# Readme

## Generating webhook and secret

webhooks
 - https://www.runatlantis.io/docs/configuring-webhooks#github-github-enterprise
 - https://docs.github.com/en/webhooks/using-webhooks/creating-webhooks
Generate webhook secret - https://www.browserling.com/tools/random-string

Folder structure / auto-planning
https://www.runatlantis.io/docs/autoplanning.html

## setup github app and custom workflow

https://medium.com/@wadexu007/advanced-configuration-of-atlantis-with-github-apps-for-customized-terraform-workflows-c74bce4c7fde
Customer workflow - https://github.com/wadexu007/learning_by_doing/blob/main/Atlantis/base/configmap.yaml
https://www.youtube.com/watch?v=d_IMfEledII


# workflow config 
https://www.runatlantis.io/docs/server-side-repo-config 

# Github app setup
1. Go to create github app
2. Enter the name - must be unique to the world
3. Enter the homepage and webhook urls
   1. homepage - http://<atlantis-domain>
   2. webhookurl - https://<atlantis-domain>/events
4. Enable the following under Repoository and Org permissions - https://www.runatlantis.io/docs/access-credentials.html#github-app
   1. Administration	Read-only
   2. Checks	Read and write
   3. Commit statuses	Read and write
   4. Contents	Read and write
   5. Issues	Read and write
   6.  Metadata	Read-only (default)
   7.  Pull requests	Read and write
   8.  Webhooks	Read and write
   9.  Members	Read-only
   10. Actions	Read-only

5.  Enable the following under subscribe to events. 
   1. Check run
   2. Issue comment
   3. Issues
   4. Pull requests
   5. Pull request review
   6. Pull request review comment
   7. Push
6.  Click on create Github app
7.  Next generate private key - the key will be created and download by your browser
8.  Click on install app, you can install on account or org
9.  Select repositories needed or all repositories
10. Installation ID can be found in - https://github.com/settings/installations
    1.  Click on configure next to the app the url will have the install id e.g. https://github.com/settings/installations/<ID> 
11. Generate a random string of text for the webhook secret - https://docs.github.com/en/webhooks/using-webhooks/creating-webhooks#creating-a-repository-webhook 
    1.  Enter the secret in the Github app settings
12. Set `ATLANTIS_WRITE_GIT_CREDS: true` in helm chart
13. 
