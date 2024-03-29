% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dsm_varprop.R
\name{dsm_varprop}
\alias{dsm_varprop}
\title{Variance propagation for density surface models}
\usage{
dsm_varprop(
  model,
  newdata = NULL,
  trace = FALSE,
  var.type = "Vp",
  var_type = NULL
)
}
\arguments{
\item{model}{a fitted \code{\link{dsm}}.}

\item{newdata}{the prediction grid. Set to \code{NULL} to avoid making
predictions and just return model objects.}

\item{trace}{for debugging, see how the scale parameter estimation is going.}

\item{var.type}{which variance-covariance matrix should be used (\code{"Vp"} for
variance-covariance conditional on smoothing parameter(s), \code{"Vc"} for
unconditional). See \code{\link{gamObject}} for an details/explanation. If
in doubt, stick with the default, \code{"Vp"}.}

\item{var_type}{deprecated, use \code{var.type} instead.}
}
\value{
a \code{list} with elements:
\itemize{
\item \code{old_model} fitted model supplied to the function as \code{model}
\item \code{refit} refitted model object, with extra term
\item \code{pred} point estimates of predictions at \code{newdata}
\item \code{var} total variance calculated over all of \code{newdata}
\item \code{ses} standard error for each prediction cell in \code{newdata}
if \code{newdata=NULL} then the last three entries are \code{NA}.
}
}
\description{
Calculate the uncertainty in predictions from a fitted DSM, including
uncertainty from the detection function.
}
\details{
When we make predictions from a spatial model, we also want to know the
uncertainty about that abundance estimate. Since density surface models are
2 (or more) stage models, we need to incorporate the uncertainty from the
earlier stages (i.e. the detection function) into our "final" uncertainty
estimate.

This function will refit the spatial model but include the Hessian of the
offset as an extra term. Variance estimates using this new model can then be
used to calculate the variance of predicted abundance estimates which
incorporate detection function uncertainty. Importantly this requires that
if the detection function has covariates, then these do not vary within a
segment (so, for example covariates like sex cannot be used).

For more information on how to construct the prediction grid \code{data.frame},
\code{newdata}, see \code{\link{predict.dsm}}.

This routine is only useful if a detection function with covariates has been
used in the DSM.

Note that we can use \code{var.type="Vc"} here (see \code{gamObject}), which is the
variance-covariance matrix for the spatial model, corrected for smoothing
parameter uncertainty. See Wood, Pya & S{\"a}fken (2016) for more
information.

Models with fixed scale parameters (e.g., negative binomial) do not require
an extra round of optimisation.
}
\section{Diagnostics}{

The summary output from the function includes a simply diagnostic that shows
the average probability of detection from the "original" fitted model (the
model supplied to this function; column \code{Fitted.model}) and the probability
of detection from the refitted model (used for variance propagation; column
\code{Refitted.model}) along with the standard error of the probability of
detection from the fitted model (\code{Fitted.model.se}), at the unique values of
any factor covariates used in the detection function (for continuous
covariates the 5\%, 50\% and 95\% quantiles are shown). If there are large
differences between the probabilities of detection then there are
potentially problems with the fitted model, the variance propagation or
both. This can be because the fitted model does not account for enough of
the variability in the data and in refitting the variance model accounts for
this in the random effect.
}

\references{
Bravington, M. V., Miller, D. L., & Hedley, S. L. (2021). Variance
Propagation for Density Surface Models. Journal of Agricultural, Biological
and Environmental Statistics. https://doi.org/10.1007/s13253-021-00438-2

Williams, R., Hedley, S.L., Branch, T.A., Bravington, M.V., Zerbini, A.N.
and Findlay, K.P. (2011). Chilean Blue Whales as a Case Study to Illustrate
Methods to Estimate Abundance and Evaluate Conservation Status of Rare
Species. Conservation Biology 25(3), 526-535.

Wood, S.N., Pya, N. and S{\"a}fken, B. (2016) Smoothing parameter and model
selection for general smooth models. Journal of the American Statistical
Association, 1-45.
}
\author{
David L. Miller, based on code from Mark V. Bravington and Sharon L.
Hedley.
}
