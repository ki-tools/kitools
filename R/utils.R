nice_text <- function(...) {
  txt <- do.call(paste0, list(...))
  paste0(strwrap(txt), collapse = "\n")
}
