#' Register a Synapse dataset with your analysis and download a local copy
#'
#' @param id Synapse ID of dataset
#' @param type one of "core", "discovered", or "derived"
#' @details This function should be used once per dataset pulled. It will create a new entry in project_settings.yml with the registered dataset.
#' @export
#' @importFrom synapser synGet
data_pull <- function(id, type = c("core", "discovered", "derived")) {
  cfg <- get_config()

  type <- match.arg(type)

  f <- synapser::synGet(id, downloadFile = FALSE)
  if (!inherits(f, "File"))
    stop("Synapse object with id '", id, "' is not a file.", call. = FALSE)

  # TODO: check to see if this file is in the current project
  # if it is, warn about how data_sync() should be used to register the data

  # see if we have already pulled it
  path <- paste("data", type, f$properties$name, sep = "/")
  if (file.exists(path)) {
    md5 <- unname(tools::md5sum(path))
    if (md5 == f$get("md5")) {
      message("File already exists in project and is up to date.")
      return(invisible(TRUE))
    } else {
      message("File already exists in project... Getting latest version...")
    }
  }

  entity <- synapser::synGet(id,
    downloadLocation = file.path("data", type),
    ifcollision = "overwrite.local")

  cfg$data[[type]][[id]] <- list(
    path = paste("data", type, entity$properties$name, sep = "/"),
    modified = entity$properties$modifiedOn,
    version = entity$properties$versionNumber)

  name <- get_file_name(f$properties$name)
  message("") # Synapse messages don't end with newline...
  message(nice_text("Data pulled. Use 'data_use(\"", name, "\")' ",
    "any time you want to load and use this dataset in your analysis."))

  cfg_set_(cfg)
}

#' Load a dataset registered to your project
#'
#' @param name name of the dataset registered with your project (matches the base name of the data file according to its path in project_config.yml)
#' @param check_update should Synapse be checked to see if there is an updated file available? (default \code{TRUE})
#' @param read_fn an optional function providing code to read in the data file (if not a supported "rds" or "csv" file or if custom reading options are desired). This function should take as a single parameter the path to the file, which will be supplied when it is called.
#' @details If the dataset has not been pulled from Synapse, you will first need to register it with your project using \code{\link{data_pull}} using its Synapse ID. If it has been previously pulled, a check against Synapse will be made for a newer version and the user will be prompted about whether to update the data.
#' @export
#' @importFrom utils menu
#' @importFrom readr read_csv
data_use <- function(name, check_update = TRUE, read_fn = NULL) {
  cfg <- get_config()

  not_found <- FALSE
  is_syn_id <- grepl("^syn[0-9]", name)

  dat <- get_config()$data
  ids <- lapply(dat, names)
  if (is_syn_id) {
    id <- name
    idx <- which(sapply(ids, function(x) id %in% x))
    if (length(idx) == 0) {
      not_found <- TRUE
    } else {
      entry <- dat[[idx]][[id]]
      name <- get_file_name(entry$path)
    }
  } else {
    idx <- which(sapply(dat, function(x) {
      nms <- sapply(x, function(a) get_file_name(a$path))
      name %in% nms
    }))
    if (length(idx) == 0) {
      not_found <- TRUE
    } else {
      nms <- sapply(dat[[idx]], function(x) get_file_name(x$path))
      idx2 <- which(name == nms)
      entry <- dat[[idx]][[idx2]]
      id <- names(dat[[idx]])[idx2]
    }
  }

  if (not_found) {
    txt <- ifelse(is_syn_id, "Synapse ID", "name")
    stop(nice_text("Couldn't find a dataset registered to this ",
      "project with ", txt, " '", name, "'. Check the name against",
      "registered datasets with data_list(). You can register a new ",
      "dataset with data_publish() or pull a core dataset from ",
      "another Synapse space with data_pull()."))
  }

  if (!file.exists(entry$path)) {
    message(nice_text("This data has not been downloaded from Synapse. ",
      "Downloading now..."))
    entity <- synapser::synGet(id,
      downloadLocation = dirname(entry$path),
      ifcollision = "overwrite.local")
    message("")
  } else if (check_update) {
    # check to see if there's a newer one on Synapse
    f <- synapser::synGet(id, downloadFile = FALSE)
    # Q: should we check md5 instead?
    synver <- f$properties$versionNumber
    if (synver != entry$version) {
      message(nice_text("The version of this file on Synapse (v",
        synver, ") is not the same as local (v", entry$version, ")."))
      ans <- utils::menu(c("Yes", "No"), 
        title = "Replace the local version with file from Synapse?")
      if (ans == 1) {
        message("Downloading from Synapse...")
        entity <- synapser::synGet(id,
          downloadLocation = dirname(entry$path),
          ifcollision = "overwrite.local")
        message("")
        message("Downloading Complete.")
      }
    }
  }

  # now finally load the file in
  # honor special reader function if specified
  if (!is.null(read_fn) && is.function(read_fn)) {
    return(read_fn(entry$path))
  } else {
    file_type <- get_file_type(entry$path)
    if (file_type == "rds") {
      return(readRDS(entry$path))
    } else if (file_type == "csv") {
      return(readr::read_csv(entry$path))
    } else {
      message(nice_text("Don't know how to read file of type ",
        file_type, ". Please provide a custom reader function ",
        "that takes as one argument the path of the file to read."))
    }
  }
}

