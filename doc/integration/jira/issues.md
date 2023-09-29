---
stage: Manage
group: Import and Integrate
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Jira issue management **(FREE ALL)**

You can [manage Jira issues directly in GitLab](configure.md).
You can then refer to Jira issues by ID in GitLab commits and merge requests.
The Jira issue IDs must be in uppercase.

## Cross-reference GitLab activity and Jira issues

With this integration, you can cross-reference Jira issues while you work in
GitLab issues, merge requests, and Git.
When you mention a Jira issue in a GitLab issue, merge request, comment, or commit:

- GitLab links to the Jira issue from the mention in GitLab.
- GitLab adds a formatted comment to the Jira issue that links back to the issue, merge request, or commit in GitLab.

For example, when this commit refers to a `GIT-1` Jira issue:

```shell
git commit -m "GIT-1 this is a test commit"
```

GitLab adds to that Jira issue:

- A reference in the **Web links** section.
- A comment in the **Activity** section that follows this format:

  ```plaintext
  USER mentioned this issue in RESOURCE_NAME of [PROJECT_NAME|COMMENTLINK]:
  ENTITY_TITLE
  ```

  - `USER`: Name of the user who has mentioned the Jira issue with a link to their GitLab user profile.
  - `RESOURCE_NAME`: Type of resource (for example, a GitLab commit, issue, or merge request) that has referenced the Jira issue.
  - `PROJECT_NAME`: GitLab project name.
  - `COMMENTLINK`: Link to where the Jira issue is mentioned.
  - `ENTITY_TITLE`: Title of the GitLab commit (first line), issue, or merge request.

Only a single cross-reference appears in Jira per GitLab issue, merge request, or commit.
For example, multiple comments on a GitLab merge request that reference a Jira issue
create only a single cross-reference back to that merge request in Jira.

You can [disable comments](#disable-comments-on-jira-issues) on issues.

### Require associated Jira issue for merge requests to be merged **(ULTIMATE ALL)**

With this integration, you can prevent merge requests from being merged if they do not refer to a Jira issue.
To enable this feature:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Settings > Merge requests**.
1. In the **Merge checks** section, select **Require an associated issue from Jira**.
1. Select **Save**.

After you enable this feature, a merge request that doesn't reference an associated
Jira issue can't be merged. The merge request displays the message
**To merge, a Jira issue key must be mentioned in the title or description.**

## Customize Jira issue matching in GitLab

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/112826) in GitLab 15.10.

You can configure custom rules for how GitLab matches Jira issue keys by defining:

