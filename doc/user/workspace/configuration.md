---
stage: Create
group: IDE
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Workspace configuration **(PREMIUM ALL BETA)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/112397) in GitLab 15.11 [with a flag](../../administration/feature_flags.md) named `remote_development_feature_flag`. Disabled by default.
> - [Enabled on GitLab.com and self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/391543) in GitLab 16.0.

FLAG:
On self-managed GitLab, by default this feature is available.
To hide the feature, an administrator can [disable the feature flag](../../administration/feature_flags.md) named `remote_development_feature_flag`.
On GitLab.com, this feature is available.
The feature is not ready for production use.

WARNING:
This feature is in [Beta](../../policy/experiment-beta-support.md#beta) and subject to change without notice.
To leave feedback, see the [feedback issue](https://gitlab.com/gitlab-org/gitlab/-/issues/410031).

You can use [workspaces](index.md) to create and manage isolated development environments for your GitLab projects.
Each workspace includes its own set of dependencies, libraries, and tools,
which you can customize to meet the specific needs of each project.

## Set up a workspace

> Support for private projects [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/124273) in GitLab 16.4.

### Prerequisites

- Set up a Kubernetes cluster that the GitLab agent for Kubernetes supports.
  See the [supported Kubernetes versions](../clusters/agent/index.md#supported-kubernetes-versions-for-gitlab-features).
- Ensure autoscaling for the Kubernetes cluster is enabled.
- In the Kubernetes cluster, verify that a [default storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/)
  is defined so that volumes can be dynamically provisioned for each workspace.
- In the Kubernetes cluster, install an Ingress controller of your choice (for example, `ingress-nginx`)
  and make that controller accessible over a domain. For example, point `*.workspaces.example.dev` and
  `workspaces.example.dev` to the load balancer exposed by the Ingress controller.
- In the Kubernetes cluster, [install `gitlab-workspaces-proxy`](https://gitlab.com/gitlab-org/remote-development/gitlab-workspaces-proxy#installation-instructions).
- In the Kubernetes cluster, [install the GitLab agent for Kubernetes](../clusters/agent/install/index.md).
- Configure remote development settings for the GitLab agent with this snippet and update `dns_zone` as needed:

  ```yaml
  remote_development:
    enabled: true
    dns_zone: "workspaces.example.dev"
  ```

  You can use any agent defined under the root group of your project,
  provided that remote development is properly configured for that agent.
- You must have at least the Developer role in the root group.
- In each project you want to use this feature for, create a [devfile](index.md#devfile):
  1. On the left sidebar, select **Search or go to** and find your project.
  1. In the root directory of your project, create a file named `.devfile.yaml`.
     You can use one of the [example configurations](index.md#example-configurations).
- Ensure the container images used in the devfile support [arbitrary user IDs](index.md#arbitrary-user-ids).

### Create a workspace

To create a workspace:

1. On the left sidebar, select **Search or go to**.
1. Select **Your work**.
1. Select **Workspaces**.
1. Select **New workspace**.
1. From the **Select project** dropdown list, [select a project with a `.devfile.yaml` file](#prerequisites).
1. From the **Select cluster agent** dropdown list, select a cluster agent owned by the group the project belongs to.
1. In **Time before automatic termination**, enter the number of hours until the workspace automatically terminates.
   This timeout is a safety measure to prevent a workspace from consuming excessive resources or running indefinitely.
1. Select **Create workspace**.

The workspace might take a few minutes to start.
To open the workspace, under **Preview**, select the workspace.
You also have access to the terminal and can install any necessary dependencies.

## Connect to a workspace with SSH

> [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/10478) in GitLab 16.3.

Prerequisites:

- SSH must be enabled for the workspace.
- You must have a TCP load balancer that points to [`gitlab-workspaces-proxy`](https://gitlab.com/gitlab-org/remote-development/gitlab-workspaces-proxy).

To connect to a workspace with an SSH client:

1. Run this command:

   ```shell
   ssh <workspace_name>@<ssh_proxy>
   ```

1. For the password, enter your personal access token with at least the `read_api` scope.

When you connect to `gitlab-workspaces-proxy` through the TCP load balancer,
`gitlab-workspaces-proxy` examines the username (workspace name) and interacts with GitLab to verify:

- The personal access token
- User access to the workspace

### Set up `gitlab-workspaces-proxy` for SSH connections

Prerequisite:

- You must have an SSH host key for client verification.

SSH is now enabled by default in [`gitlab-workspaces-proxy`](https://gitlab.com/gitlab-org/remote-development/gitlab-workspaces-proxy).
To set up `gitlab-workspaces-proxy` with the GitLab Helm chart:

1. Run this command:

   ```shell
   ssh-keygen -f ssh-host-key -N '' -t rsa
   export SSH_HOST_KEY=$(pwd)/ssh-host-key
   ```

1. Install `gitlab-workspaces-proxy` with the generated SSH host key:

   ```shell
   helm upgrade --install gitlab-workspaces-proxy \
         gitlab-workspaces-proxy/gitlab-workspaces-proxy \
         --version 0.1.8 \
         --namespace=gitlab-workspaces \
         --create-namespace \
         --set="auth.client_id=${CLIENT_ID}" \
         --set="auth.client_secret=${CLIENT_SECRET}" \
         --set="auth.host=${GITLAB_URL}" \
         --set="auth.redirect_uri=${REDIRECT_URI}" \
         --set="auth.signing_key=${SIGNING_KEY}" \
         --set="ingress.host.workspaceDomain=${GITLAB_WORKSPACES_PROXY_DOMAIN}" \
         --set="ingress.host.wildcardDomain=${GITLAB_WORKSPACES_WILDCARD_DOMAIN}" \
         --set="ingress.tls.workspaceDomainCert=$(cat ${WORKSPACES_DOMAIN_CERT})" \
         --set="ingress.tls.workspaceDomainKey=$(cat ${WORKSPACES_DOMAIN_KEY})" \
         --set="ingress.tls.wildcardDomainCert=$(cat ${WILDCARD_DOMAIN_CERT})" \
         --set="ingress.tls.wildcardDomainKey=$(cat ${WILDCARD_DOMAIN_KEY})" \
         --set="ssh.host_key=$(cat ${SSH_HOST_KEY})" \
         --set="ingress.className=nginx"
   ```

### Update your runtime images

To update your runtime images for SSH connections:

1. Install [`sshd`](https://man.openbsd.org/sshd.8) in your runtime images.
1. Create a user named `gitlab-workspaces` to allow access to your container without a password.

```Dockerfile
FROM golang:1.20.5-bullseye

# Install `openssh-server` and other dependencies
RUN apt update \
    && apt upgrade -y \
    && apt install  openssh-server sudo curl git wget software-properties-common apt-transport-https --yes \
    && rm -rf /var/lib/apt/lists/*

# Permit empty passwords
RUN sed -i 's/nullok_secure/nullok/' /etc/pam.d/common-auth
RUN echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config

# Generate a workspace host key
RUN ssh-keygen -A
RUN chmod 775 /etc/ssh/ssh_host_rsa_key && \
    chmod 775 /etc/ssh/ssh_host_ecdsa_key && \
    chmod 775 /etc/ssh/ssh_host_ed25519_key

# Create a `gitlab-workspaces` user
RUN useradd -l -u 5001 -G sudo -md /home/gitlab-workspaces -s /bin/bash gitlab-workspaces
RUN passwd -d gitlab-workspaces
ENV HOME=/home/gitlab-workspaces
WORKDIR $HOME
RUN mkdir -p /home/gitlab-workspaces && chgrp -R 0 /home && chmod -R g=u /etc/passwd /etc/group /home

# Allow sign-in access to `/etc/shadow`
RUN chmod 775 /etc/shadow

USER gitlab-workspaces
```

## Disable remote development in the GitLab agent for Kubernetes

You can stop the `remote_development` module of the GitLab agent for Kubernetes from communicating with GitLab.
To disable remote development in the GitLab agent configuration, set this property:

```yaml
remote_development:
  enabled: false
```

If you already have running workspaces, an administrator must manually delete these workspaces in Kubernetes.

## Related topics

- [Quickstart guide for GitLab remote development workspaces](https://go.gitlab.com/AVKFvy)
- [Set up your infrastructure for on-demand, cloud-based development environments in GitLab](https://go.gitlab.com/dp75xo)

## Troubleshooting

### `Failed to renew lease` when creating a workspace

You might not be able to create a workspace due to a known issue in the GitLab agent for Kubernetes.
The following error message might appear in the agent's log:

```plaintext
{"level":"info","time":"2023-01-01T00:00:00.000Z","msg":"failed to renew lease gitlab-agent-remote-dev-dev/agent-123XX-lock: timed out waiting for the condition\n","agent_id":XXXX}
```

This issue occurs when an agent instance cannot renew its leadership lease, which results
in the shutdown of leader-only modules including the `remote_development` module.
To resolve this issue, restart the agent instance.
