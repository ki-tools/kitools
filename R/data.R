
#' Register a Synapse dataset with your analysis and download a local copy
#'
#' @param id Synapse ID of dataset
#' @param type one of "core", "discovered", or "derived"
#' @export
#' @importFrom synapser synGet
data_use <- function(id, type = c("core", "discovered", "derived")) {
  type <- match.arg(type)

  f <- synapser::synGet(id, downloadFile = FALSE)
  if (!inherits(f, "File"))
    stop("Synapse object with id '", id, "' is not a file.", call. = FALSE)

  # TODO: check to see if this file is in the current project
  # if it is, warn about how data_sync() should be used to register the data

  entity <- synapser::synGet(id,
    downloadLocation = file.path("data", type))

  cfg$data[[type]][[id]] <- list(
    path = paste("data", type, entity$properties$name, sep = "/"),
    modified = entity$properties$modifiedOn,
    version = entity$properties$versionNumber)

  cfg_set_(cfg)
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
          downloadLocation = file.path("data", type))
      }
    }
  }

  for (tp in names(cfg$data)) {
    message("Syncing ", tp, " data...")
    traverse_and_download(cfg$data, tp)
  }
}

# TODO: should we enforce csv?
# TODO: allow annotations
# TODO: compute metadata
# TODO: keep _raw in sync?

#' Publish a discovered or derived dataset to Synapse
#'
#' @param path path to the file in your project's data/discovered or data/derived folder
#' @param used (optional) The Entity, Synapse ID, or URL used to create the object (can also be a list of these)
#' @param executed (optional) The Entity, Synapse ID, or URL representing code executed to create the object (can also be a list of these)
#' @param activity (optional) Activity object specifying the user's provenance
#' @param activity_name (optional) Activity name to be used in conjunction with *used* and *executed*.
#' @param activity_desc	(optional) Activity description to be used in conjunction with *used* and *executed*.
#' @export
#' @importFrom synapser Folder File synStore
data_publish <- function(path, used = NULL, executed = NULL, activity = NULL,
  activity_name = NULL, activity_desc = NULL) {

  if (! grepl("^data/discovered|^data/derived", path))
    stop(nice_text("Only data stored in 'data/discovered' or 'data/derived' ",
      "can be published to Synapse. The provided data path was '", path, "'."),
      call. = FALSE)

  type <- ifelse(grepl("^data/discovered", path), "discovered", "derived")

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

  file <- synapser::File(path = path, parent = tmp)
  res <- synapser::synStore(file,
    used = used,
    executed = executed,
    activity = activity,
    activityName = activity_name,
    activityDescription = activity_desc,
    forceVersion = FALSE)

  file_id <- res$properties$id

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

  # synapser::synSetAnnotations(file_id,
  #   annotations=list(foo = "bar", baz = 1))

  cfg_set_(cfg)

  # activity <- Activity(
  #   name = 'Activity name',
  #   description='Activity description',
  #   used = c('syn1906480', 'http://data_r_us.com/fancy/data.txt'),
  #   executed = 'syn1917825')

  res
}