# synGetChildren
# synapser::synGetUserProfile(id = 3341483)

#' One-way sync of data from Synapse to local
#'
#' @export
#' @details Looks at all datasets in project_config.yml and pulls them if they aren't recent. To push discovered and derived data back to Synapse, use \code{\link{data_publish}}.
#' @importFrom tools md5sum
data_sync <- function() {

  cfg <- get_config()

  traverse_and_download <- function(x, type) {
    nms <- names(x[[type]])
    for (id in nms) {
      f <- synapser::synGet(id, downloadFile = FALSE)
      a <- x[[type]][[id]]
      md5 <- unname(tools::md5sum(a$path))
      if (is.na(md5) || md5 != f$get("md5")) {
        # TODO: ask first
        message("Downloading ", f$properties$name, " to ",
          file.path("data", type), "...")
        entity <- synapser::synGet(id,
          downloadLocation = file.path("data", type),
          ifcollision = "overwrite.local")
      }
    }
  }

  for (tp in names(cfg$data)) {
    message("Syncing ", tp, " data...")
    traverse_and_download(cfg$data, tp)
  }
}

# data_sync_raw <- function() {

# }


get_file_type <- function(path) {
  tools::file_ext(basename(path))
}

get_file_name <- function(path) {
  tools::file_path_sans_ext(basename(path))
}

# TODO: compute metadata
# TODO: keep _raw in sync?

