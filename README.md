# Using Managed Identities of Azure App Service to access Graph APIs

This sample demonstrates how to use Managed Identities of Azure App Service to access Graph APIs.

## How to run this sample

1. Create an App Service for NodeJS in Azure and enable its System Assigned Managed Identity.

2. Run the `Grant-MIRole.ps1` script to grant the Managed Identity the required permissions, as in the example below:

    ```powershell
    .\Grant-MIRole.ps1 -TenantID "your-tenant-id" -ManagedIdentityName "appservice-name" -GraphPermissionName Directory.Read.All
    ```

    > **NOTE**: you need to be a Global Administrator in the tenant to run this script.

3. Publish the app code to the App Service via VS Code, Github Actions or via CLI from the current folder:

    ```bash
    az webapp up --name <appservice-name>
    ```

4. Wait some minutes for the App Service to restart, then access the app in the browser at the URL: `https://<appservice-name>.azurewebsites.net`: it should display the message "Test Graph API token retrieved from Managed Identity".

5. Open `https://<appservice-name>.azurewebsites.net/token`. Copy the token and decode it at [jwt.io](https://jwt.io/). The token should contain the required permissions to access the Graph API [= `Directory.Read.All`] in the `"roles"` claim.

6. To test the Graph API access, open `https://<appservice-name>.azurewebsites.net/users`. The app should display the list of users in the tenant.
