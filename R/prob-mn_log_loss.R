#' Mean log loss
#'
#' Compute the logarithmic loss of a classification model.
#'
#' Log loss is a measure of the performance of a classification model. A
#' perfect model has a log loss of `0`.
#'
#' Compared with [accuracy()], log loss
#' takes into account the uncertaintly in the prediction and gives a more
#' detailed view into the actual performance. For example, given two input
#' probabilities of `.6` and `.9` where both are classified as predicting
#' a positive value, say, `"Yes"`, the accuracy metric would interpret them
#' as having the same value. If the true output is `"Yes"`, log loss penalizes
#' `.6` because it is "less sure" of it's result compared to the probability
#' of `.9`.
#'
#' @family class probability metrics
#' @templateVar metric_fn mn_log_loss
#' @template return
#'
#' @section Multiclass:
#' Log loss has a known multiclass extension, and is simply the sum of the
#' log loss values for each class prediction. Because of this, no averaging
#' types are supported.
#'
#' @inheritParams pr_auc
#'
#' @param sum A `logical`. Should the sum of the likelihood contributions be
#' returned (instead of the mean value)?
#'
#' @author Max Kuhn
#'
#' @examples
#' # Two class
#' data("two_class_example")
#' mn_log_loss(two_class_example, truth, Class1)
#'
#' # Multiclass
#' library(dplyr)
#' data(hpc_cv)
#'
#' # You can use the col1:colN tidyselect syntax
#' hpc_cv %>%
#'   filter(Resample == "Fold01") %>%
#'   mn_log_loss(obs, VF:L)
#'
#' # Groups are respected
#' hpc_cv %>%
#'   group_by(Resample) %>%
#'   mn_log_loss(obs, VF:L)
#'
#'
#' # Vector version
#' # Supply a matrix of class probabilities
#' fold1 <- hpc_cv %>%
#'   filter(Resample == "Fold01")
#'
#' mn_log_loss_vec(
#'    truth = fold1$obs,
#'    matrix(
#'      c(fold1$VF, fold1$F, fold1$M, fold1$L),
#'      ncol = 4
#'    )
#' )
#'
#' # Supply `...` with quasiquotation
#' prob_cols <- levels(two_class_example$truth)
#' mn_log_loss(two_class_example, truth, Class1)
#' mn_log_loss(two_class_example, truth, !! prob_cols[1])
#'
#' @export
mn_log_loss <- function(data, ...) {
  UseMethod("mn_log_loss")
}

class(mn_log_loss) <- c("prob_metric", "function")

#' @export
#' @rdname mn_log_loss
#' @importFrom rlang quo
mn_log_loss.data.frame <- function(data, truth, ...,
                                   na_rm = TRUE, sum = FALSE) {

  estimate <- dots_to_estimate(data, !!! enquos(...))

  metric_summarizer(
    metric_nm = "mn_log_loss",
    metric_fn = mn_log_loss_vec,
    data = data,
    truth = !!enquo(truth),
    estimate = !!estimate,
    na_rm = na_rm,
    # Extra argument for mn_log_loss_impl()
    metric_fn_options = list(sum = sum)
  )

}

#' @rdname mn_log_loss
#' @importFrom stats model.matrix
#' @export
mn_log_loss_vec <- function(truth, estimate, na_rm = TRUE, sum = FALSE, ...) {

  estimator <- finalize_estimator(truth, metric_class = "mn_log_loss")

  # estimate here is a matrix of class prob columns
  mn_log_loss_impl <- function(truth, estimate, sum = FALSE) {
    mn_log_loss_estimator_impl(truth, estimate, estimator, sum)
  }

  metric_vec_template(
    metric_impl = mn_log_loss_impl,
    truth = truth,
    estimate = estimate,
    na_rm = na_rm,
    estimator = estimator,
    cls = c("factor", "numeric"),
    ...,
    sum = sum
  )
}

mn_log_loss_estimator_impl <- function(truth, estimate, estimator, sum = FALSE) {

  if (is_binary(estimator)) {
    mn_log_loss_binary(truth, estimate, sum)
  }
  else {
    mn_log_loss_multiclass(truth, estimate, sum)
  }

}

mn_log_loss_binary <- function(truth, estimate, sum) {
  estimate <- matrix(c(estimate, 1-estimate), ncol = 2)
  mn_log_loss_multiclass(truth, estimate, sum)
}

mn_log_loss_multiclass <- function(truth, estimate, sum) {

  y <- model.matrix(~ truth - 1)
  res <- y * estimate
  res[res <= .Machine$double.eps & res > 0] <- .Machine$double.eps
  pos_log <- function(x)
    log(x[x != 0])
  res <- -sum(unlist(apply(res, 1, pos_log)))

  if (!sum)
    res <- res / length(truth)

  res

}
