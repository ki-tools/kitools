#' @importFrom devtools as.package
use_apache_license <- function(pkg = ".",
  copyright_holder = "Bill and Melinda Gates Foundation") {

  pkg <- devtools::as.package(pkg)
  message("* Updating license field in DESCRIPTION.")
  desc_path <- file.path(pkg$path, "DESCRIPTION")
  DESCRIPTION <- devtools:::read_dcf(desc_path)
  DESCRIPTION$License <- "Apache License 2.0 | file LICENSE"
  devtools:::write_dcf(desc_path, DESCRIPTION)
  use_template("mit-license.txt", "LICENSE",
    data = list(
      year = format(Sys.Date(), "%Y"),
      copyright_holder = copyright_holder
    ),
    pkg = pkg)
}

#' @importFrom whisker whisker
use_template <- function(template, save_as = template,
  data = list(), pkg = ".") {

  pkg <- devtools::as.package(pkg)
  path <- file.path(pkg$path, save_as)
  if (!devtools:::can_overwrite(path))
    stop("'", save_as, "' already exists.", call. = FALSE)
  template_path <- system.file(template, package = "kitools",
    mustWork = TRUE)
  template_out <- whisker::whisker.render(readLines(template_path),
    data)
  message("* Creating `", save_as, "` from template.")
  writeLines(template_out, path)
  invisible(TRUE)
}
