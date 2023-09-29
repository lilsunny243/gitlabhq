---
stage: Fulfillment
group: Purchase
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# The Customers Portal

For some management tasks for your subscription and account, such as purchasing additional seats or storage and viewing invoices, you use the Customers Portal. See the following pages for specific instructions on managing your subscription:

- [GitLab SaaS subscription](gitlab_com/index.md)
- [Self-managed subscription](self_managed/index.md)

If you made your purchase through an authorized reseller, you must contact them directly to make changes to your subscription (your subscriptions are read-only).

## Sign in to Customers Portal

You can sign in to Customers Portal either with your GitLab.com account or your email and password (if you have not yet [linked your Customers Portal account to your GitLab.com account](#link-a-gitlabcom-account)).

NOTE:
If you registered for Customers Portal with your GitLab.com account, sign in with this account.

To sign in to Customers Portal using your GitLab.com account:

1. Navigate to [Customers Portal](https://customers.gitlab.com/customers/sign_in).
1. Select **Continue with your GitLab.com account**.

To sign in to Customers Portal with your email and to receive a one-time sign-in link:

1. Navigate to [Customers Portal](https://customers.gitlab.com/customers/sign_in).
1. Select **Sign in with your email**.
1. Provide the **Email** for your Customers Portal account. You will receive
   an email with a one-time, sign-in link for your Customers Portal account.
1. In the email you received, select **Sign in**.

NOTE:
The one-time sign-in link expires in 24 hours and can only be used once.

## Confirm Customers Portal email address

The first time you sign in to the Customers Portal with a one-time sign-in link,
you must confirm your email address to maintain access to the Customers Portal. If you sign in
to the Customers Portal through GitLab.com, you don't need to confirm your email address.

You must also confirm any updates to the account email address. You will receive
an automatic email with instructions about how to confirm, which you can [resend](https://customers.gitlab.com/customers/confirmation/new)
if required.

## Change account owner information

The account owner's personal details are used on invoices. The account owner's email address is used for the [Customers Portal legacy sign-in](#sign-in-to-customers-portal) and license-related email.

To change account owner information, including name, billing address, and email address:

1. Sign in to the [Customers Portal](https://customers.gitlab.com/customers/sign_in).
1. Select **My account > Account details**.
1. Expand the **Personal details** section.
1. Edit the personal details.
1. Select **Save changes**.

If you want to transfer ownership of the Customers Portal account
to another person, after you enter that person's personal details, you must also:

- [Change the linked GitLab.com account](#change-the-linked-account), if you have one linked.

## Change your company details

To change your company details, including company name and VAT number:

1. Sign in to the [Customers Portal](https://customers.gitlab.com/customers/sign_in).
1. Select **My account > Account details**.
1. Expand the **Company details** section.
1. Edit the company details.
1. Select **Save changes**.

## Change your payment method

Purchases in the Customers Portal require a credit card on record as a payment method. You can add
multiple credit cards to your account, so that purchases for different products are charged to the
correct card.

If you would like to use an alternative method to pay, please
[contact our Sales team](https://about.gitlab.com/sales/).

To change your payment method:

1. Sign in to the [Customers Portal](https://customers.gitlab.com/customers/sign_in).
1. Select **My account > Payment methods**.
1. **Edit** an existing payment method's information or **Add new payment method**.
1. Select **Save Changes**.

### Set a default payment method

Automatic renewal of a subscription is charged to your default payment method. To mark a payment
method as the default:

1. Sign in to the [Customers Portal](https://customers.gitlab.com/customers/sign_in).
1. Select **My account > Payment methods**.
1. **Edit** the selected payment method and check the **Make default payment method** checkbox.
1. Select **Save Changes**.

## Link a GitLab.com account

Follow this guideline if you have a legacy Customers Portal account and use an email and password to log in.

To link a GitLab.com account to your Customers Portal account:

1. Sign in to the [Customers Portal](https://customers.gitlab.com/customers/sign_in?legacy=true) using email and password.
1. On the Customers Portal page, select **My account > Account details**.
1. Under **Your GitLab.com account**, select **Link account**.
1. Sign in to the [GitLab.com](https://gitlab.com/users/sign_in) account you want to link to the Customers Portal account.

## Change the linked account

Customers are required to use their GitLab.com account to register for a new Customers Portal account.

If you have a legacy Customers Portal account that is not linked to a GitLab.com account, you may still [sign in](https://customers.gitlab.com/customers/sign_in?legacy=true) using an email and password. However, you should [create](https://gitlab.com/users/sign_up) and [link a GitLab.com account](#change-the-linked-account) to ensure continued access to the Customers Portal.

To change the GitLab.com account linked to your Customers Portal account:

1. Sign in to the [Customers Portal](https://customers.gitlab.com/customers/sign_in).
1. In a separate browser tab, go to [GitLab.com](https://gitlab.com/users/sign_in) and ensure you are not logged in.
1. On the Customers Portal page, select **My account > Account details**.
1. Under **Your GitLab.com account**, select **Change linked account**.
1. Sign in to the [GitLab.com](https://gitlab.com/users/sign_in) account you want to link to the Customers Portal account.

## Customers that purchased through a reseller

If you purchased a subscription through an authorized reseller (including GCP and AWS marketplaces), you have access to the Customers Portal to:

- View your subscription.
- Associate your subscription with the relevant group (GitLab SaaS) or download the license (GitLab self-managed).
- Manage contact information.

Other changes and requests must be done through the reseller, including:

- Changes to the subscription.
- Purchase of additional seats, Storage, or Compute.
- Requests for invoices, because those are issued by the reseller, not GitLab.

Resellers do not have access to the Customers Portal, or their customers' accounts.

After your subscription order is processed, you will receive several emails:

- A "Welcome to the Customers Portal" email, including instructions on how to log in.
- A purchase confirmation email with instructions on how to provision access.