#' Publish a discovered or derived dataset to Synapse
#'
#' @param obj object to publish or a path to the file in your project's data/discovered or data/derived folder
#' @param name name of the dataset being published
#' @param type either "derived" or "discovered". If "discovered", it will go in data/discovered. If "derived", it will go in data/derived.
#' @param file_type one of "rds", or "csv"
#' @param desc description of the dataset
#' @param used (optional) The Entity, Synapse ID, or URL used to create the object (can also be a list of these)
#' @param executed (optional) The Entity, Synapse ID, or URL representing code executed to create the object (can also be a list of these)
#' @param activity (optional) Activity object specifying the user's provenance
#' @param activity_name (optional) Activity name to be used in conjunction with *used* and *executed*.
#' @param activity_desc	(optional) Activity description to be used in conjunction with *used* and *executed*.
#' @export
#' @importFrom synapser Folder File synStore
data_publish <- function(obj, name = NULL, type = c("discovered", "derived"),
  file_type = c("rds", "csv", "txt"), desc = NULL, used = NULL, executed = NULL,
  activity = NULL, activity_name = NULL, activity_desc = NULL) {

  type <- match.arg(type)
  file_type <- match.arg(file_type)

  nrow <- NULL
  ncol <- NULL

  if (is.character(obj)) {
    # it's a path, so we don't need to save the object, just publish
    path <- obj
    file_type <- get_file_type(path)
    name2 <- get_file_name(path)
    if (!is.null(name))
      message(nice_text("Ignoring provided name: '", name, "' and using the ",
      "file's name: '", name2, "'."))
    name <- name2

    if (! grepl("^data/discovered|^data/derived", path))
      stop(nice_text("Only data stored in 'data/discovered' or 'data/derived' ",
        "can be published to Synapse. The provided data path was '",
        path, "'."),
        call. = FALSE)

    type <- ifelse(grepl("^data/discovered", path), "discovered", "derived")
  } else if (is.data.frame(obj)) {
    nrow <- nrow(obj)
    ncol <- ncol(obj)

    # save appropriate type
    if (is.null(name))
      stop("Must provide a 'name' for this object.")

    path <- file.path("data", type, paste0(name, ".", file_type))

    # make sure the name doesn't already exist
    nms <- get_data_names()
    if (name %in% nms) {
      if (file.exists(path)) {
        ans <- utils::menu(c("Yes", "No"),
          title = "This file exists. Do you want to overwrite a new version?")
        if (ans != 1) {
          message("Not publishing file...")
          return(invisible(NULL))
        }
      } else {
        stop(nice_text("A different dataset with the same name, '", name,
          "' already exists. Please choose a different name."),
          call. = FALSE)
      }
    }

    message("Saving to disk...")
    if (file_type == "rds") {
      saveRDS(obj, file = path)
    } else if (file_type %in% c("csv", "txt")) {
      readr::write_csv(obj, path = path)
    } else {
      stop("File type '", file_type, "' not supported.")
    }
  } else {
    stop(nice_text("data_publish() doesn't yet support non-data-frame ",
      "objects. To publish, please first save it to data/discovered or ",
      "data/derived and then call data_publish() again with the path to ",
      "that file."),
      call. = FALSE)
  }

  if (!file.exists(path))
    stop(nice_text("Data in specified path '", path, "' does not exist"),
      call. = FALSE)

  cfg <- get_config()
  id <- cfg$synapse_id
  if (is.null(id))
    stop(nice_text("Could not find an entry for 'synapse_id' in analysis ",
      "project configuration file 'project_config.yml'. ",
      "Please use `use_synapse(id)` to update this."),
      call. = FALSE)

  project <- synapser::synGet(id)
  if (!inherits(project, "Project")) {
    stop(nice_text("The synapse_id: ", id, " provided in project_config.yml ",
      "is not a valid Synapse project id."),
      call. = FALSE)
  }

  data_folder <- synapser::Folder("Data", parent = project)
  tmp <- synapser::synStore(data_folder)
  data_folder2 <- synapser::Folder(type, parent = tmp)
  tmp <- synapser::synStore(data_folder2)

  message("Publishing file to Synapse...")
  file <- synapser::File(path = path, parent = tmp)
  res <- synapser::synStore(file,
    used = used,
    executed = executed,
    activity = activity,
    activityName = activity_name,
    activityDescription = activity_desc,
    forceVersion = FALSE)

  file_id <- res$properties$id
  message("")
  message("File has been stored on Synapse with id '", file_id, "'.")

  # add to config...
  if (is.null(cfg$data))
    cfg$data <- list(
      core = NULL,
      discovered = NULL,
      derived = NULL)

  cfg$data[[type]][[file_id]] <- list(
    path = path,
    modified = res$properties$modifiedOn,
    version = res$properties$versionNumber)

  synapser::synSetAnnotations(file_id, annotations = list(
    desc = desc,
    published_by = get_syn_user(),
    nrow = nrow,
    ncol = ncol
  ))

  cfg_set_(cfg)

  # activity <- Activity(
  #   name = 'Activity name',
  #   description='Activity description',
  #   used = c('syn1906480', 'http://data_r_us.com/fancy/data.txt'),
  #   executed = 'syn1917825')

  invisible(res)
}

#' List all datasets registered with the project
#' @export
data_list <- function() {
  dat <- get_config()$data
  res <- do.call(rbind, list(
    data_list_sub(dat, "core"),
    data_list_sub(dat, "discovered"),
    data_list_sub(dat, "derived")
  ))
  if (nrow(res) == 0) {
    cat("[no data]")
  } else {
    print(res, row.names = FALSE)
  }
}

#' View a dataset on Synapse
#'
#' @param id Synapse ID of the data file
#' @note To see a list of Synapse IDs for registered data files, use \code{\link{data_list}}.
#' @export
#' @importFrom utils browseURL
data_view <- function(id) {
  utils::browseURL(paste0("https://www.synapse.org/#!Synapse:", id))
}

data_list_sub <- function(dat, type) {
  rws <- lapply(dat[[type]], function(x) as.data.frame(x,
    stringsAsFactors = FALSE))
  if (length(rws) == 0)
    return(NULL)
  tmp <- do.call(rbind, unname(rws))
  tmp$synapse_id <- names(dat[[type]])
  tmp$path <- get_file_name(tmp$path)
  tmp$modified <- substr(tmp$modified, 1, 16)
  tmp$modified <- gsub("T", " ", tmp$modified)
  names(tmp)[1] <- "name"
  tmp$type <- type
  tmp[, c("name", "type", "modified", "version", "synapse_id")]
}

get_data_names <- function() {
  dat <- get_config()$data
  unname(
    unlist(
      lapply(unlist(dat, recursive = FALSE),
        function(x) get_file_name(x$path))))
}
