---
stage: Govern
group: Compliance
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Audit event streaming **(ULTIMATE ALL)**

> - UI [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/336411) in GitLab 14.9.
> - [Subgroup events recording](https://gitlab.com/gitlab-org/gitlab/-/issues/366878) fixed in GitLab 15.2.
> - Custom HTTP headers UI [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/361630) in GitLab 15.2 [with a flag](../feature_flags.md) named `custom_headers_streaming_audit_events_ui`. Disabled by default.
> - Custom HTTP headers UI [made generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/365259) in GitLab 15.3. [Feature flag `custom_headers_streaming_audit_events_ui`](https://gitlab.com/gitlab-org/gitlab/-/issues/365259) removed.
> - [Improved user experience](https://gitlab.com/gitlab-org/gitlab/-/issues/367963) in GitLab 15.3.
> - [HTTP destination **Name*** field](https://gitlab.com/gitlab-org/gitlab/-/issues/411357) added in GitLab 16.3.

Users can set a streaming destination for a top-level group or instance to receive all audit events about the group,
subgroups, and projects, as structured JSON.

Top-level group owners and instance administrators can manage their audit logs in third-party systems. Any service that
can receive structured JSON data can be used as the streaming destination.

Each streaming destination can have up to 20 custom HTTP headers included with each streamed event.

GitLab can stream a single event more than once to the same destination. Use the `id` key in the payload to deduplicate
incoming data.

WARNING:
Streaming destinations receive **all** audit event data, which could include sensitive information. Make sure you trust
the streaming destination.

## Top-level group streaming destinations

Manage streaming destinations for top-level groups.

### HTTP destinations

Manage HTTP streaming destinations for top-level groups.

#### Add a new HTTP destination

Add a new HTTP streaming destination to a top-level group.

Prerequisites:

- Owner role for a top-level group.

To add streaming destinations to a top-level group:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select **Streams** tab.
1. Select **Add streaming destination** and select **HTTP endpoint** to show the section for adding destinations.
1. In the **Name** and **Destination URL** fields, add a destination name and URL.
1. Optional. Locate the **Custom HTTP headers** table.
1. Ignore the **Active** checkbox because it isn't functional. To track progress on adding functionality to the
   **Active** checkbox, see [issue 367509](https://gitlab.com/gitlab-org/gitlab/-/issues/367509).
1. Select **Add header** to create a new name and value pair. Enter as many name and value pairs as required. You can add up to
   20 headers per streaming destination.
1. After all headers have been filled out, select **Add** to add the new streaming destination.

#### List HTTP destinations

Prerequisites:

- Owner role for a group.

To list the streaming destinations for a top-level group:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select **Streams** tab.
1. Select the stream to expand it and see all the custom HTTP headers.

#### Update an HTTP destination

Prerequisites:

- Owner role for a group.

To update a streaming destination's name:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select **Streams** tab.
1. Select the stream to expand.
1. In the **Name** fields, add a destination name to update.
1. Select **Save** to update the streaming destination.

To update a streaming destination's custom HTTP headers:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select **Streams** tab.
1. Select the stream to expand.
1. Locate the **Custom HTTP headers** table.
1. Locate the header that you wish to update.
1. Ignore the **Active** checkbox because it isn't functional. To track progress on adding functionality to the
   **Active** checkbox, see [issue 367509](https://gitlab.com/gitlab-org/gitlab/-/issues/367509).
1. Select **Add header** to create a new name and value pair. Enter as many name and value pairs as required. You can add up to
   20 headers per streaming destination.
1. Select **Save** to update the streaming destination.

#### Delete an HTTP destination

Delete streaming destinations for a top-level group. When the last destination is successfully deleted, streaming is
disabled for the top-level group.

Prerequisites:

- Owner role for a group.

To delete a streaming destination:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select the **Streams** tab.
1. Select the stream to expand.
1. Select **Delete destination**.
1. Confirm by selecting **Delete destination** in the dialog.

To delete only the custom HTTP headers for a streaming destination:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select the **Streams** tab.
1. Select the stream to expand.
1. Locate the **Custom HTTP headers** table.
1. Locate the header that you wish to remove.
1. To the right of the header, select **Delete** (**{remove}**).
1. Select **Save** to update the streaming destination.

#### Verify event authenticity

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/360814) in GitLab 15.2.

Each streaming destination has a unique verification token (`verificationToken`) that can be used to verify the authenticity of the event. This
token is either specified by the Owner or generated automatically when the event destination is created and cannot be changed.

Each streamed event contains the verification token in the `X-Gitlab-Event-Streaming-Token` HTTP header that can be verified against
the destination's value when listing streaming destinations.

Prerequisites:

- Owner role for a group.

To list streaming destinations and see the verification tokens:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select the **Streams**.
1. Select the stream to expand.
1. Locate the **Verification token** input.

#### Update event filters

> Event type filtering in the UI with a defined list of audit event types [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/413581) in GitLab 16.1.

When this feature is enabled for a group, you can permit users to filter streamed audit events per destination.
If the feature is enabled with no filters, the destination receives all audit events.

A streaming destination that has an event type filter set has a **filtered** (**{filter}**) label.

To update a streaming destination's event filters:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select the **Streams** tab.
1. Select the stream to expand.
1. Locate the **Filter by audit event type** dropdown list.
1. Select the dropdown list and select or clear the required event types.
1. Select **Save** to update the event filters.

#### Override default content type header

By default, streaming destinations use a `content-type` header of `application/x-www-form-urlencoded`. However, you
might want to set the `content-type` header to something else. For example ,`application/json`.

To override the `content-type` header default value for a top-level group streaming destination, use either:

- The [GitLab UI](#update-an-http-destination).
- The [GraphQL API](graphql_api.md#update-streaming-destinations).

### Google Cloud Logging destinations

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/124384) in GitLab 16.2.

Manage Google Cloud Logging destinations for top-level groups.

#### Prerequisites

Before setting up Google Cloud Logging streaming audit events, you must:

1. Create a service account for Google Cloud with the appropriate credentials and permissions. This account is used to configure audit log streaming authentication.
   For more information, see [Creating and managing service accounts in the Google Cloud documentation](https://cloud.google.com/iam/docs/service-accounts-create#creating).
1. Enable the **Logs Writer** role for the service account to enable logging on Google Cloud. For more information, see [Access control with IAM](https://cloud.google.com/logging/docs/access-control#logging.logWriter).
1. Create a JSON key for the service account. For more information, see [Creating a service account key](https://cloud.google.com/iam/docs/keys-create-delete#creating).

#### Add a new Google Cloud Logging destination

Prerequisites:

- Owner role for a top-level group.

To add Google Cloud Logging streaming destinations to a top-level group:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select **Streams** tab.
1. Select **Add streaming destination** and select **Google Cloud Logging** to show the section for adding destinations.
1. Enter the Google project ID, Google client email, log ID, and Google private key to add.
1. Select **Add** to add the new streaming destination.

#### List Google Cloud Logging destinations

Prerequisites:

- Owner role for a top-level group.

To list Google Cloud Logging streaming destinations for a top-level group:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select **Streams** tab.
1. Select the Google Cloud Logging stream to expand and see all the fields.

#### Update a Google Cloud Logging destination

> Button to add private key [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/419675) in GitLab 16.3.

Prerequisites:

- Owner role for a top-level group.

To update Google Cloud Logging streaming destinations to a top-level group:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select **Streams** tab.
1. Select the Google Cloud Logging stream to expand.
1. Enter the Google project ID, Google client email, and log ID to update.
1. Select **Add a new private key** and enter a Google private key to update the private key.
1. Select **Save** to update the streaming destination.

#### Delete a Google Cloud Logging streaming destination

Prerequisites:

- Owner role for a top-level group.

To delete Google Cloud Logging streaming destinations to a top-level group:

1. On the left sidebar, select **Search or go to** and find your group.
1. Select **Secure > Audit events**.
1. On the main area, select the **Streams** tab.
1. Select the Google Cloud Logging stream to expand.
1. Select **Delete destination**.
1. Confirm by selecting **Delete destination** in the dialog.

## Instance streaming destinations **(ULTIMATE SELF)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/398107) in GitLab 16.1 [with a flag](../feature_flags.md) named `ff_external_audit_events`. Disabled by default.
> - [Feature flag `ff_external_audit_events`](https://gitlab.com/gitlab-org/gitlab/-/issues/393772) enabled by default in GitLab 16.2.
> - Instance streaming destinations [made generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/393772) in GitLab 16.4. [Feature flag `ff_external_audit_events`](https://gitlab.com/gitlab-org/gitlab/-/issues/417708) removed.

Manage HTTP streaming destinations for an entire instance.

### Add a new HTTP destination

Add a new HTTP streaming destination to an instance.

Prerequisites:

- Administrator access on the instance.

To add a streaming destination for an instance:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select **Streams** tab.
1. Select **Add streaming destination** and select **HTTP endpoint** to show the section for adding destinations.
1. In the **Name** and **Destination URL** fields, add a destination name and URL.
1. Optional. To add custom HTTP headers, select **Add header** to create a new name and value pair, and input their values. Repeat this step for as many name and value pairs are required. You can add up to 20 headers per streaming destination.
1. Ignore the **Active** checkbox because it isn't functional. To track progress on adding functionality to the
   **Active** checkbox, see [issue 367509](https://gitlab.com/gitlab-org/gitlab/-/issues/367509).
1. Select **Add header** to create a new name and value pair. Repeat this step for as many name and value pairs are required. You can add up to
   20 headers per streaming destination.
1. After all headers have been filled out, select **Add** to add the new streaming destination.

### List HTTP destinations

Prerequisites:

- Administrator access on the instance.

To list the streaming destinations for an instance:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select **Streams** tab.
1. Select the stream to expand it and see all the custom HTTP headers.

### Update an HTTP destination

Prerequisites:

- Administrator access on the instance.

To update a instance streaming destination's name:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select **Streams** tab.
1. Select the stream to expand.
1. In the **Name** fields, add a destination name to update.
1. Select **Save** to update the streaming destination.

To update a instance streaming destination's custom HTTP headers:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select **Streams** tab.
1. Select the stream to expand.
1. Locate the **Custom HTTP headers** table.
1. Locate the header that you wish to update.
1. Ignore the **Active** checkbox because it isn't functional. To track progress on adding functionality to the
   **Active** checkbox, see [issue 367509](https://gitlab.com/gitlab-org/gitlab/-/issues/367509).
1. Select **Add header** to create a new name and value pair. Enter as many name and value pairs as required. You can add up to
   20 headers per streaming destination.
1. Select **Save** to update the streaming destination.

### Delete an HTTP destination

Delete streaming destinations for an entire instance. When the last destination is successfully deleted, streaming is
disabled for the instance.

Prerequisites:

- Administrator access on the instance.

To delete the streaming destinations for an instance:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select the **Streams** tab.
1. Select the stream to expand.
1. Select **Delete destination**.
1. Confirm by selecting **Delete destination** in the dialog.

To delete only the custom HTTP headers for a streaming destination:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select the **Streams** tab.
1. To the right of the item, **Edit** (**{pencil}**).
1. Locate the **Custom HTTP headers** table.
1. Locate the header that you wish to remove.
1. To the right of the header, select **Delete** (**{remove}**).
1. Select **Save** to update the streaming destination.

### Verify event authenticity

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/398107) in GitLab 16.1 [with a flag](../feature_flags.md) named `ff_external_audit_events`. Disabled by default.
> - [Feature flag `ff_external_audit_events`](https://gitlab.com/gitlab-org/gitlab/-/issues/393772) enabled by default in GitLab 16.2.
> - Instance streaming destinations [made generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/393772) in GitLab 16.4. [Feature flag `ff_external_audit_events`](https://gitlab.com/gitlab-org/gitlab/-/issues/417708) removed.

Each streaming destination has a unique verification token (`verificationToken`) that can be used to verify the authenticity of the event. This
token is either specified by the Owner or generated automatically when the event destination is created and cannot be changed.

Each streamed event contains the verification token in the `X-Gitlab-Event-Streaming-Token` HTTP header that can be verified against
the destination's value when listing streaming destinations.

Prerequisites:

- Administrator access on the instance.

To list streaming destinations for an instance and see the verification tokens:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select the **Streams** tab.
1. View the verification token on the right side of each item.

### Update event filters

> Event type filtering in the UI with a defined list of audit event types [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/415013) in GitLab 16.3.

When this feature is enabled, you can permit users to filter streamed audit events per destination.
If the feature is enabled with no filters, the destination receives all audit events.

A streaming destination that has an event type filter set has a **filtered** (**{filter}**) label.

To update a streaming destination's event filters:

1. On the left sidebar, select **Search or go to**.
1. Select **Admin Area**.
1. On the left sidebar, select **Monitoring > Audit Events**.
1. On the main area, select the **Streams** tab.
1. Select the stream to expand.
1. Locate the **Filter by audit event type** dropdown list.
1. Select the dropdown list and select or clear the required event types.
1. Select **Save** to update the event filters.

### Override default content type header

By default, streaming destinations use a `content-type` header of `application/x-www-form-urlencoded`. However, you
might want to set the `content-type` header to something else. For example ,`application/json`.

To override the `content-type` header default value for an instance streaming destination, use either:

- The [GitLab UI](#update-an-http-destination-1).
- The [GraphQL API](graphql_api.md#update-streaming-destinations).

## Payload schema

> Documentation for an audit event streaming schema was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/358149) in GitLab 15.3.

Streamed audit events have a predictable schema in the body of the response.

| Field            | Description                                                | Notes                                                                             |
|------------------|------------------------------------------------------------|-----------------------------------------------------------------------------------|
| `author_id`      | User ID of the user who triggered the event                |                                                                                   |
| `author_name`    | Human-readable name of the author that triggered the event | Helpful when the author no longer exists                                          |
| `created_at`     | Timestamp when event was triggered                         |                                                                                   |
| `details`        | JSON object containing additional metadata                 | Has no defined schema but often contains additional information about an event    |
| `entity_id`      | ID of the audit event's entity                             |                                                                                   |
| `entity_path`    | Full path of the entity affected by the auditable event    |                                                                                   |
| `entity_type`    | String representation of the type of entity                | Acceptable values include `User`, `Group`, and `Key`. This list is not exhaustive |
| `event_type`     | String representation of the type of audit event           |                                                                                   |
| `id`             | Unique identifier for the audit event                      | Can be used for deduplication if required                                         |
| `ip_address`     | IP address of the host used to trigger the event           |                                                                                   |
| `target_details` | Additional details about the target                        |                                                                                   |
| `target_id`      | ID of the audit event's target                             |                                                                                   |
| `target_type`    | String representation of the target's type                 |                                                                                   |

### JSON payload schema

```json
{
  "properties": {
    "id": {
      "type": "string"
    },
    "author_id": {
      "type": "integer"
    },
    "author_name": {
      "type": "string"
    },
    "details": {},
    "ip_address": {
      "type": "string"
    },
    "entity_id": {
      "type": "integer"
    },
    "entity_path": {
      "type": "string"
    },
    "entity_type": {
      "type": "string"
    },
    "event_type": {
      "type": "string"
    },
    "target_id": {
      "type": "integer"
    },
    "target_type": {
      "type": "string"
    },
    "target_details": {
      "type": "string"
    },
  },
  "type": "object"
}
```
