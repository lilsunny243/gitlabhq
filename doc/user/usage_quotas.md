---
type: howto
stage: Fulfillment
group: Utilization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Storage usage quota **(FREE ALL)**

Storage usage statistics are available for projects and namespaces. You can use that information to
manage storage usage within the applicable quotas.

Statistics include:

- Storage usage across projects in a namespace.
- Storage usage that exceeds the storage quota.
- Available purchased storage.

## View storage usage

Prerequisites:

- To view storage usage for a project, you must have at least the Maintainer role for the project or Owner role for the namespace.
- To view storage usage for a namespace, you must have the Owner role for the namespace.

1. On the left sidebar, select **Search or go to** and find your project or group.
1. On the left sidebar, select **Settings > Usage Quotas**.
1. Select the **Storage** tab.

Select any title to view details. The information on this page
is updated every 90 minutes.

If your namespace shows `'Not applicable.'`, push a commit to any project in the
namespace to recalculate the storage.

### Container Registry usage **(FREE SAAS)**

Container Registry usage is available only for GitLab.com. This feature requires a
[new version](https://about.gitlab.com/blog/2022/04/12/next-generation-container-registry/)
of the GitLab Container Registry. To learn about the proposed release for self-managed
installations, see [epic 5521](https://gitlab.com/groups/gitlab-org/-/epics/5521).

#### How container registry usage is calculated

Image layers stored in the Container Registry are deduplicated at the root namespace level.

An image is only counted once if:

- You tag the same image more than once in the same repository.
- You tag the same image across distinct repositories under the same root namespace.

An image layer is only counted once if:

- You share the image layer across multiple images in the same container repository, project, or group.
- You share the image layer across different repositories.

Only layers that are referenced by tagged images are accounted for. Untagged images and any layers
referenced exclusively by them are subject to [online garbage collection](packages/container_registry/delete_container_registry_images.md#garbage-collection).
Untagged image layers are automatically deleted after 24 hours if they remain unreferenced during that period.

Image layers are stored on the storage backend in the original (usually compressed) format. This
means that the measured size for any given image layer should match the size displayed on the
corresponding [image manifest](https://github.com/opencontainers/image-spec/blob/main/manifest.md#example-image-manifest).

Namespace usage is refreshed a few minutes after a tag is pushed or deleted from any container repository under the namespace.

#### Delayed refresh

It is not possible to calculate [container registry usage](#container-registry-usage)
with maximum precision in real time for extremely large namespaces (about 1% of namespaces).
To enable maintainers of these namespaces to see their usage, there is a delayed fallback mechanism.
See [epic 9413](https://gitlab.com/groups/gitlab-org/-/epics/9413) for more details.

If the usage for a namespace cannot be calculated with precision, GitLab falls back to the delayed method.
In the delayed method, the displayed usage size is the sum of **all** unique image layers
in the namespace. Untagged image layers are not ignored. As a result,
the displayed usage size might not change significantly after deleting tags. Instead,
the size value only changes when:

- An automated [garbage collection process](packages/container_registry/delete_container_registry_images.md#garbage-collection)
  runs and deletes untagged image layers. After a user deletes a tag, a garbage collection run
  is scheduled to start 24 hours later. During that run, images that were previously tagged
  are analyzed and their layers deleted if not referenced by any other tagged image.
  If any layers are deleted, the namespace usage is updated.
- The namespace's registry usage shrinks enough that GitLab can measure it with maximum precision.
  As usage for namespaces shrinks to be under the [limits](#namespace-storage-limit),
  the measurement switches automatically from delayed to precise usage measurement.
  There is no place in the UI to determine which measurement method is being used,
  but [issue 386468](https://gitlab.com/gitlab-org/gitlab/-/issues/386468) proposes to improve this.

### Storage usage statistics

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/68898) project-level graph in GitLab 14.4 [with a flag](../administration/feature_flags.md) named `project_storage_ui`. Disabled by default.
> - Enabled on GitLab.com in GitLab 14.4.
> - Enabled on self-managed in GitLab 14.5.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/71270) in GitLab 14.5.

The following storage usage statistics are available to a maintainer:

- Total namespace storage used: Total amount of storage used across projects in this namespace.
- Total excess storage used: Total amount of storage used that exceeds their allocated storage.
- Purchased storage available: Total storage that has been purchased but is not yet used.

## Manage your storage usage

To manage your storage, if you are a namespace Owner you can [purchase more storage for the namespace](../subscriptions/gitlab_com/index.md#purchase-more-storage-and-transfer).

Depending on your role, you can also use the following methods to manage or reduce your storage:

- [Reduce package registry storage](packages/package_registry/reduce_package_registry_storage.md).
- [Reduce dependency proxy storage](packages/dependency_proxy/reduce_dependency_proxy_storage.md).
- [Reduce repository size](project/repository/reducing_the_repo_size_using_git.md).
- [Reduce container registry storage](packages/container_registry/reduce_container_registry_storage.md).
- [Reduce wiki repository size](../administration/wikis/index.md#reduce-wiki-repository-size).
- [Manage artifact expiration period](../ci/yaml/index.md#artifactsexpire_in).
- [Reduce build artifact storage](../ci/jobs/job_artifacts.md#delete-job-log-and-artifacts).

To automate storage usage analysis and management, see the [storage management automation](storage_management_automation.md) documentation.

## Manage your transfer usage

Depending on your role, to manage your transfer usage you can [reduce Container Registry data transfers](packages/container_registry/reduce_container_registry_data_transfer.md).

## Project storage limit

Projects on GitLab SaaS have a 10 GB storage limit on their Git repository and LFS storage.
After namespace-level storage limits are applied, the project limit is removed. A namespace has either a namespace-level storage limit or a project-level storage limit, but not both.

When a project's repository and LFS reaches the quota, the project is set to a read-only state.
You cannot push changes to a read-only project. To monitor the size of each
repository in a namespace, including a breakdown for each project,
[view storage usage](#view-storage-usage). To allow a project's repository and LFS to exceed the free quota
you must purchase additional storage. For more details, see [Excess storage usage](#excess-storage-usage).

### Excess storage usage

Excess storage usage is the amount that a project's repository and LFS exceeds the [project storage limit](#project-storage-limit). If no
purchased storage is available the project is set to a read-only state. You cannot push changes to a read-only project.
To remove the read-only state you must [purchase more storage](../subscriptions/gitlab_com/index.md#purchase-more-storage-and-transfer)
for the namespace. When the purchase is completed, read-only projects are automatically restored to their standard state. The
amount of purchased storage available must always be greater than zero.

The **Storage** tab of the **Usage Quotas** page warns you of the following:

- Purchased storage available is running low.
- Projects that are at risk of becoming read-only if purchased storage available is zero.
- Projects that are read-only because purchased storage available is zero. Read-only projects are
  marked with an information icon (**{information-o}**) beside their name.

#### Excess storage example

The following example describes an excess storage scenario for a namespace:

| Repository | Storage used | Excess storage | Quota  | Status               |
|------------|--------------|----------------|--------|----------------------|
| Red        | 10 GB        | 0 GB           | 10 GB  | Read-only **{lock}** |
| Blue       | 8 GB         | 0 GB           | 10 GB  | Not read-only        |
| Green      | 10 GB        | 0 GB           | 10 GB  | Read-only **{lock}** |
| Yellow     | 2 GB         | 0 GB           | 10 GB  | Not read-only        |
| **Totals** | **30 GB**    | **0 GB**       | -      | -                    |

The Red and Green projects are read-only because their repositories and LFS have reached the quota. In this
example, no additional storage has yet been purchased.

To remove the read-only state from the Red and Green projects, 50 GB additional storage is purchased.

Assuming the Green and Red projects' repositories and LFS grow past the 10 GB quota, the purchased storage
available decreases. All projects no longer have the read-only status because 40 GB purchased storage is available:
50 GB (purchased storage) - 10 GB (total excess storage used).

| Repository | Storage used | Excess storage | Quota   | Status            |
|------------|--------------|----------------|---------|-------------------|
| Red        | 15 GB        | 5 GB           | 10 GB   | Not read-only     |
| Blue       | 14 GB        | 4 GB           | 10 GB   | Not read-only     |
| Green      | 11 GB        | 1 GB           | 10 GB   | Not read-only     |
| Yellow     | 5 GB         | 0 GB           | 10 GB   | Not read-only     |
| **Totals** | **45 GB**    | **10 GB**      | -       | -                 |

## Namespace storage limit

Namespaces on GitLab SaaS have a storage limit. For more information, see our [pricing page](https://about.gitlab.com/pricing/).

After namespace storage limits are enforced, view them in the **Usage quotas** page.
For more information about the namespace storage limit enforcement, see the FAQ pages for the [Free](https://about.gitlab.com/pricing/faq-efficient-free-tier/#storage-limits-on-gitlab-saas-free-tier) and [Paid](https://about.gitlab.com/pricing/faq-paid-storage-transfer/) tiers.

Namespace storage limits do not apply to self-managed deployments, but administrators can [manage the repository size](../administration/settings/account_and_limit_settings.md#repository-size-limit).

Storage types that add to the total namespace storage are:

- Git repository
- Git LFS
- Job artifacts
- Container registry
- Package registry
- Dependency proxy
- Wiki
- Snippets

If your total namespace storage exceeds the available namespace storage quota, all projects under the namespace become read-only. Your ability to write new data is restricted until the read-only state is removed. For more information, see [Restricted actions](../user/read_only_namespaces.md#restricted-actions).

To notify you that you have nearly exceeded your namespace storage quota:

- In the command-line interface, a notification displays after each `git push` action when you've reached 95% and 100% of your namespace storage quota.
- In the GitLab UI, a notification displays when you've reached 75%, 95%, and 100% of your namespace storage quota.
- GitLab sends an email to members with the Owner role to notify them when namespace storage usage is at 70%, 85%, 95%, and 100%.

To prevent exceeding the namespace storage limit, you can:

- [Manage your storage usage](#manage-your-storage-usage).
- If you meet the eligibility requirements, you can apply for:
  - [GitLab for Education](https://about.gitlab.com/solutions/education/join/)
  - [GitLab for Open Source](https://about.gitlab.com/solutions/open-source/join/)
  - [GitLab for Startups](https://about.gitlab.com/solutions/startups/)
- Consider using a [self-managed instance](../subscriptions/self_managed/index.md) of GitLab, which does not have these limits on the Free tier.
- [Purchase additional storage](../subscriptions/gitlab_com/index.md#purchase-more-storage-and-transfer) units at $60/year for 10 GB of storage.
- [Start a trial](https://about.gitlab.com/free-trial/) or [upgrade to GitLab Premium or Ultimate](https://about.gitlab.com/pricing/), which include higher limits and features to enable growing teams to ship faster without sacrificing on quality.
- [Talk to an expert](https://page.gitlab.com/usage_limits_help.html) for more information about your options.

### View project fork storage usage

A cost factor is applied to the storage consumed by project forks so that forks consume less namespace storage than their actual size.

To view the amount of namespace storage the fork has used:

1. On the left sidebar, select **Search or go to** and find your project or group.
1. On the left sidebar, select **Settings > Usage Quotas**.
1. Select the **Storage** tab. The **Total** column displays the amount of namespace storage used by the fork as a portion of the actual size of the fork on disk.

The cost factor applies to the project repository, LFS objects, job artifacts, packages, snippets, and the wiki.

The cost factor does not apply to private forks in namespaces on the Free plan.
