# GitHub Action to Trigger a Deployment on DeployHQ 🚀

This simple action calls the [DeployHQ API](https://www.deployhq.com/support/api/deployments/create-a-new-deployment) to trigger a deployment on DeployHQ.


## Usage

All sensitive variables should be [set as encrypted secrets](https://help.github.com/en/articles/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables) in the action's configuration.

### Configuration Variables

| Key                        | Value                                                                                                                                                                                                                         | Suggested Type | Required |
|----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ------------- | ------------- |
| `DEPLOYHQ_USER_ID`      | **Required.** Your DeployHQ user. For example, `adam@atechmedia.com`.                                                                                                                                                            | `secret` | **Yes** |
| `DEPLOYHQ_API_TOKEN`      | **Required.** The Api Token that will be used for authentication, which can be found in your DeployHQ Dashboard, under `Settings` >> `Security`. For example, `a74b8262ebae565e7572b37a94b11e27decadf05`.                      | `secret` | **Yes** |
| `DEPLOYHQ_SUBDOMAIN`      | **Required.** Your DeployHQ subdomain. For example, if your url is `https://matias.deployhq.com`, then it's `matias`.                                                                                                          | `secret` | **Yes** |
| `DEPLOYHQ_PROJECT_ID` | **Required.** The DeployHQ Project ID in which the deployment will be triggered. For example, if they URL to your project is `https://matias.deployhq.com/projects/italy`, then this variable would be `italy`.                    | `secret` | **Yes** |                                                                                                   | `secret` | **Yes** |
| `DEPLOYHQ_PARENT_ID`      | **Required.** The server (or server group) to which you're deploying.                                                                                                                                                          | `secret` | **Yes** |
| `DEPLOYHQ_START_REVISION`    | **Required.** The start revision of the deployment (a blank value can be sent if you wish to deploy the entire branch).                                                                                                     | `env` | **Yes** |
| `DEPLOYHQ_END_REVISION`    | **Required.** The end revision of the deployment.                                                                                                                                                                             | `env` | **Yes** |


### `workflow.yml` Example

Place in a `.yml` file such as this one in your `.github/workflows` folder. [Refer to the documentation on workflow YAML syntax here.](https://help.github.com/en/articles/workflow-syntax-for-github-actions)

```yaml
name: Deploy my website in DeployHQ
on: push

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:

    # Put steps here to build your site, deploy it to a service, etc.
    - name: Trigger deployment in DeployHQ
      uses: HarmonicVic/DeployHQ-action@main
      env:
        # All these values should be set as encrypted secrets in your repository settings
        DEPLOYHQ_USER_ID: ${{ secrets.DEPLOYHQ_USER_ID }}
        DEPLOYHQ_API_TOKEN: ${{ secrets.DEPLOYHQ_API_TOKEN }}
        DEPLOYHQ_SUBDOMAIN: ${{ secrets.DEPLOYHQ_SUBDOMAIN }}
        DEPLOYHQ_PROJECT_ID: ${{ secrets.DEPLOYHQ_PROJECT_ID }} 
        DEPLOYHQ_PARENT_ID: ${{ secrets.DEPLOYHQ_PARENT_ID }}
```

## License

This project is distributed under the [MIT license](LICENSE.md).
