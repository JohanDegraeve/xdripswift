# Using GitHub Actions + FastLane to deploy to TestFlight

These instructions allow you to build your app without having access to a Mac.

* You can install your app on phones using TestFlight that are not connected to your computer
* You can send builds and updates to those you care for
* You can install your app on your phone using only the TestFlight app if a phone was lost or the app is accidentally deleted
* You do not need to worry about specific Xcode/Mac versions for a given iOS

## **Automatic Builds**
> 
> This new version of the browser build **defaults to** automatically updating and building a new version of xDrip4iOS according to this schedule:
> - automatically checks for updates weekly on Wednesdays and if updates are found, it will build a new version of the app
> - automatically builds once a month regardless of whether there are updates on the first of the month
> - with each scheduled run (weekly or monthly), a successful Build xDrip4iOS log appears - if the time is very short, it did not need to build - only the long actions (>20 minutes) built a new xDrip4iOS app
> 
> It also creates an alive branch, if you don't already have one. See [Why do I have an alive branch?](#why-do-i-have-an-alive-branch).
>
> The [**Optional**](#optional) section provides instructions to modify the default behavior if desired. 

This method for building without a Mac was ported from Loop. If you have used this method for Loop or one of the other DIY apps (Loop Caregiver, Loop Follow, Trio or iAPS), some of the steps can be re-used and the full set of instructions does not need to be repeated. This will be mentioned in relevant sections below.

> **Repeat Builders**
> - to enable automatic build, your `GH_PAT` token must have `workflow` scope
> - if you previously configured your `GH_PAT` without that scope, see [`GH_PAT` `workflow` permission](#gh_pat-workflow-permission)

## Introduction

The setup steps are somewhat involved, but nearly all are one time steps. Subsequent builds are trivial. Your app must be updated once every 90 days, but it's a simple click to make a new build and can be done from anywhere. The 90-day update is a TestFlight requirement, and with this version of xDrip4iOS, the build process (once you've successfully built once) is automated to update and build at least once a month.

There are more detailed instructions in LoopDocs for using GitHub for Browser Builds of Loop, including troubleshooting and build errors. Please refer to:

* [LoopDocs: Browser Overview](https://loopkit.github.io/loopdocs/browser/bb-overview/)
* [LoopDocs: Errors with Browser](https://loopkit.github.io/loopdocs/browser/bb-errors/)

Note that installing with TestFlight, (in the US), requires the Apple ID account holder to be 13 years or older. For younger users, an adult must log into Media & Purchase on the child's phone to install xDrip4iOS. More details on this can be found in [LoopDocs](https://loopkit.github.io/loopdocs/browser/phone-install/#testflight-for-a-child).

If you build multiple apps, it is strongly recommended that you configure a free *GitHub* organization and do all your building in the organization. This means you enter items one time for the organization (6 SECRETS required to build and 1 VARIABLE required to automatically update your certificates annually). Otherwise, those 6 SECRETS must be entered for every repository. Please refer to [LoopDocs: Create a *GitHub* Organization](https://loopkit.github.io/loopdocs/browser/secrets/#create-a-free-github-organization).

## Prerequisites

* A [GitHub account](https://github.com/signup). The free level comes with plenty of storage and free compute time to build xDrip4iOS, multiple times a day, if you wanted to.
* A paid [Apple Developer account](https://developer.apple.com).
* Some time. Set aside a couple of hours to perform the setup.

## Save 6 Secrets

You require 6 Secrets (alphanumeric items) to use the GitHub build method and if you use the GitHub method to build more than xDrip4iOS, e.g., Trio, LoopFollow or other apps, you will use the same 6 Secrets for each app you build with this method. Each secret is indentified below by `ALL_CAPITAL_LETTER_NAMES`.

* Four Secrets are from your Apple Account
* Two Secrets are from your GitHub account
* Be sure to save the 6 Secrets in a text file using a text editor
    - Do **NOT** use a smart editor, which might auto-correct and change case, because these Secrets are case sensitive

Refer to [LoopDocs: Make a Secrets Reference File](https://loopkit.github.io/loopdocs/browser/intro-summary/#make-a-secrets-reference-file) for a handy template to use when saving your Secrets.

## Generate App Store Connect API Key

This step is common for all GitHub Browser Builds; do this step only once. You will be saving 4 Secrets from your Apple Account in this step.

1. Sign in to the [Apple developer portal page](https://developer.apple.com/account/resources/certificates/list).
1. Copy the Team ID from the upper right of the screen. Record this as your `TEAMID`.
1. Go to the [App Store Connect](https://appstoreconnect.apple.com/access/api) interface, click the "Keys" tab, and create a new key with "Admin" access. Give it the name: "FastLane API Key".
1. Record the issuer id; this will be used for `FASTLANE_ISSUER_ID`.
1. Record the key id; this will be used for `FASTLANE_KEY_ID`.
1. Download the API key itself, and open it in a text editor. The contents of this file will be used for `FASTLANE_KEY`. Copy the full text, including the "-----BEGIN PRIVATE KEY-----" and "-----END PRIVATE KEY-----" lines.

## Create GitHub Personal Access Token

If you have previously built another app using the "browser build" method, you use the same personal access token (`GH_PAT`), so skip this step. If you use a free GitHub organization to build, you still use the same personal access token. This is created using your personal GitHub username.

Log into your GitHub account to create a personal access token; this is one of two GitHub secrets needed for your build.

1. Create a [new personal access token](https://github.com/settings/tokens/new):
    * Enter a name for your token, use "FastLane Access Token".
    * Change the Expiration selection to `No expiration`.
    * Select the `workflow` permission scope - this also selects `repo` scope.
    * Click "Generate token".
    * Copy the token and record it. It will be used below as `GH_PAT`.

## Make up a Password

This is the second one of two GitHub secrets needed for your build.

The first time you build with the GitHub Browser Build method for any DIY app, you will make up a password and record it as `MATCH_PASSWORD`. Note, if you later lose `MATCH_PASSWORD`, you will need to delete and make a new Match-Secrets repository (next step).

## Setup GitHub Match-Secrets Repository

A private Match-Secrets repository is automatically created under your GitHub username the first time you run a GitHub Action. Because it is a private repository - only you can see it. You will not take any direct actions with this repository; it needs to be there for GitHub to use as you progress through the steps.

## Setup GitHub xdripswift Repository

1. Fork https://github.com/JohanDegraeve/xdripswift into your GitHub username (using your organization if you have one).
1. If you are using an organization, do this step at the organization level, e.g., username-org. If you are not using an organization, do this step at the repository level, e.g., username/xdripswift:
    * Go to Settings -> Secrets and variables -> Actions and make sure the Secrets tab is open
1. For each of the following secrets, tap on "New repository secret", then add the name of the secret, along with the value you recorded for it:
    * `TEAMID`
    * `FASTLANE_ISSUER_ID`
    * `FASTLANE_KEY_ID`
    * `FASTLANE_KEY`
    * `GH_PAT`
    * `MATCH_PASSWORD`

> Note: At this time, the Variable `ENABLE_NUKE_CERTS` is not used by xdripswift. The annual Distribution Certificate renewnal is manual if this is the only Open Source app in the iOS OS AID ecosystem you are using. There is more information about this in [Annual Certificate Renewal](#annual-certificate-renewal).

## Validate repository secrets

This step validates most of your six Secrets and provides error messages if it detects an issue with one or more.

1. Click on the "Actions" tab of your xdripswift repository and enable workflows if needed
1. On the left side, select "1. Validate Secrets".
1. On the right side, click "Run Workflow", and tap the green `Run workflow` button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.
1. The workflow will check if the required secrets are added and that they are correctly formatted. If errors are detected, please check the run log for details.

There can be a delay after you start a workflow before the screen changes. Refresh your browser to see if it started. And if it seems to take a long time to finish - refresh your browser to see if it is done.

## Add Identifiers for xDrip4iOS App

1. Click on the "Actions" tab of your xdripswift repository.
1. On the left side, select "2. Add Identifiers".
1. On the right side, click "Run Workflow", and tap the green `Run workflow` button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

## Create Loop App Group

If you have already built xDrip4iOS via Xcode using this Apple ID, you can skip on to [Add App Groups to Bundle Identifiers](#add-app-groups-to-bundle-identifiers).

If you have already built Loop via Xcode using this Apple ID, you can skip on to [Create Trio App Group](#create-trio-app-group).

1. Go to [Register an App Group](https://developer.apple.com/account/resources/identifiers/applicationGroup/add/) on the apple developer site.
1. For Description, use "Loop App Group".
1. For Identifier, enter "group.com.TEAMID.loopkit.LoopGroup", subsituting your team id for `TEAMID`.
1. Click "Continue" and then "Register".

## Create Trio App Group

If you have already built Trio or xDrip4iOS via Xcode using this Apple ID, you can skip on to [Add App Groups to Bundle Identifiers](#add-app-groups-to-bundle-identifiers).

1. Go to [Register an App Group](https://developer.apple.com/account/resources/identifiers/applicationGroup/add/) on the apple developer site.
1. For Description, use "Trio App Group".
1. For Identifier, enter "group.org.nightscout.TEAMID.trio.trio-app-group", subsituting your team id for `TEAMID`.
1. Click "Continue" and then "Register".

## Add App Groups to Bundle Identifiers

Note 1 - If you previously built with Xcode, the `Names` listed below may be different, but the `Identifiers` will match. A table is provided below the steps to assist. The Add Identifier Action that you completed above generates 5 identifiers, and all 5 need to be modified as indicated in this step.

Note 2 - Depending on your build history, you may find some of the Identifiers are already configured - and you are just verifying the status; but in other cases, you will need to configure the Identifiers.

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) on the apple developer site.
1. For each of the following identifier names:
    * xdrip
    * xDrip Notification Context Extension
    * xDrip Watch App
    * xDrip Watch Complication Extension
    * xDrip Widget Extension
1. Click on the identifier's name.
1. On the "App Groups" capabilies, click on the "Configure" button.
1. Select the "Loop App Group". _(yes, "Loop App Group" is correct)_
1. For "xdripswift", also add the "Trio App Group" in addition to the "Loop App Group".
1. Click "Continue".
1. Click "Save".
1. Click "Confirm".
1. Remember to do this for each of the identifiers above.

#### Table with Name and Identifier for xDrip4iOS

| NAME | IDENTIFIER |
|-------|------------|
| xdrip | com.TEAMID.xdripswift |
| xDrip Notification Context Extension | com.TEAMID.xDripNotificationContextExtension |
| xDrip Watch App | com.TEAMID.xdripswift.watchkitapp |
| xDrip Watch Complication Extension | com.TEAMID.xdripswift.watchkitapp.xDripWatchComplication |
| xDrip Widget Extension | com.TEAMID.xdripswift.xDripWidget |

## Create Xdrip4iOS App in App Store Connect

If you have created a Xdrip4iOS app in App Store Connect before, you can skip this section as well.

1. Go to the [apps list](https://appstoreconnect.apple.com/apps) on App Store Connect and click the blue "plus" icon to create a New App.
    * Select "iOS".
    * Select a name: this will have to be unique, so you may have to try a few different names here, but it will not be the name you see on your phone, so it's not that important.
    * Select your primary language.
    * Choose the bundle ID that matches `com.TEAMID.xdripswift`, with TEAMID matching your team id.
    * SKU can be anything; e.g. "123".
    * Select "Full Access".
1. Click Create

You do not need to fill out the next form. That is for submitting to the app store.

## Create Building Certificates

1. Go back to the "Actions" tab of your xdripswift repository in GitHub.
1. On the left side, select "3. Create Certificates".
1. On the right side, click "Run Workflow", and tap the green `Run workflow` button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

> The Create Certificate action:
>
> * generates a new Distribution Certificate if needed, or uses the existing one
> * generates new profiles if needed, or uses existing ones
> * creates credentials used during building if needed, or uses existing ones; these are stored in your Match-Secrets repository using the your MATCH_PASSWORD as the passphrase

### Annual Certificate Renewal

Once a year, you will get an email from Apple indicating your Distribution Certificate will expire in 30 days. One Distribution Certificate is used for all your apps.

* You can wait until the certificate actually expires and Apple removes it from your account
* Your next build will then fail

> If you are building other apps like Loop or Trio, the first one run after the Distribution Certificate is removed will automatically:
>
> * for all apps, clear out old profiles and remove build credentials from your Match-Secrets repository
> * create a new Distribution Certificate
> * create new profiles and new build credentials just for the one app in question and store those in your Match-Secrets repository

Build one of those apps first and then run Create Certificates for xdripswift.

**Manual Renewal**

If you only build xDrip4iOS, you need to manually clear out information in your Match-Secrets repository that uses the old (expired) Distribution Certificate. The easiest way to do this is to delete your Match-Secrets repository and then run Create Certificates.

* [LoopDocs: Delete Match Secrets](https://loopkit.github.io/loopdocs/browser/bb-errors/#delete-match-secrets)

## Build Xdrip4iOS!

1. Click on the "Actions" tab of your xdripswift repository.
1. On the left side, select "4. Build xDrip4iOS".
1. On the right side, click "Run Workflow", and tap the green `Run workflow` button.
1. You have some time now. Go enjoy a coffee. The build should take about 10 minutes.
1. Your app should eventually appear on [App Store Connect](https://appstoreconnect.apple.com/apps).
1. For each phone/person you would like to support xDrip4iOS on:
    * Add them in [Users and Access](https://appstoreconnect.apple.com/access/users) on App Store Connect.
    * Add them to your TestFlight Internal Testing group.

## TestFlight and Deployment Details

Please refer to [LoopDocs: TestFlight Overview](https://loopkit.github.io/loopdocs/browser/tf-users) and [LoopDocs: Install on Phone](https://loopkit.github.io/loopdocs/browser/phone-install/)

## Automatic Build FAQs

### Why do I have an `alive` branch?

If a GitHub repository has no activity (no commits are made) in 60 days, then GitHub disables the ability to use automated actions for that repository. We need to take action more frequently than that or the automated build process won't work.

The updated `build_xdrip.yml` file uses a special branch called `alive` and adds a dummy commit to the `alive` branch at regular intervals. This "trick" keeps the Actions enabled so the automated build works.

The branch `alive` is created automatically for you. Do not delete or rename it! Do not modify `alive` yourself; it is not used for building the app.

## OPTIONAL

What if you don't want to allow automated updates of the repository or automatic builds?

You can affect the default behavior:

1. [`GH_PAT` `workflow` permission](#gh_pat-workflow-permission)
1. [Modify scheduled building and synchronization](#modify-scheduled-building-and-synchronization)

### `GH_PAT` `workflow` permission

To enable the scheduled build and sync, the `GH_PAT` must hold the `workflow` permission scopes. This permission serves as the enabler for automatic and scheduled builds with browser build. To verify your token holds this permission, follow these steps.

1. Go to your [FastLane Access Token](https://github.com/settings/tokens)
2. It should say `repo`, `workflow` next to the `FastLane Access Token` link
3. If it does not, click on the link to open the token detail view
4. Click to check the `workflow` box. You will see that the checked boxes for the `repo` scope become disabled (change color to dark gray and are not clickable)
5. Scroll all the way down to and click the green `Update token` button
6. Your token now holds both required permissions

If you choose not to have automatic building enabled, be sure the `GH_PAT` has `repo` scope or you won't be able to manually build.

### Modify scheduled building and synchronization

You can modify the automation by creating and using some variables.

To configure the automated build more granularly involves creating up to two environment variables: `SCHEDULED_BUILD` and/or `SCHEDULED_SYNC`. See [How to configure a variable](#how-to-configure-a-variable). 

Note that the weekly and monthly Build xDrip4iOS actions will continue, but the actions are modified if one or more of these variables is set to false. **A successful Action Log will still appear, even if no automatic activity happens**.

* If you want to manually decide when to update your repository to the latest commit, but you want the monthly builds and keep-alive to continue: set `SCHEDULED_SYNC` to false and either do not create `SCHEDULED_BUILD` or set it to true
* If you want to only build when an update has been found: set `SCHEDULED_BUILD` to false and either do not create `SCHEDULED_SYNC` or set it to true
    * **Warning**: if no updates to your default branch are detected within 90 days, your previous TestFlight build may expire requiring a manual build

|`SCHEDULED_SYNC`|`SCHEDULED_BUILD`|Automatic Actions|
|---|---|---|
| `true` (or NA) | `true` (or NA) | keep-alive, weekly update check (auto update/build), monthly build with auto update|
| `true` (or NA) | `false` | keep-alive, weekly update check with auto update, only builds if update detected|
| `false` | `true` (or NA) | keep-alive, monthly build, no auto update |
| `false` | `false` | no automatic activity, no keep-alive|

### How to configure a variable

1. Go to the "Settings" tab of your xdripswift repository.
2. Click on `Secrets and Variables`.
3. Click on `Actions`
4. You will now see a page titled *Actions secrets and variables*. Click on the `Variables` tab
5. To disable ONLY scheduled building, do the following:
    - Click on the green `New repository variable` button (upper right)
    - Type `SCHEDULED_BUILD` in the "Name" field
    - Type `false` in the "Value" field
    - Click the green `Add variable` button to save.
7. To disable scheduled syncing, add a variable:
    - Click on the green `New repository variable` button (upper right)
    - - Type `SCHEDULED_SYNC` in the "Name" field
    - Type `false` in the "Value" field
    - Click the green `Add variable` button to save
  
Your build will run on the following conditions:
- Default behaviour:
    - Run weekly, every Wednesday at 08:00 UTC to check for changes; if there are changes, it will update your repository and build
    - Run monthly, every first of the month at 06:00 UTC, if there are changes, it will update your repository; regardless of changes, it will build
    - Each time the action runs, it makes a keep-alive commit to the `alive` branch if necessary
- If you disable any automation (both variables set to `false`), no updates, keep-alive or building happens when Build xDrip4iOS runs
- If you disabled just scheduled synchronization (`SCHEDULED_SYNC` set to`false`), it will only run once a month, on the first of the month, no update will happen; keep-alive will run
- If you disabled just scheduled build (`SCHEDULED_BUILD` set to`false`), it will run once weekly, every Wednesday, to check for changes; if there are changes, it will update and build; keep-alive will run