- [A regex pattern](#use-regular-expression)
- [A prefix](#use-a-prefix)

When you don't configure custom rules, the [default behavior](https://gitlab.com/gitlab-org/gitlab/-/blob/710d83af298d8896f2b940faf48a46d2feb4cbaf/lib/gitlab/regex.rb#L552) is used. For more information, see the [RE2 wiki](https://github.com/google/re2/wiki/Syntax).

### Use regular expression

To define a regex pattern for Jira issue keys:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Settings > Integrations**.
1. Select **Jira**.
1. Go to the **Jira issue matching** section.
1. In the **Jira issue regex** text box, enter a regex pattern.
1. Select **Save changes**.

For more information, see the [Atlassian documentation](https://confluence.atlassian.com/adminjiraserver073/changing-the-project-key-format-861253229.html).

### Use a prefix

You can define a prefix for GitLab to match Jira issue keys. For example, if your Jira issue ID is `ALPHA-1`
and you've set a `JIRA#` prefix, GitLab matches `JIRA#ALPHA-1` rather than `ALPHA-1`.

To define a prefix for Jira issue keys:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Settings > Integrations**.
1. Select **Jira**.
1. Go to the **Jira issue matching** section.
1. In the **Jira issue prefix** text box, enter a prefix.
1. Select **Save changes**.

## Close Jira issues in GitLab

If you have configured GitLab transition IDs, you can close a Jira issue directly
from GitLab. Use a trigger word followed by a Jira issue ID in a commit or merge request.
When you push a commit containing a trigger word and Jira issue ID, GitLab:

1. Comments in the mentioned Jira issue.
1. Closes the Jira issue. If the Jira issue has a resolution, it isn't transitioned.

For example, use any of these trigger words to close the Jira issue `PROJECT-1`:

- `Resolves PROJECT-1`
- `Closes PROJECT-1`
- `Fixes PROJECT-1`

The commit or merge request must target your project's [default branch](../../user/project/repository/branches/default.md).
You can change your project's default branch in [project settings](../../user/project/settings/index.md).

### Use case for closing issues

Consider this example:

1. A user creates Jira issue `PROJECT-7` to request a new feature.
1. You create a merge request in GitLab to build the requested feature.
1. In the merge request, you add the issue closing trigger `Closes PROJECT-7`.
1. When the merge request is merged:
   - GitLab closes the Jira issue for you.
   - GitLab adds a formatted comment to Jira, linking back to the commit that
     resolved the issue. You can [disable comments](#disable-comments-on-jira-issues).

## View Jira issues **(PREMIUM ALL)**

You can view and search issues from a selected Jira project directly in GitLab,
provided your GitLab administrator [has configured the integration](configure.md#configure-the-integration).

To view Jira issues:

1. On the left sidebar, select **Search or go to** and find your project.
1. On the left sidebar, select **Plan > Jira issues**.

The issues are sorted by **Created date** by default, with the most recently created issues listed at the top.

- To display the most recently updated issues first, select **Updated date**.
- You can [search and filter the issue list](#search-and-filter-the-issue-list).
- You can [select an issue from the list to view the issue in GitLab](https://gitlab.com/gitlab-org/gitlab/-/issues/299832).

Issues are grouped into tabs based on their
[Jira status](https://confluence.atlassian.com/adminjiraserver070/defining-status-field-values-749382903.html):

- **Open** tab: All issues with a Jira status in any category other than Done.
- **Closed** tab: All issues with a Jira status categorized as Done.
- **All** tab: All issues of any status.

### Search and filter the issue list **(PREMIUM ALL)**

To refine the list of issues, use the search bar to search for any text
contained in an issue summary (title) or description. Use any combination
of these filters:

- To filter issues by `labels`, specify one or more labels as part of the `labels[]`
  parameter in the URL. When using multiple labels, only issues that contain all specified
  labels are listed: `/-/integrations/jira/issues?labels[]=backend&labels[]=feature&labels[]=QA`
- To filter issues by `status`, specify the `status` parameter in the URL:
  `/-/integrations/jira/issues?status=In Progress`
- To filter issues by `reporter`, specify a reporter's Jira display name for the
  `author_username` parameter in the URL: `/-/integrations/jira/issues?author_username=John Smith`
- To filter issues by `assignee`, specify their Jira display name for the
  `assignee_username` parameter in the URL: `/-/integrations/jira/issues?assignee_username=John Smith`

Enhancements to use these filters through the user interface
[are planned](https://gitlab.com/groups/gitlab-org/-/epics/3622).

## Automatic issue transitions

When you configure automatic issue transitions, you can transition a referenced
Jira issue to the next available status with a category of **Done**. To configure
this setting:

1. Refer to the [Configure GitLab](configure.md) instructions.
1. Select the **Enable Jira transitions** checkbox.
1. Select the **Move to Done** option.

## Custom issue transitions

For advanced workflows, you can specify custom Jira transition IDs:

1. Use the method based on your Jira subscription status:
   - *(For users of Jira Cloud)* Obtain your transition IDs by editing a workflow
     in the **Text** view. The transition IDs display in the **Transitions** column.
   - *(For users of Jira Server)* Obtain your transition IDs in one of these ways:
     - By using the API, with a request like `https://yourcompany.atlassian.net/rest/api/2/issue/ISSUE-123/transitions`,
       using an issue that is in the appropriate "open" state.
     - By mousing over the link for the transition you want and looking for the
       **action** parameter in the URL.
   The transition ID may vary between workflows (for example, a bug instead of a
   story), even if the status you're changing to is the same.
1. Refer to the [Configure GitLab](configure.md) instructions.
1. Select the **Enable Jira transitions** setting.
1. Select the **Custom transitions** option.
1. Enter your transition IDs in the text field. If you insert multiple transition IDs
   (separated by `,` or `;`), the issue is moved to each state, one after another, in the
   order you specify. If a transition fails, the sequence is aborted.

## Disable comments on Jira issues

GitLab can cross-link source commits or merge requests with Jira issues without
adding a comment to the Jira issue:

1. Refer to the [Configure GitLab](configure.md) instructions.
1. Clear the **Enable comments** checkbox.

## Related topics

- [Create a Jira issue for a vulnerability](../../user/application_security/vulnerabilities/index.md#create-a-jira-issue-for-a-vulnerability)
