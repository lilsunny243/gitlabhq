---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
type: reference
---

# Protected paths **(FREE SELF)**

Rate limiting is a technique that improves the security and durability of a web
application. For more details, see [Rate limits](../../security/rate_limits.md).

You can rate limit (protect) specified paths. For these paths, GitLab responds with HTTP status
code `429` to POST requests that exceed 10 requests per minute per IP address and GET requests that exceed 10 requests per minute per IP address at protected paths.

For example, the following are limited to a maximum 10 requests per minute:

- User sign-in
- User sign-up (if enabled)
- User password reset

After 10 requests, the client must wait 60 seconds before it can try again.

See also:

- List of paths [protected by default](../instance_limits.md#by-protected-path).
- [User and IP rate limits](user_and_ip_rate_limits.md#response-headers)
  for the headers returned to blocked requests.

## Configure protected paths

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/31246) in GitLab 12.4.

Throttling of protected paths is enabled by default and can be disabled or
customized.

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. Select **Settings > Network**.
1. Expand **Protected paths**.

Requests that exceed the rate limit are logged in `auth.log`.
