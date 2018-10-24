cfg <- new.env(parent = emptyenv())

cfg_get_ <- function() cfg$cur

#' @importFrom yaml write_yaml
cfg_set_ <- function(dat) {
  yaml::write_yaml(dat, file = "project_config.yml")
  old <- cfg$cur
  cfg$cur <- dat
  invisible(old)
}

#' Scaffolding to create a Ki analysis project
#'
#' @param path path to directory where project will be set up
#' @param title a title for the project
#' @param synid a synapse project ID for the project
#' @param use_packrat should packrat be initialized for managing package dependencies? (NOT IMPLEMENTED)
#' @importFrom usethis create_project use_git_ignore
#' @importFrom git2r config
#' @export
create_analysis <- function(path = ".", title = NULL, synid = NULL,
  use_packrat = FALSE) {

  # TODO: check if project already exists and load it...
  if (file.exists(file.path(path, "project_config.yml"))) {
    message(nice_text("It looks like a project has already been created. ",
      "Loading the project..."), call. = FALSE)
  }

  message("Configuring project...")

  usethis::create_project(path, rstudio = FALSE, open = FALSE)

  # track contributing user via synapse ID in git global config custom field
  # (can't track in config because it's shared across multiple users)
  git_cfg <- git2r::config(global = TRUE)
  if (is.null(git_cfg[["global"]]$user.synapseid)) {
    synapseid <- readline(prompt = "Enter your synapse ID: ")
    git2r::config(global = TRUE, "user.synapseid" = synapseid)
  }

  if (is.null(title))
    title <- readline(prompt = "Enter the project title: ")

  if (is.null(synid))
    synid <- readline(prompt = paste0(nice_text(
      "Enter the ID of the associated synapse space. ",
      "This is required to push/pull data to/from Synapse. ",
      "If you don't know the ID, just hit 'enter' and you can ",
      "set it later with use_synapse(id):"), " "))

  if (synid == "")
    synid <- NULL

  cfg <- list(
    title = title,
    synapse_id = synid,
    data = list(
      core = NULL,
      discovered = NULL,
      derived = NULL
    )
  )

  cfg_set_(cfg)

  message("Setting up project file structure...")

  if (!dir.exists("data/core"))
    dir.create("data/core", recursive = TRUE)

  if (!dir.exists("data/derived"))
    dir.create("data/derived", recursive = TRUE)

  if (!dir.exists("data/discovered/_raw"))
    dir.create("data/discovered/_raw", recursive = TRUE)

  if (!dir.exists("data/scripts/_raw"))
    dir.create("data/scripts/_raw", recursive = TRUE)

  if (!dir.exists("reports"))
    dir.create("reports")

  usethis::use_git_ignore(c(
    ".Rproj.user", ".Rhistory", ".RData", ".rda", ".png", ".jpeg", ".pdf",
    "data/core", "data/derived", "data/discovered"))

  # check Synapse login
  a <- try(synapser::synGet("syn1906480", downloadFile = FALSE), silent = TRUE)
  if (inherits(a, "try-error") && grepl("Please login", a)) {
    message("Not logged into Synapse... Logging in...")
    synapse_login()
  }
}

get_syn_user <- function() {
  git_cfg <- git2r::config(global = TRUE)
  git_cfg[["global"]]$user.synapseid
}

get_config <- function() {
  cfg <- cfg_get_()
  if (is.null(cfg))
    load_project()
  cfg
}

#' @importFrom yaml read_yaml
#' @importFrom usethis proj_get
load_project <- function(load_packages = TRUE) {
  tryres <- try(usethis::proj_get(), silent = TRUE)

  if (inherits(tryres, "try-error")) {
    msg <- gsub("Error : ", "", tryres)
    stop(msg, " Use create_analysis() if you haven't created an analysis yet.",
      call. = FALSE)
  }

  if (!file.exists("project_config.yml"))
    stop(nice_text("Could not find a valid configuration. ",
      "Has this project been initialized with create_analysis()?"),
      call. = FALSE)

  cfg <- yaml::read_yaml("project_config.yml")
  cfg_set_(cfg)

  # check Synapse login
  a <- try(synapser::synGet("syn1906480", downloadFile = FALSE), silent = TRUE)
  if (inherits(a, "try-error") && grepl("Please login", a)) {
    message("Not logged into Synapse... Logging in...")
    synapse_login()
  }

  # check if there is a Synapse ID and warn if not

  message("Project '", cfg$title, "' loaded.")
}

#' Adds R package to project configuration file
use_project_package <- function() {

}

use_synapse <- function(id) {
  cfg <- cfg_get_()
  if (length(cfg) == 0)
    stop(nice_text("Could not find a valid configuration. ",
      "Has this project been initialized with create_project()?"))
  cfg$synapse_id <- id
  cfg_set_(cfg)
}

#' Log in to Synapse
#'
#' @param ... arguments passed to \code{\link[synapser]{synLogin}}
#' @export
#' @importFrom synapser synLogin
synapse_login <- function(...) {
  args <- list(...)
  if (!is.null(Sys.getenv("SYN_EMAIL")) && is.null(args$email))
    args$email <- Sys.getenv("SYN_EMAIL")
  if (!is.null(Sys.getenv("SYN_PAT")) && is.null(args$apiKey))
    args$apiKey <- Sys.getenv("SYN_PAT")
  res <- do.call(synapser::synLogin, args)
  message("")
  invisible(res)
}
