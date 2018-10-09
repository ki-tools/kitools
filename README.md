[![Travis build status](https://travis-ci.org/ki-tools/kitools.svg?branch=master)](https://travis-ci.org/ki-tools/kitools)
[![Coverage status](https://codecov.io/gh/ki-tools/kitools/branch/master/graph/badge.svg)](https://codecov.io/github/ki-tools/kitools?branch=master)
[![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)

# kitools

The kitools R package provides utility functions for setting up Knowledge Integration (Ki) projects and supporting workflows within these projects, such as finding data and publishing results.

This package is in the extreme early development process and is expected to seriously evolve over time. Although hosted publicly on GitHub, it is not of use to the general public - only to those inside Ki.

More documentation will be made available as the package matures.

## Guidance for Ki Analysis Projects

General guidelines:

- All analysis source code is managed and version controlled using Git and Github, using the ["ki-analysis"](https://github.com/ki-analysis) Github organization.
- All analysis code is open and public on Github. While several Ki datasets are not appropriate to host publicly, code that acts on them can be public.
- Github is for code only. Data and binary artifacts such as figures are not stored in Github. There are [good reasons for this](https://robinwinslow.uk/2013/06/11/dont-ever-commit-binary-files-to-git/), and we have a more appropriate place (Synapse) for these files.
- Core datasets (see definition below) as well as derived data artifacts are stored in your local analysis environment but are not pushed to Github. For provenance and reproducibility, data are synced with [Synapse](https://www.synapse.org), with utility functions provided by kitools for pulling and pushing data.
- R Markdown documents and Shiny apps are published to the Ki RStudio Connect server and public / private viewing permissions are evaluated on a case-by-case basis. Utility functions and guidance for doing this are (TODO) provided as part of the kitools package. Source code for R Markdown documents and Shiny apps can be tracked in Git and published to Github.
- Support for publishing results using other technologies such as Jupyter notebooks, etc., will be considered when / if demand is sufficient.

#### Project setup

This package provides utility functions that you must use to set up a new Ki analysis project. These set up minimal project structure, with the goal of giving you freedom while still maintaining standard behavior where necessary for Ki reproducibility and tracking needs.

- Create an empty directory named for your analysis (see "Naming projects" below) and enter R with this as your working directory
- `create_analysis()`
  - Prompts for your Synapse ID, if not already supplied
  - Prompts for a title of your project
  - Prompts for the ID of the associated Synapse space where data and other analysis outputs will be stored
  - Stores these values in a project-level configuration file
  - Sets up a minimal directory structure
    - `/R` for analysis R code
    - `/data/core` to locally store core datasets pulled from Synapse, pulled with `data_use(id)` (see "Working with data" for more on core vs. discovered vs. derived datasets)
    - `/data/discovered/_raw` to locally place raw data files for discovered datasets
    - `/data/discovered` to locally place processed discovered datasets that you are ready to publish to Synapse and share with others, published with `data_publish(path)`
    - `/data/derived` to locally place datasets derived from core or discovered datasets, typically as the result of an analysis or summarization, also published with `data_publish(path)`
    - `/data/scripts` to store R scripts that operate on raw discovered data to create discovered data, or operate on core or discovered data to produce derived data
  - Creates a .gitignore file to ignore data/core, data/derived, data/discovered, *.Rdata, *.rda, *.png, *.jpeg, *.pdf, etc.
- `usethis::use_git()` to intialize a git repository for the analysis
- `usethis::use_github(organisation = "ki-analysis")` to set a GitHub remote at `ki-tools/__analysis-name__`

<!-- http://projecttemplate.net/index.html -->

#### Naming projects

Names for projects should be descriptive, use lowercase text, and use dashes to separate words. This convention should be used for naming all other files in an analysis as well.

#### Working with data

There are three main classes of data types in a Ki analysis:

- **Core data**: Data that exists in Synapse, probably in its own Synapse project and has ideally gone through some sort of rigorous curation from the data management team. Once pulled into your local environment, you should treat them as read-only.
- **Discovered data**: These are datasets that you may have found somewhere ourside of Ki. These data should be treated as read-only. You should register these datasets in the Synapse project associated with your anlaysis, but if later deemed to be generally useful to projects beyond your analysis, they should be considered for additional curation and promotion to a core dataset.
- **Derived data**: These are datasets that you derive throughout the course of your analysis. Examples include transformations of core datasets, analysis output data objects, tables, plot-ready data, etc. Each derived dataset should have a script that generates it, stored in the "data/scripts" directory or in your "R" code directory.

There are several utility functions for working with data in kitools. The purpose for these data management functions is to help you keep the datasets you are using and producing organized and sharable with others. Each dataset you use or produce can be registered to your project and synced with Synapse, so that others who check out your code can easily get up to speed with. This also helps provide some additional provenance of what datasets are used in what analyses. These utilities also help you separate your code storage on Github from your data storage on Synapse.

Data management functions:

- `data_use(synapse_id)`: This is used when you need to register a core dataset with your analysis and download a local copy.
- `data_publish(path, ...)`: This is used when you need to register a discovered or derived dataset with your analysis and push it to the appropriate place on Synapse.
- `data_sync()`: This is used when you want to make sure you have a local copy of all datasets that have been associated with your analysis project. This is useful for collaborative environments where someone else might check out your code and wants to pull all data files associated with the project.

Datasets that have been registered with your analysis project are updated in your "project_config.yml" file and you can view this file to see what's registered with your project.

#### Working with code

On project creation, an "R" directory is created in which you can add R scripts. Here you are free organize your files however you like, but you are encouraged to use descriptive file names with all lowercase, no spaces, and underscores to separate words, followed with a capital ".R" file extension.

An often-recommended approach to organizing R analysis code is to write your code as an R package. There are benefits to this approach, but we do not want to put too many constraints on project structure and there are also negative aspects of this approach. Instead, you should think about aspects of your analysis code that could be of general use beyond your analysis and create separate R packages for those separately as appropriate. For example, in the [CIDACS Brazil analysis](), general functionality for transforming DATASUS data was deemed to be generally useful as a [separate R package]() and developed accordingly.

#### Style guide

To make it easier to work in a collaborative manner, we strongly recommend adhering to the [tidyverse style guide](http://style.tidyverse.org) for your analysis code.

## Guidance for Ki R Packages

#### Package scaffolding

If you find yourself in need to develop a Ki-related R package, this package provides utilities to bootstrap your package in a way that conforms with Ki R package development guidance.

Several functions in the usethis package are leveraged for a ki R package setup. If you have not used usethis, some useful setup instructions can be found [here](http://usethis.r-lib.org/articles/articles/usethis-setup.html).

The following steps are recommended to set up a ki R package:

- `usethis::create_package()` to create a package (if not already created)
- `usethis::use_git()` to initialize a git repository
- `usethis::use_github(organisation = "ki-tools")` to set a GitHub remote at `ki-tools/__package-name__`
- `usethis::use_readme_md()` to create a basic README.md file
- `usethis::use_testthat()` to set up unit tests
- `usethis::use_tidy_ci()` to set up travis-ci continuous integration and code coverage - be sure to add Travis and coverage
- `kitools::use_lintr_test()` to add a unit test for correct code style
- `kitools::use_apache_license()` to use the Apache 2.0 license (with copyright BMGF)

<!-- `use_tidy_issue_template()` -->
<!-- `use_tidy_contributing()` -->

#### Style guide

To make it easier to work in a collaborative manner, we adhere to the [tidyverse style guide](http://style.tidyverse.org).

You should add a unit test to your package that will cause the package check to fail if the code does not meet the style guide. You can set this up with a utility function `kitools::use_lintr_test()`.

#### Documentation

- Use roxygen to document package functions, data, etc.
- We recommend using [pkgdown](https://pkgdown.r-lib.org) for more user-friendly documentation. You can set this up with `usethis::use_pkgdown()`.

Please note that the 'kitools' project is released with a [Contributor Code of Conduct](.github/CODE_OF_CONDUCT.md). By contributing to this project, you agree to abide by its terms