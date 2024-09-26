const express = require('express');
const graph = require('@microsoft/microsoft-graph-client');
const { DefaultAzureCredential } = require("@azure/identity");
require('isomorphic-fetch');

const PORT = process.env.PORT || 3000;
const app = express();

async function getMIGraphAccessToken() {
    let tokenResponse = await new DefaultAzureCredential().getToken('https://graph.microsoft.com/.default');
    return tokenResponse.token;
}

function getGraphClient() {
    const client = graph.Client.init({
        authProvider: async done => { done(null, await getMIGraphAccessToken()); }
    });

    return client;
}

app.get('/', (req, res) => {
    res.send('Test Graph API token retrieved from Managed Identity');
});

app.get('/token', async (req, res) => {
    let token = await getMIGraphAccessToken();
    res.send(token);
});

app.get('/users', async (req, res) => {
    let cli = getGraphClient();
    let users = await cli.api('/users').select(["id", "userPrincipalName", "displayName"]).get();

    res.send(users.value);
});

app.listen(PORT, () => {
    console.log('Server is running on port ' + PORT);
});

