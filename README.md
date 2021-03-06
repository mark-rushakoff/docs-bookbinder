[![Code Climate](https://codeclimate.com/github/pivotal-cf/docs-bookbinder.png)](https://codeclimate.com/github/pivotal-cf/docs-bookbinder) [![Build Status](https://travis-ci.org/pivotal-cf/docs-bookbinder.png?branch=master)](https://travis-ci.org/pivotal-cf/docs-bookbinder)
# Bookbinder

Bookbinder is a gem that binds together a unified documentation web-app from disparate source material, stored as repositories of markdown or plain HTML on GitHub. It runs [middleman](http://middlemanapp.com/) to produce a (CF-pushable) Rackup app.

## About

Bookbinder is meant to be used from within a "book" project. The book project provides a configuration of which documentation repositories to pull in; the bookbinder gem provides a set of scripts to aggregate those repositories and publish them to various locations.
It also provides scripts for running a CI system that can detect when a documentation repository has been updated with new content, and then verify that the composed book is free of any dead links.

## Setting Up a Book Project

### Setup Checklist
Please read this document to understand how to set up a new book project.  You can refer to this checklist for the steps that must completed manually when setting up your book:

#### Creating and configuring your book
- Create a git repo for the book and populate it with the required files (or use an existing book repo as a template)
- Add list of included doc repos to `config.yml`
- (For private repositories) Create a github [Personal Access Token](https://github.com/settings/applications) for bookbinder from an account that has access to the documentation repositories
- (For private repositories) Set your Personal Access Token as the environment variable GITHUB_API_TOKEN
- Publish and run the server locally to test your book

#### Deploying your book
- Create AWS bucket for green builds and put info into `config.yml`
- Set up CF spaces for staging and production and put details into `config.yml`
- Start a Jenkins CI server 
- Set up Jenkins CI with required plugins and two-build setup
- Verify that Jenkins builds are running and that it deploys to staging after successful builds
- Deploy to production
- (optional) Register your sitemap with Google Webmaster Tools

### Book Repository Structure
A book project needs a few things to allow bookbinder to run. Here's the minimal directory structure you need in a book project:

```
.
├── Gemfile
├── Gemfile.lock
├── .gitignore
├── .ruby-version
├── config.yml
└── master_middleman
    ├── config.rb
    ├── source
    |   ├── index.html.md
    |   ├── layouts
    |   |   └── layout.erb
    |   └── subnavs
    |       └── _default.erb
    └── <Top level folder of "pretty" directory path>
        └── (optional) index(.html)(.md)(.erb)
```

`Gemfile` needs to point to this bookbinder gem, and probably no other gems. `Gemfile.lock` can be created by bundler automatically (see below).

`config.yml` is a YAML file that holds all the information bookbinder needs. The following keys are used:

- **book_repo**: the org-name/repo-name of the book's github repository.
- **cred_repo**: the org-name/repo-name of a private repository in which AWS and CF credentials may be kept to facilitate secure CI
- **repos**: an array of hashes which specifies which documentation repositories to pull in. Each hash needs to specify:
    - **github_repo**: the path on github to this repository, i.e. 'organization/repository'. The organization is ignored when finding repositories locally. The repository must be public (unless finding repositories locally).
    - **directory**: (optional) a "pretty" directory path under the main root that the webapp will use for this sub-repo.
    - **sha**: (optional) the sha of the repo to use when downloading it from github. Ignored when finding repositories locally.
    - **subnav_template**: (optional) a label for the template in /subnavs to insert at `<%= yield_for_subnav %>`, when generating the page. Note the default template (\_default.erb) uses the label `default` and is applied to all repos unless another template is specified with subnav\_template. Template labels beside the default one are the name of the template file with extension removed. ("sample" for a template named "sample.erb") 
- **public_host**: (domain, used for sitemap generation) e.g. docs.gopivotal.com
- **pdf**: (optional) Bookbinder can generate a PDF from one output (.html) file. To format it properly, you need to include print-specific stylesheets.
    - **page**: path of webpage to turn into a PDF (remember to use the "pretty" path if using the 'directory' key in the repo)
    - **filename**: name of the outputted PDF
- **aws**: For CI and deployment scripts. These allow bookbinder's CI scripts to push/pull green builds to/from S3
    - **access_key**: your AWS access key
    - **secret_key**: your AWS secret key
    - **green_builds_bucket**: This is where we store builds (on S3) that go green on Jenkins, and are ready to be pushed to production.
- **cloud_foundry**: For deployment scripts. As with github, we advise to use a non-person "role" account here. For staging and production servers, we assume you have already created a **app_name** application within the specified spaces (pushes will fail if the app is not yet in place).
    - **username**: CF username
    - **password**: CF password
    - **api_endpoint**: e.g. https://api.run.pivotal.io
    - **organization**: e.g. pivotal
    - **app_name**: e.g. docs
    - **staging_space**: e.g. docs-pivotalone-staging
    - **production_space**: e.g. docs-pivotalone-prod
    - **staging_host**: (subdomain of cfapps.io) e.g. cf-p1-docs-staging
    - **production_host**: (subdomain of cfapps.io) e.g. cf-p1-docs-prod
- **template_variables**: (optional) a hash of variables that can be used by ERB templates, like so: <%= vars.var_name %>
    - **var_name**: var_val
    - ...

`.gitignore` should contain the following entries, which are directories generated by bookbinder:

    output
    final_app

`master_middleman` is a directory which forms the basis of your site. [Middleman](http://middlemanapp.com/) configuration and top-level assets, javascripts, and stylesheets should all be placed in here. You can also have ERB layout files. Each time a publish operation is run, this directory is copied to `output/master_middleman`. Then each doc-repo is copied (as a directory) into `output/master_middleman/source/`, before middleman is run to generate the final app.

`.ruby-version` is used by [rbenv](https://github.com/sstephenson/rbenv) or [rvm](https://rvm.io/) to find the right ruby.  WARNING: If you install rbenv, you MUST uninstall RVM first: [see details here](http://robots.thoughtbot.com/post/47273164981/using-rbenv-to-manage-rubies-and-gems).

## Middleman Templating Helpers

Bookbinder comes with a Middleman configuration that provides a handful of helpful functions, and should work for most Book Projects. To use a custom Middleman configuration instead, place a `config.rb` file in the `master_middleman` directory of the Book Project (this will overwrite Bookbinder's `config.rb`).

Bookbinder provides several helper functions that can be called from within a .erb file in a doc repo, such as a layout file.

`<%= quick_links %>` produces a table of contents based on in-page anchors.

`<%= breadcrumbs %>` generates a series of breadcrumbs as a UL HTML tag. The breadcrumbs go up to the site's top-level, based on the title of each page. The bottom-most entry in the list of breadcrumbs represents the current page; the rest of the breadcrumbs show the hiearchy of directories that the page lives in. Each breadcrumb above the current page is generated by looking at the [frontmatter](http://middlemanapp.com/frontmatter/) title of the index template of that directory. If you'd like to use breadcrumb text that is different than the title, an optional 'breadcrumb' attribute can be used in the frontmatter section to override the title.

`<%= yield_for_subnav %>` inserts the appropriate template in /subnavs, based on each constituent repositories' `subnav_template:` parameter in config.yml.

`<%= yield_for_code_snippet from: 'my-org/code-repo', at: 'myCodeSnippetA' %>` inserts code snippets extracted from code repositories. Wrap excerpts with their corresponding markers:

```clojure

; code_snippet myCodeSnippetA start
	(def fib-seq
   	  (lazy-cat [0 1] (map + (rest fib-seq) fib-seq)))
	user> (take 20 fib-seq)
	(0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 987 1597 2584 4181)
; code_snippet myCodeSnippetA end

```

Bookbinder also includes helper code to correctly find image, stylesheet, and javascript assets. When using `<% image_tag ...`, `<% stylesheet_link_tag ...`, or `<% javascript_include_tag ...` to include assets, Bookbinder will search the entire directory structure starting at the top-level until it finds an asset with the provided name. For example, when resolving `<% image_tag 'great_dane.png' %>` called from the page `dogs/big_dogs/index.html.md.erb`, Middleman will first look in `images/great_dane.png.` If that file does not exist, it will try `dogs/images/great_dane.png`, then `dogs/big_dogs/images/great_dane.png`.

## Bootstrapping with Bundler

Once rbenv or rvm is set up and the correct ruby version is set up (2.0.0-p195), run (in your book project)

    gem install bundler
    bundle

And you should be good to go!

Bookbinder's entry point is the `bookbinder` executable. It should be invoked from the book directory. The following commands are available:

### `publish` command

Bookbinder's most important command is `publish`. It takes one argument on the command line:

        bundle exec bookbinder publish local

will find documentation repositories in directories that are siblings to your current directory, while

        bundle exec bookbinder publish github

will find doc repos by downloading the latest version from github.

The publish command creates 2 output directories, one named `output/` and one named `final_app/`. These are placed in the current directory and are cleared each time you run bookbinder.

`final_app/` contains bookbinder's ultimate output: a Rackup web-app that can be pushed to cloud foundry or run locally.

`output/` contains intermediary state, including the final prepared directory that the `publish` script ran middleman against, in `output/master_middleman`.

### `update_local_doc_repos` command

As a convenience, Bookbinder provides a command to update all your local doc repos, performing a git pull on each one:

        bundle exec bookbinder update_local_doc_repos

### `tag` command

The `bookbinder tag` command commits Git tags to checkpoint a book and its constituent document repositories. This allows the tagged version of the documentation to be re-generated at a later time.

    `bundle exec bookbinder tag book-formerly-known-as-v1.0.1`

Books can be published from a tag, like so:

    `bundle exec bookbinder publish github book-formerly-known-as-v1.0.1`

## Running the App Locally

    cd final_app
    bundle
    ruby app.rb

This will start a Rackup server to serve your documentation website locally at [http://localhost:4567/](http://localhost:4567/). While making edits in documentation repos, we recommend leaving this running in a dedicated shell window.  It can be terminated by hitting `ctrl-c`.

You should only need to run the `bundle` the first time around. 


## Continuous Integration

### CI for Books

Part of what makes bookbinder awesome is that it can automatically verify and deploy your book on changes to doc repos, using Jenkins.

The goal of this CI setup is to run a full publish operation every time either of the following changes:

- Your book's repo, i.e. any change to your main book git repo.
- Any of the document sub-repositories that the book depends on (listed in config.yml).

The book CI should have 2 Jenkins builds to accomplish this. Both should link to the same repository (the book repository). Both use scripts from the bookbinder gem.

The **Change Monitor Build** build is simply a cron-like build that runs every minute, and detects if any of the document repositories have changed; if they have, it triggers the Publish Build to run. 

The **Publish Build**, when triggered, runs a full publish operation. If the publish build goes green (i.e. there are no broken links), it will deploy to staging and also generate a tarball of the green build, which is stored on S3 with a build number in the filename.  It is then available for [manual deployment](#deploying) to production.

### CI Technical Details

[Ciborg](https://github.com/pivotal/ciborg) can be used to set up an AWS box running Jenkins.

The following Jenkins plugins are necessary:

- Rbenv (configured to use ruby version 2.0.0p195) (this may be optional, haven't tested yet)
- Jenkins GIT
- Jenkins java.io.tmpdir cleaner plugin

You will also want to select the Discard Old Builds checkbox in the configuration for each Jenkins build so that your disk does not fill up.

#### *Change Monitor Build*
This Jenkins build executes the following shell command

    bundle install
    bundle exec bookbinder doc_repos_updated

and builds the **Publish Build** project on success as a post-build action.

This build determines whether a full publish build should be triggered, by checking whether any of the documentation repos have changed since the last build. To do this, it maintains the `cached_shas.yml` file, kept in the job folder of the change monitor build (i.e. one level above the actual workspace), so that it persists between builds.

#### *Publish Build*
This build executes this shell command:

    bundle install
    bundle exec bookbinder run_publish_ci

## <a name="deploying"></a>Deploying

Bookbinder has the ability to deploy the finished product to either staging or production. The deployment scripts use the gem's pre-packaged CloudFoundry Go CLI binary (separate versions for darwin-amd64 and linux-amd64 are included); any pre-installed version of the CLI on your system will **not** be used.

### Setting up CF Apps

Each book should have a dedicated CF space and host for its staging and production servers.
The Cloud Foundry organization and spaces must be created manually and specified as values for "organization", "staging_space" and "production_space" in `config.yml`.
Upon the first and second deploy, bookbinder will create two apps in the space to which it is deploying. The apps will be named `"app_name"-blue` and `"app_name"-green`.  These will be used for a [blue-green deployment](http://martinfowler.com/bliki/BlueGreenDeployment.html) scheme.  Upon successful deploy, the subdomain of `cfapps.io` specified by "staging_host" or "production_host" will point to the most recently deployed of these two apps.


### Deploy to Staging
Deploying to staging is not normally something a human needs to do: the book's Jenkins CI script does this automatically every time a build passes.

The following command will deploy the build in your local 'final_app' directory to staging:

    bundle exec bookbinder push_local_to_staging

### Deploy to Production
Deploying to prod is always done manually. It can be done from any machine with the book project checked out, but does not depend on the results from a local publish (or the contents of your `final_app` directory). Instead, it pulls the latest green build from S3, untars it locally, and then pushes it up to prod:

    bundle exec bookbinder push_to_prod <build_number>

If the build_number argument is left out, the latest green build will be deployed to production.

## Generating a Sitemap for Google Search Indexing

The sitemap file `/sitemap.txt` is automatically regenerated when publishing. When setting up a new docs website, make sure to add this sitemap's url in Google Webmaster Tools (for better reindexing?).

## Contributing to Bookbinder

### Running Tests

To run bookbinder's rspec suite, use bundler like this: `bundle exec rspec`.

### CI

Bookbinder has a [CI on Travis](https://travis-ci.org/pivotal-cf/docs-bookbinder) that runs all its unit tests.
