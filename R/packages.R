#' Add Apache 2.0 license to a Ki-related R package
#' 
#' @param pkg package description, can be path or package name. See \code{\link[devtools]{as.package}} for more information. 
#' @param copyright_holder The copyright holder for the package.
#'
#' @importFrom devtools as.package
#' @importFrom usethis use_template
#' @importFrom utils getFromNamespace
#' @export
use_apache_license <- function(pkg = ".",
  copyright_holder = "Bill and Melinda Gates Foundation") {

  rdcf <- utils::getFromNamespace("read_dcf","devtools")
  wdcf <- utils::getFromNamespace("write_dcf","devtools")

  pkg <- devtools::as.package(pkg)
  message("* Updating license field in DESCRIPTION.")
  desc_path <- file.path(pkg$path, "DESCRIPTION")
  DESCRIPTION <- rdcf(desc_path)
  DESCRIPTION$License <- "Apache License 2.0 | file LICENSE"
  wdcf(desc_path, DESCRIPTION)
  usethis::use_template(
    template = "apache-license.txt",
    save_as = "LICENSE",
    data = list(
      year = format(Sys.Date(), "%Y"),
      copyright_holder = copyright_holder
    ),
    package = "kitools")
}

#' Add a lintr checking unit test to your R package
#' @param pkg package description, can be path or package name. See \code{\link[devtools]{as.package}} for more information.
#' @export
use_lintr_test <- function(pkg = ".") {
  pkg <- devtools::as.package(pkg)
  path <- file.path(pkg$path, "tests", "testthat", "test-lintr.R")

  test_file_path <- system.file("test-lintr.R", package = "kitools",
    mustWork = TRUE)

  message("* Copying test-lintr.R to tests/testthat.")
  file.copy(test_file_path, path, overwrite = TRUE)
  invisible(TRUE)
}
