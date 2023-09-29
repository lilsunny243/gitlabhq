---
stage: Create
group: Code Review
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
type: index, reference
---

# Merge request commits **(FREE ALL)**

Each merge request has a history of the commits made to the source branch
after the merge request was created.

These commits are displayed on the merge request's **Commits** tab.
From this tab, you can review commit messages and copy a commit's SHA when you need to
[cherry-pick changes](cherry_pick_changes.md).

## View commits in a merge request

To see the commits included in a merge request:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Code > Merge requests**, then select your merge request.
1. To show a list of the commits in the merge request, newest first, select **Commits** .
   To read more about the commit, select **Toggle commit description** (**{ellipsis_h}**)
   on any commit.
1. To view the changes in the commit, select the title of the commit link.
1. To view other commits in the merge request, either:

   - Select **Prev** or **Next**.
   - Use keyboard shortcuts: <kbd>X</kbd> (previous commit) and <kbd>C</kbd> (next commit).

If your merge request builds upon a previous merge request, you might
need to [include more commits for context](#show-commits-from-previous-merge-requests).

### Show commits from previous merge requests

> - [Enabled on GitLab.com](https://gitlab.com/gitlab-org/gitlab/-/issues/320757) in GitLab 14.8.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/320757) in GitLab 14.9. [Feature flag `context_commits`](https://gitlab.com/gitlab-org/gitlab/-/issues/320757) removed.

When you review a merge request, you might need information from previous commits
to help understand the commits you're reviewing. You might need more context
if another merge request:

- Changed files your current merge request doesn't modify, so those files aren't shown
  in your current merge request's diff.
- Changed files that you're modifying in your current merge request, and you need
  to see the progression of work.

To add previously merged commits to a merge request for more context:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Code > Merge requests**, then select your merge request.
1. Select **Commits**.
1. Scroll to the end of the list of commits, and select **Add previously merged commits**.
1. Select the commits that you want to add.
1. Select **Save changes**.

## Add a comment to a commit

WARNING:
Threads created this way are lost if the commit ID changes after a
force push.

To add discussion to a specific commit:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Code > Commits**.
1. Below the commits, in the **Comment** field, enter a comment.
1. Save your comment as either a standalone comment, or a thread:
   - To add a comment, select **Comment**.
   - To start a thread, select the down arrow (**{chevron-down}**), then select **Start thread**.

## View diffs between commits

To view the changes between previously merged commits:

1. On the left sidebar, select **Search or go to** and find your project.
1. Select **Code > Merge requests**, then select your merge request.
1. Select **Changes**.
1. By **Compare** (**{file-tree}**), select the commits to compare:

   ![Previously merged commits](img/previously_merged_commits_v16_0.png)

If you selected to add previously merged commits for context, those commits are
also shown in the list.
