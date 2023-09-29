---
stage: Verify
group: Runner
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# SaaS runners on macOS **(PREMIUM SAAS BETA)**

SaaS runners on macOS are in [Beta](../../../policy/experiment-beta-support.md#beta) for open source programs and customers in Premium and Ultimate plans.

SaaS runners on macOS provide an on-demand macOS build environment integrated with
GitLab SaaS [CI/CD](../../../ci/index.md).
Use these runners to build, test, and deploy apps for the Apple ecosystem (macOS, iOS, watchOS, tvOS). You can take advantage
of all the capabilities of the GitLab single DevOps platform and not have to manage or operate a
build environment. Our [Mobile DevOps solution](../../../ci/mobile_devops.md#ios-build-environments) provides features, documentation, and guidance on building and deploying mobile applications for iOS.

We want to keep iterating to get SaaS runners on macOS
[generally available](../../../policy/experiment-beta-support.md#generally-available-ga).
You can follow our work towards this goal in the
[related epic](https://gitlab.com/groups/gitlab-org/-/epics/8267).

## Machine types available for macOS

GitLab SaaS provides macOS build machines on Apple silicon (M1) chips.
Intel x86-64 runners were deprecated in favor of Apple silicon. To build for an x86-64 target, use Rosetta 2 to emulate an Intel x86-64 build environment.

| Runner Tag             | vCPUS | Memory | Storage |
| ---------------------- | ----- | ------ | ------- |
| `saas-macos-medium-m1` | 4     | 8 GB   | 25 GB   |

## Supported macOS images

In comparison to our SaaS runners on Linux, where you can run any Docker image,
GitLab SaaS provides a set of VM images for macOS.

You can execute your build in one of the following images, which you specify
in your `.gitlab-ci.yml` file.

Each image runs a specific version of macOS and Xcode.

| VM image                   | Status |
|----------------------------|--------|
| `macos-12-xcode-13`        | `GA`   |
| `macos-12-xcode-14`        | `GA`   |
| `macos-13-xcode-14`        | `Beta` |

## Image update policy for macOS

macOS and Xcode follow a yearly release cadence, during which GitLab increments its versions synchronously. GitLab typically supports multiple versions of preinstalled tools. For more information, see
a [full list of preinstalled software](https://gitlab.com/gitlab-org/ci-cd/shared-runners/images/job-images/-/tree/main/toolchain).

GitLab provides `stable` and `latest` macOS images that follow different update patterns:

- **Stable image:** The `stable` images and installed components are updated every release. Images without the `:latest` prefix are considered stable images.
- **Latest image:** The `latest` images are typically updated on a weekly cadence and use a `:latest` prefix in the image name. Using the `latest` image results in more regularly updated components and shorter update times for Homebrew or asdf. The `latest` images are used to test software components before releasing the components to the `stable` images.
By definition, the `latest` images are always Beta.
A `latest` image is not available.

### Image release process

When Apple releases a new macOS version, GitLab releases both `stable` and `latest` images based on the OS in the next release. Both images are Beta.

With the release of the first patch to macOS, the `stable` image becomes Generally Available (GA).
As only two GA images are supported at a time, the prior OS version becomes deprecated and is deleted after three months in accordance with the [supported image lifecycle](../index.md#supported-image-lifecycle).

## Example `.gitlab-ci.yml` file

The following sample `.gitlab-ci.yml` file shows how to start using the SaaS runners on macOS:

```yaml
.macos_saas_runners:
  tags:
    - saas-macos-medium-m1
  image: macos-12-xcode-14
  before_script:
    - echo "started by ${GITLAB_USER_NAME}"

build:
  extends:
    - .macos_saas_runners
  stage: build
  script:
    - echo "running scripts in the build job"

test:
  extends:
    - .macos_saas_runners
  stage: test
  script:
    - echo "running scripts in the test job"
```

## Code signing iOS Projects with fastlane

Before you can integrate GitLab with Apple services, install to a device, or deploy to the Apple App Store, you must [code sign](https://developer.apple.com/support/code-signing/) your application.

Included in each runner on macOS VM image is [fastlane](https://fastlane.tools/),
an open-source solution aimed at simplifying mobile app deployment.

For information about how to set up code signing for your application, see the instructions in the [Mobile DevOps documentation](../../../ci/mobile_devops.md#code-sign-ios-projects-with-fastlane).

Related topics:

- [Apple Developer Support - Code Signing](https://developer.apple.com/support/code-signing/)
- [Code Signing Best Practice Guide](https://codesigning.guide/)
- [fastlane authentication with Apple Services guide](https://docs.fastlane.tools/getting-started/ios/authentication/)

## Optimizing Homebrew

By default, Homebrew checks for updates at the start of any operation. Homebrew has a
release cycle that may be more frequent than the GitLab macOS image release cycle. This
difference in release cycles may cause steps that call `brew` to take extra time to complete
while Homebrew makes updates.

To reduce build time due to unintended Homebrew updates, set the `HOMEBREW_NO_AUTO_UPDATE` variable in `.gitlab-ci.yml`:

```yaml
variables:
  HOMEBREW_NO_AUTO_UPDATE: 1
```

## Optimizing Cocoapods

If you use Cocoapods in a project, you should consider the following optimizations to improve CI performance.

**Cocoapods CDN**

You can use content delivery network (CDN) access to download packages from the CDN instead of having to clone an entire
project repository. CDN access is available in Cocoapods 1.8 or later and is supported by all GitLab SaaS runners on macOS.

To enable CDN access, ensure your Podfile starts with:

```ruby
source 'https://cdn.cocoapods.org/'
```

**Use GitLab caching**

Use caching in Cocoapods packages in GitLab to only run `pod install`
when pods change, which can improve build performance.

To [configure caching](../../../ci/caching/index.md) for your project:

1. Add the `cache` configuration to your `.gitlab-ci.yml` file:

    ```yaml
    cache:
      key:
        files:
         - Podfile.lock
    paths:
      - Pods
    ```

1. Add the [`cocoapods-check`](https://guides.cocoapods.org/plugins/optimising-ci-times.html) plugin to your project.
1. Update the job script to check for installed dependencies before it calls `pod install`:

    ```shell
    bundle exec pod check || bundle exec pod install
    ```

**Include pods in source control**

You can also [include the pods directory in source control](https://guides.cocoapods.org/using/using-cocoapods.html#should-i-check-the-pods-directory-into-source-control). This eliminates the need to install pods as part of the CI job,
but it does increase the overall size of your project's repository.

## Known issues and usage constraints

- If the VM image does not include the specific software version you need for your job, the required software must be fetched and installed. This causes an increase in job execution time.
- It is not possible to bring your own OS image.
- The keychain for user `gitlab` is not publicly available. You must create a keychain instead.
