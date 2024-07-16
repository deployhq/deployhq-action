# GitHub Action to Trigger a Deployment on DeployHQ with a Webhook URL 🚀

This action calls the DeployHQ's [Webhook URL](https://www.deployhq.com/support/deployments/automatic-deployments/custom) created for your DeployHQ account to trigger a deployment on DeployHQ. 

## Usage

All sensitive variables should be [set as encrypted secrets](https://help.github.com/en/articles/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables) in the action's configuration.

### Configuration Variables

| Key                        | Value                                                                                                                                                                                                                         | Suggested Type | Required |
|----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ------------- | ------------- |
| `DEPLOYHQ_WEBHOOK_URL`     | **Required.** Your DeployHQ webhook URL. Can be found in your DeployHQ Dashboard, under "Automatic Deployments"                                                                                                               | `secret` | **Yes** |
| `REPO_REVISION`            | **Required.** The revision you wish to deploy. Can also be set to "latest" if you wish to deploy the latest revision in your set branch.                                                                                      | `secret` | **Yes** |
| `REPO_BRANCH`              | **Required.** The branch your revision is on.                                                                                                                                                                                 | `secret` | **Yes** |
| `DEPLOYHQ_EMAIL`           | **Required.** Your DeployHQ user. For example, matias@barilla.com.                                                                                                                                                            | `secret` | **Yes** |
| `REPO_CLONE_URL`           | **Required.** The path to your repository (as entered in the Deploy UI).                                                                                                                                                      | `secret` | **Yes** |

### `workflow.yml` Example

Place in a `.yml` file such as this one in your `.github/workflows` folder. [Refer to the documentation on workflow YAML syntax here.](https://help.github.com/en/articles/workflow-syntax-for-github-actions)

```yaml
name: Deploy my website in DeployHQ w/ my webhook URL
on: push

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:

    # Put steps here to build your site, deploy it to a service, etc.
    - name: Trigger deployment in DeployHQ w/ webhook URL
      uses: viktodorov/deployhq-action@main
      env:
        # All these values should be set as encrypted secrets in your repository settings
        DEPLOYHQ_WEBHOOK_URL: ${{ secrets.DEPLOYHQ_WEBHOOK_URL }}
        REPO_REVISION: ${{ secrets.REPO_REVISION }}
        REPO_BRANCH: ${{ secrets.REPO_BRANCH }}
        DEPLOYHQ_EMAIL: ${{ secrets.DEPLOYHQ_EMAIL }} 
        REPO_CLONE_URL: ${{ secrets.REPO_CLONE_URL }}
```

## License

This project is distributed under the [MIT license](LICENSE.md).
