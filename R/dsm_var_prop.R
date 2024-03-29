#' Prediction variance propagation for DSMs
#'
#' To ensure that uncertainty from the detection function is correctly
#' propagated to the final variance estimate of abundance, this function uses a
#' method first detailed in Williams et al (2011), further explanation is given
#' in Bravington et al. (2021).
#'
#' The idea is to refit the spatial model but including an extra random effect.
#' This random effect has zero mean and hence to effect on point estimates. Its
#' variance is the Hessian of the detection function. Variance estimates then
#' incorporate detection function uncertainty. Further mathematical details are
#' given in the paper in the references below.
#'
#' Many prediction grids can be supplied by supplying a list of `data.frame`s
#' to the function.
#'
#' Note that this routine simply calls [`dsm_varprop`][dsm_varprop]. If you
#' don't require multiple prediction grids, the other routine will probably be
#' faster.
#'
#' This routine is only useful if a detection function with covariates has been
#' used in the DSM.
#'
#' @section Diagnostics:
#' The summary output from the function includes a simply diagnostic that shows
#' the average probability of detection from the "original" fitted model (the
#' model supplied to this function; column `Fitted.model`) and the probability
#' of detection from the refitted model (used for variance propagation; column
#' `Refitted.model`) along with the standard error of the probability of
#' detection from the fitted model (`Fitted.model.se`), at the unique values of
#' any factor covariates used in the detection function (for continuous
#' covariates the 5%, 50% and 95% quantiles are shown). If there are large
#' differences between the probabilities of detection then there are
#' potentially problems with the fitted model, the variance propagation or
#' both. This can be because the fitted model does not account for enough of
#' the variability in the data and in refitting the variance model accounts for
#' this in the random effect.
#'
#' @section Limitations:
#' Note that this routine is only useful if a detection function has been used
#' in the DSM. It cannot be used when the `abundance.est` or `density.est`
#' responses are used. Importantly this requires that if the detection function
#' has covariates, then these do not vary within a segment (so, for example
#' covariates like sex cannot be used).
#'
#' @inheritParams dsm_var_gam
#' @return a `list` with elements
#'   * `model` the fitted model object
#'   * `pred.var` variance of each region given in `pred.data`
#'   * `bootstrap` logical, always `FALSE`
#'   * `pred.data` as above
#'   * `off.set` as above
#'   * `model` the fitted model with the extra term
#'   * `dsm.object` the original model, as above
#'   * `model.check` simple check of subtracting the coefficients of the two
#'   models to see if there is a large difference
#'   * `deriv` numerically calculated Hessian of the offset
#' @author Mark V. Bravington, Sharon L. Hedley. Bugs added by David L. Miller.
#' @references
#' Bravington, M. V., Miller, D. L., & Hedley, S. L. (2021). Variance
#' Propagation for Density Surface Models. Journal of Agricultural, Biological
#' and Environmental Statistics. https://doi.org/10.1007/s13253-021-00438-2
#'
#' Williams, R., Hedley, S.L., Branch, T.A., Bravington, M.V., Zerbini, A.N.
#' and Findlay, K.P. (2011). Chilean Blue Whales as a Case Study to Illustrate
#' Methods to Estimate Abundance and Evaluate Conservation Status of Rare
#' Species. Conservation Biology 25(3), 526-535.
#' @export
#' @importFrom stats as.formula update
#' @importFrom numDeriv grad
# @examples
# \dontrun{
#  library(Distance)
#  library(dsm)
#
#  # load the Gulf of Mexico dolphin data (see ?mexdolphins)
#  data(mexdolphins)
#
#  # fit a detection function
#  df <- ds(distdata, truncation=6000,
#           key = "hn", adjustment = NULL)
#
#  # fit a simple smooth of x and y
#  mod1 <- dsm(count~s(x, y), df, segdata, obsdata, family=tw())
#
#  # Calculate the variance
#  # this will give a summary over the whole area in mexdolphins$preddata
#  mod1.var <- dsm_var_prop(mod1, preddata, off.set=preddata$area)
#  summary(mod1.var)
# }
dsm_var_prop <- function(dsm.obj, pred.data, off.set,
                         seglen.varname='Effort', type.pred="response") {

  ## pre-checking...
  # die if we have a gamm
  if(any(class(dsm.obj)=="gamm")){
    stop("GAMMs are not supported.")
  }

  # break if we use the wrong response
  if(as.character(dsm.obj$formula)[2] != "count"){
    stop("Variance propagation can only be used with count as the response.")
  }

  # if there is no ddf object, then we should stop!
  # thanks to Adrian Schiavini for spotting this
  if(any(class(dsm.obj$ddf)=="fake_ddf")){
    stop("No detection function in this analysis, use dsm_var_gam")
  }

  ## end of checks

  ## data setup
  # if all the offsets are the same then we can just supply 1 and rep it
  if(length(off.set)==1){
    if(is.null(nrow(pred.data))){
      off.set <- rep(list(off.set), length(pred.data))
    }else{
      off.set <- rep(off.set, nrow(pred.data))
    }
  }

  # make sure if one of pred.data and off.set is not a list we break
  # if we didn't have a list, then put them in a list so everything works
  if(is.data.frame(pred.data) & is.vector(off.set)){
    pred.data <- list(pred.data)
    off.set <- list(off.set)
  }else if(is.list(off.set)){
    if(length(pred.data)!=length(off.set)){
      stop("pred.data and off.set don't have the same number of elements")
    }
  }

  # push the offsets into the data...
  for(i in seq_along(pred.data)){
    pred.data[[i]]$off.set <- off.set[[i]]
  }

  # mudge together all the prediction data
  all_preddata <- do.call("rbind", pred.data)

  ## end data setup


  # extract the link & invlink
  linkfn <- dsm.obj$family$linkfun
  linkinvfn <- dsm.obj$family$linkinv

  # storage
  vpred <- length(pred.data)
  preddo <- list()
  varp <- list()

  # to the varprop thing once to get the model
  varp <- dsm_varprop(dsm.obj, pred.data[[1]])
  refit <- varp$refit

  # add extra cols
  if(all(class(dsm.obj$ddf) == "list")){
    df_npars <- sum(unlist(lapply(dsm.obj$ddf,function(x) length(x$par))))
  }else{
    df_npars <- length(dsm.obj$ddf$par)
  }
  all_preddata[["XX"]] <- matrix(0, nrow(all_preddata), df_npars)

  # get a big Lp matrix now and just get rows below
  Lp_big <- predict(refit, newdata=all_preddata, type="lpmatrix")

  # start indices
  start <- 1
  end <- nrow(pred.data[[1]])

  # loop over the prediction grids
  for(ipg in seq_along(pred.data)){

    # get some data
    newdata <- pred.data[[ipg]]
    Lp <- Lp_big[start:end,,drop=FALSE]

    # predictions on the link scale
    pred <- Lp %*% coef(refit)
    pred <- newdata$off.set * linkinvfn(pred)

    # get variance-covariance
    vc <- refit$Vp

    # this is why we can only use log link
    dNdbeta <- t(pred)%*%Lp

    # make a sandwich
    var_p <- dNdbeta %*% vc %*% t(dNdbeta)

    # apply the link function to the offset
    # NB this is because refit is a gam not dsm object! If refit is dsm
    #    then this will get done in predict.dsm
    newdata$off.set <- linkfn(newdata$off.set)


    vpred[ipg] <- var_p
    preddo[[ipg]] <- sum(pred)

    # get next indices
    start <- end+1
    end <- start + nrow(pred.data[[ipg]])-1
  }


  result <- list(pred.var = vpred,
                 bootstrap = FALSE,
                 var.prop = TRUE,
                 pred.data = pred.data,
                 pred = preddo,
                 off.set = off.set,
                 model = varp$refit,
                 dsm.object = dsm.obj,
                 model.check = varprop_check(varp),
                 #deriv = firstD,
                 seglen.varname = seglen.varname,
                 type.pred=type.pred
                )

  class(result) <- "dsm.var"

  return(result)
}
